use std::{
    sync::{Arc, Mutex},
    time::Duration,
};

use anyhow::{Context, Error, Result};
use flutter_rust_bridge::frb;
use log::{debug, error, info, warn};
use mdns_sd::{ServiceDaemon, ServiceEvent};
use tokio::time::timeout;

use crate::{api::models::F1Car, frb_generated::StreamSink};

const SERVICE_TYPE: &str = "_f1-car._udp.local.";
const DISCOVERY_TIMEOUT: Duration = Duration::from_secs(10);

#[derive(Debug, Clone)]
pub enum DiscoveryEvent {
    CarDiscovered(F1Car),
    CarUpdated(F1Car),
    DiscoveryStarted,
    DiscoveryStopped,
    Error(String),
}

#[derive(Debug, Clone)]
pub struct F1DiscoveryService {
    discovered_cars: Arc<Mutex<Vec<F1Car>>>,
    is_discovering: Arc<Mutex<bool>>,
}

impl F1DiscoveryService {
    #[frb(sync)]
    pub fn new() -> Self {
        Self {
            discovered_cars: Arc::new(Mutex::new(Vec::new())),
            is_discovering: Arc::new(Mutex::new(false)),
        }
    }

    #[frb(sync)]
    pub fn is_discovering(&self) -> bool {
        *self.is_discovering.lock().unwrap()
    }

    #[frb(sync)]
    pub fn get_discovered_cars(&self) -> Vec<F1Car> {
        self.discovered_cars.lock().unwrap().clone()
    }

    pub async fn start_discovery(&self, sink: StreamSink<DiscoveryEvent>) -> Result<()> {
        info!("Starting F1 car discovery...");

        if self.is_discovering() {
            warn!("Discovery already in progress. It will be restarted.");
        }
        *self.is_discovering.lock().unwrap() = true;
        self.discovered_cars.lock().unwrap().clear();

        let _ = sink.add(DiscoveryEvent::DiscoveryStarted);

        let discovery_result = self.perform_discovery(&sink).await;

        if let Err(e) = &discovery_result {
            error!("Discovery failed: {e}");
            let _ = sink.add(DiscoveryEvent::Error(e.to_string()));
        }

        let _ = self.stop_discovery_internal(&sink).await;

        discovery_result
    }

    pub async fn load_mock_cars(&self, sink: StreamSink<DiscoveryEvent>) -> Result<()> {
        info!("Loading mock F1 cars...");
        *self.is_discovering.lock().unwrap() = true;
        self.discovered_cars.lock().unwrap().clear();

        let _ = sink.add(DiscoveryEvent::DiscoveryStarted);

        tokio::time::sleep(Duration::from_secs(1)).await;

        let mock_cars = vec![
            F1Car::new(
                1,
                "Max Verstappen".to_string(),
                "Oracle Red Bull Racing".to_string(),
                "1.0.0".to_string(),
                Some("192.168.0.100".to_string()),
                Some(8080),
            ),
            F1Car::new(
                16,
                "Charles Leclerc".to_string(),
                "Scuderia Ferrari HP".to_string(),
                "1.0.2".to_string(),
                Some("192.168.0.101".to_string()),
                Some(8080),
            ),
            F1Car::new(
                55,
                "Carlos Sainz".to_string(),
                "Atlassian Williams Racing".to_string(),
                "1.0.3".to_string(),
                Some("192.168.0.102".to_string()),
                Some(8080),
            ),
        ];

        for car in mock_cars {
            self.add_or_update_car(car, &sink).await;
            // Simulate a delay for each car discovery
            tokio::time::sleep(Duration::from_millis(500)).await;
        }

        info!("Mock F1 cars loaded successfully.");
        let _ = self.stop_discovery_internal(&sink).await;

        Ok(())
    }

    async fn stop_discovery_internal(&self, sink: &StreamSink<DiscoveryEvent>) -> Result<()> {
        let mut is_discovering = self.is_discovering.lock().unwrap();
        if *is_discovering {
            *is_discovering = false;
            let discovered_count = self.discovered_cars.lock().unwrap().len();
            info!("Stopping discovery. Found {discovered_count} car(s).");
            let _ = sink.add(DiscoveryEvent::DiscoveryStopped);
        }

        Ok(())
    }

    async fn perform_discovery(&self, sink: &StreamSink<DiscoveryEvent>) -> Result<()> {
        info!("Browsing for mDNS service: {SERVICE_TYPE}");

        let mdns = ServiceDaemon::new().context("Failed to create mDNS daemon")?;
        let receiver = mdns
            .browse(SERVICE_TYPE)
            .context("Failed to browse for service")?;

        let discovery_future = async {
            while self.is_discovering() {
                match receiver.recv_async().await {
                    Ok(ServiceEvent::ServiceResolved(info)) => {
                        debug!("Resolved service: {}", info.get_fullname());
                        match self.create_car_from_service_info(&info) {
                            Ok(car) => self.add_or_update_car(car, sink).await,
                            Err(e) => {
                                warn!("Failed to create F1Car from service info: {e:?}");
                                let _ = sink.add(DiscoveryEvent::Error(e.to_string()));
                            }
                        }
                    }
                    Ok(_) => { /* Ignore other events like ServiceFound, SearchStarted */ }
                    Err(e) => {
                        warn!("mDNS receiver error: {e:?}");
                        let _ = sink.add(DiscoveryEvent::Error(format!("mDNS error: {e}")));
                        break;
                    }
                }
            }
            Ok::<(), Error>(())
        };

        match timeout(DISCOVERY_TIMEOUT, discovery_future).await {
            Ok(Ok(_)) => info!("Discovery finished gracefully."),
            Ok(Err(e)) => return Err(e).context("Discovery task failed"),
            Err(_) => {
                info!(
                    "Discovery timed out after {} seconds.",
                    DISCOVERY_TIMEOUT.as_secs()
                );
            }
        }

        Ok(())
    }

    fn create_car_from_service_info(&self, info: &mdns_sd::ServiceInfo) -> Result<F1Car> {
        let properties = info.get_properties();
        let car_number_str = extract_property(properties, "number")?;
        let driver_name = extract_property(properties, "driver")?;
        let team_name = extract_property(properties, "team")?;
        let version = extract_property(properties, "version")?;

        let car_number: i32 = car_number_str
            .parse()
            .with_context(|| format!("Invalid car number: '{car_number_str}'"))?;

        let ip_address = info
            .get_addresses()
            .iter()
            .next()
            .map(|addr| addr.to_string());
        let port = Some(info.get_port() as i32);

        Ok(F1Car::new(
            car_number,
            driver_name,
            team_name,
            version,
            ip_address,
            port,
        ))
    }

    async fn add_or_update_car(&self, car: F1Car, sink: &StreamSink<DiscoveryEvent>) {
        let mut cars = self.discovered_cars.lock().unwrap();
        if let Some(existing) = cars.iter_mut().find(|c| c.number == car.number) {
            *existing = car.clone();
            debug!("Updated existing F1 car #{}", car.number);
            let _ = sink.add(DiscoveryEvent::CarUpdated(car));
        } else {
            info!(
                "Discovered new F1 car #{} ({})",
                car.number, car.driver_name
            );
            cars.push(car.clone());
            let _ = sink.add(DiscoveryEvent::CarDiscovered(car));
        }
    }
}

fn extract_property(properties: &mdns_sd::TxtProperties, key: &str) -> Result<String> {
    properties
        .get(key)
        .map(|p| p.val_str().to_string())
        .ok_or_else(|| anyhow::anyhow!("Missing required TXT record: '{}'", key))
}
