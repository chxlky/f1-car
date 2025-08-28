use std::sync::Arc;

use anyhow::{Context, Result};
use local_ip_address::local_ip;
use log::{debug, error, info, warn};
use mdns_sd::{ServiceDaemon, ServiceInfo};
use tokio::sync::Mutex;

use crate::config::ConfigManager;
use telemetry::{ConnectionStatus, F1Car};

pub struct DiscoveryService {
    mdns: ServiceDaemon,
    service_info: Option<ServiceInfo>,
    config_manager: Arc<Mutex<ConfigManager>>,
    pub service_car: Option<F1Car>,
}

impl DiscoveryService {
    pub fn new(config_manager: Arc<Mutex<ConfigManager>>) -> Result<Self> {
        let mdns = ServiceDaemon::new().context("Failed to create mDNS service daemon")?;

        Ok(Self {
            mdns,
            service_info: None,
            config_manager,
            service_car: None,
        })
    }

    pub async fn start_advertising(&mut self, port: u16) -> Result<()> {
        let config = {
            let config_manager = self.config_manager.lock().await;
            config_manager.get_config().clone()
        };

        if let Some(service_info) = &self.service_info {
            warn!("Unregistering existing service...");
            if let Err(e) = self.mdns.unregister(service_info.get_fullname()) {
                error!("Failed to unregister existing service: {e}");
            }

            self.service_info = None;
        }

        let local_ip = local_ip().context("Failed to get local IP address")?;
        info!("Using Local IP: {local_ip}");

        let service_name = format!("car-{}", config.number);
        let service_type = telemetry::SERVICE_TYPE;
        let host_name = format!("{service_name}.local.");

        debug!("Service name: {service_name}");
        debug!("Service type: {service_type}");
        debug!("Host name: {host_name}");
        debug!("Port: {port}");

        let version = env!("CARGO_PKG_VERSION").to_string();
        let properties = [
            ("number", &config.number.to_string()),
            ("driver", &config.driver_name),
            ("team", &config.team_name),
            ("version", &version),
        ];

        debug!("Service properties: {properties:?}");

        let service_info = ServiceInfo::new(
            service_type,
            &service_name,
            &host_name,
            local_ip,
            port,
            &properties[..],
        )
        .context("Failed to create mDNS service info")?;

        info!(
            "Advertising F1 Car #{} ({} - {}) on network as '{}'",
            config.number, config.driver_name, config.team_name, service_name
        );

        self.mdns
            .register(service_info.clone())
            .context("Failed to register mDNS service")?;

        let car = F1Car {
            id: format!("car-{}", config.number),
            number: config.number as u32,
            driver: config.driver_name.clone(),
            team: config.team_name.clone(),
            ip: local_ip.to_string(),
            port,
            version: version.clone(),
            connection_status: ConnectionStatus::Disconnected,
            last_seen: None,
        };

        self.service_info = Some(service_info);
        self.service_car = Some(car);
        // Maybe sleep for a short duration to allow the service to register
        tokio::time::sleep(tokio::time::Duration::from_secs(1)).await;

        info!("mDNS service started successfully");

        Ok(())
    }

    pub async fn update_service(&mut self, port: u16) -> Result<()> {
        info!("Updating mDNS service...");
        self.start_advertising(port).await
    }

    pub fn stop_advertising(&mut self) -> Result<()> {
        if let Some(service_info) = &self.service_info {
            self.mdns
                .unregister(service_info.get_fullname())
                .context("Failed to unregister mDNS service")?;
            self.service_info = None;
        }

        Ok(())
    }
}

impl Drop for DiscoveryService {
    fn drop(&mut self) {
        if let Err(e) = self.stop_advertising() {
            error!("Failed to stop mDNS advertising on drop: {e}");
        }
    }
}
