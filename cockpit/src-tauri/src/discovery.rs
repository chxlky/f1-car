use std::sync::atomic::{AtomicBool, Ordering};
use std::{
    collections::HashMap,
    sync::{Arc, Mutex},
    time::Duration,
};

use anyhow::{Context, Result};
use log::{debug, error, info, warn};
use mdns_sd::{ServiceDaemon, ServiceEvent};
use tauri::AppHandle;
use tauri_specta::Event;
use tokio::{task::JoinHandle, time};

const SERVICE_TYPE: &str = "_f1-car._udp.local.";

use crate::types::{
    CarDiscoveredEvent, CarOfflineEvent, CarUpdatedEvent, CarsMap, DiscoveryError, F1Car,
};

pub struct DiscoveryService {
    cars: CarsMap,
    fullname_map: Arc<Mutex<HashMap<String, String>>>,
    is_running: Arc<AtomicBool>,
    cleanup_handle: Option<JoinHandle<()>>,
    discovery_handle: Option<JoinHandle<()>>,
}

impl DiscoveryService {
    pub fn new() -> Self {
        Self {
            cars: Arc::new(Mutex::new(HashMap::new())),
            fullname_map: Arc::new(Mutex::new(HashMap::new())),
            is_running: Arc::new(AtomicBool::new(false)),
            cleanup_handle: None,
            discovery_handle: None,
        }
    }

    pub fn get_cars(&self) -> CarsMap {
        Arc::clone(&self.cars)
    }

    pub fn is_running(&self) -> bool {
        self.is_running.load(Ordering::SeqCst)
    }

    pub async fn start(&mut self, handle: AppHandle) -> Result<(), DiscoveryError> {
        if self.is_running.load(Ordering::SeqCst) {
            return Err(DiscoveryError::service_already_running());
        }

        self.is_running.store(true, Ordering::SeqCst);
        info!("Starting mDNS F1 car discovery...");

        self.start_mdns_discovery(handle.clone()).await?;
        self.start_cleanup_task(handle.clone()).await;

        info!("mDNS discovery started successfully");

        Ok(())
    }

    pub async fn stop(&mut self) -> Result<(), DiscoveryError> {
        if !self.is_running.load(Ordering::SeqCst) {
            return Err(DiscoveryError::service_not_running());
        }

        self.is_running.store(false, Ordering::SeqCst);

        if let Some(h) = self.discovery_handle.take() {
            h.abort();
        }
        if let Some(h) = self.cleanup_handle.take() {
            h.abort();
        }

        info!("mDNS discovery stopped successfully");
        Ok(())
    }

    async fn start_mdns_discovery(&mut self, handle: AppHandle) -> Result<(), DiscoveryError> {
        let cars = self.cars.clone();
        let fullnames = self.fullname_map.clone();
        let is_running = self.is_running.clone();
        let app_handle = handle.clone();

        let discovery_handle = tokio::spawn(async move {
            let daemon = match ServiceDaemon::new() {
                Ok(d) => d,
                Err(e) => {
                    error!("Failed to create mDNS daemon: {e}");
                    return;
                }
            };

            let receiver = match daemon.browse(SERVICE_TYPE) {
                Ok(r) => r,
                Err(e) => {
                    error!("Failed to start mDNS browser: {e}");
                    return;
                }
            };

            info!("mDNS browser started for {}", SERVICE_TYPE);

            while let Ok(event) = receiver.recv() {
                if !is_running.load(Ordering::SeqCst) {
                    break;
                }

                debug!("mDNS event received: {:?}", event);

                match event {
                    ServiceEvent::ServiceResolved(info) => {
                        if let Err(e) =
                            Self::handle_service_resolved(info, &cars, &fullnames, &app_handle)
                        {
                            error!("Failed to handle service resolved: {e}");
                        }
                    }
                    ServiceEvent::ServiceRemoved(_, fullname) => {
                        if let Err(e) =
                            Self::handle_service_removed(&fullname, &cars, &fullnames, &app_handle)
                        {
                            error!("Failed to handle service removed: {e}");
                        }
                    }
                    _ => {}
                }
            }

            debug!("mDNS discovery task ended");
        });

        self.discovery_handle = Some(discovery_handle);
        Ok(())
    }

    async fn start_cleanup_task(&mut self, _handle: AppHandle) {
        let is_running = self.is_running.clone();

        let cleanup_handle = tokio::spawn(async move {
            let mut interval = time::interval(Duration::from_secs(60));
            loop {
                interval.tick().await;
                if !is_running.load(Ordering::SeqCst) {
                    break;
                }
                // no-op cleanup; frontend or explicit action manages removal
            }
            debug!("Cleanup task ended");
        });

        self.cleanup_handle = Some(cleanup_handle);
    }

    fn handle_service_resolved(
        info: mdns_sd::ServiceInfo,
        cars: &CarsMap,
        fullnames: &Arc<Mutex<HashMap<String, String>>>,
        handle: &AppHandle,
    ) -> Result<()> {
        if let Some(address) = info.get_addresses().iter().next() {
            let address_str = address.to_string();

            let car = F1Car {
                id: format!("{}:{}", address, info.get_port()),
                number: info
                    .get_property_val_str("number")
                    .and_then(|s| s.parse().ok())
                    .unwrap_or(0),
                driver: info
                    .get_property_val_str("driver")
                    .unwrap_or("Unknown")
                    .to_string(),
                team: info
                    .get_property_val_str("team")
                    .unwrap_or("Unknown")
                    .to_string(),
                ip: address_str.clone(),
                port: info.get_port(),
                version: info
                    .get_property_val_str("version")
                    .unwrap_or("Unknown")
                    .to_string(),
            };

            let is_new_car;
            {
                let mut cars_guard = cars.lock().unwrap();
                is_new_car = !cars_guard.contains_key(&car.id);
                cars_guard.insert(car.id.clone(), car.clone());
            }
            // remember mapping from mdns fullname -> car id for removals
            let fullname = info.get_fullname();
            let mut map_guard = fullnames.lock().unwrap();
            map_guard.insert(fullname.to_string(), car.id.clone());

            if is_new_car {
                CarDiscoveredEvent { car: car.clone() }
                    .emit(handle)
                    .context("Failed to emit car-discovered event")?;
                info!("New F1 car discovered: {}", car.id);
            } else {
                CarUpdatedEvent { car: car.clone() }
                    .emit(handle)
                    .context("Failed to emit car-updated event")?;
                debug!("F1 car updated: {}", car.id);
            }
        }

        Ok(())
    }

    fn handle_service_removed(
        fullname: &str,
        cars: &CarsMap,
        fullnames: &Arc<Mutex<HashMap<String, String>>>,
        handle: &AppHandle,
    ) -> Result<()> {
        // find the car id from the fullname mapping
        let mut map_guard = fullnames.lock().unwrap();
        if let Some(car_id) = map_guard.remove(fullname) {
            let cars_guard = cars.lock().unwrap();
            if let Some(car) = cars_guard.get(&car_id) {
                CarOfflineEvent { car: car.clone() }
                    .emit(handle)
                    .context("Failed to emit car-offline event")?;
                warn!("F1 car went offline: {fullname}");
            }
        }

        Ok(())
    }

    pub fn get_all_cars(&self) -> Vec<F1Car> {
        let cars_guard = self.cars.lock().unwrap();
        cars_guard.values().cloned().collect()
    }

    pub fn get_car_by_id(&self, car_id: &str) -> Option<F1Car> {
        let cars_guard = self.cars.lock().unwrap();
        cars_guard.get(car_id).cloned()
    }
}

impl Default for DiscoveryService {
    fn default() -> Self {
        Self::new()
    }
}

impl Drop for DiscoveryService {
    fn drop(&mut self) {
        if self.is_running() {
            warn!("DiscoveryService dropped while still running");
        }
    }
}
