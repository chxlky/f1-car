use std::sync::Arc;
use std::time::{Duration, SystemTime};

use anyhow::Context;
use log::{error, info};
use tauri::{AppHandle, State};
use tauri_specta::Event;
use telemetry::ConnectionStatus;
use tokio::sync::Mutex;

use crate::discovery::DiscoveryService;
use crate::types::{CarUpdatedEvent, DiscoveryError, F1Car};

#[tauri::command]
#[specta::specta]
pub async fn start_discovery(
    handle: AppHandle,
    discovery_service: State<'_, Arc<Mutex<DiscoveryService>>>,
) -> Result<(), String> {
    info!("Starting mDNS discovery...");

    let mut service = discovery_service.lock().await;

    match service.start(handle).await {
        Ok(()) => {
            info!("mDNS discovery started successfully");
            Ok(())
        }
        Err(e) => {
            error!("Failed to start mDNS discovery: {e:?}");
            Err(e.message)
        }
    }
}

#[tauri::command]
#[specta::specta]
pub async fn stop_discovery(
    discovery_service: State<'_, Arc<Mutex<DiscoveryService>>>,
) -> Result<(), DiscoveryError> {
    info!("Stopping mDNS discovery...");

    let mut service = discovery_service.lock().await;

    match service.stop().await {
        Ok(()) => {
            info!("mDNS discovery stopped successfully");
            Ok(())
        }
        Err(e) => {
            error!("Failed to stop mDNS discovery: {e:?}");
            Err(e)
        }
    }
}

#[tauri::command]
#[specta::specta]
pub async fn get_discovered_cars(
    discovery_service: State<'_, Arc<Mutex<DiscoveryService>>>,
) -> Result<Vec<F1Car>, DiscoveryError> {
    let service = discovery_service.lock().await;
    Ok(service.get_all_cars())
}

#[tauri::command]
#[specta::specta]
pub async fn get_car_by_id(
    car_id: String,
    discovery_service: State<'_, Arc<Mutex<DiscoveryService>>>,
) -> Result<Option<F1Car>, DiscoveryError> {
    let service = discovery_service.lock().await;
    Ok(service.get_car_by_id(&car_id))
}

#[tauri::command]
#[specta::specta]
pub async fn connect_to_car(
    car_id: String,
    handle: AppHandle,
    discovery_service: State<'_, Arc<Mutex<DiscoveryService>>>,
) -> Result<(), DiscoveryError> {
    let service = discovery_service.lock().await;
    if let Some(mut car) = service.get_car_by_id(&car_id) {
        // set status to Connecting and emit update
        car.connection_status = ConnectionStatus::Connecting;
        CarUpdatedEvent { car: car.clone() }
            .emit(&handle)
            .context("Failed to emit car-updated event")?;

        let cars_map = service.get_cars();
        let handle_clone = handle.clone();
        tokio::spawn(async move {
            // simulate network connect attempt
            tokio::time::sleep(Duration::from_millis(500)).await;
            // update cached car
            {
                let mut guard = match cars_map.lock() {
                    Ok(g) => g,
                    Err(_) => return,
                };
                if let Some(c) = guard.get_mut(&car_id) {
                    c.connection_status = ConnectionStatus::Connected;
                    c.last_seen = Some(SystemTime::now());
                    let _ = CarUpdatedEvent { car: c.clone() }.emit(&handle_clone);
                }
            }
        });
    }

    Ok(())
}

#[tauri::command]
#[specta::specta]
pub async fn disconnect_car(
    car_id: String,
    handle: AppHandle,
    discovery_service: State<'_, Arc<Mutex<DiscoveryService>>>,
) -> Result<(), DiscoveryError> {
    let service = discovery_service.lock().await;
    if let Some(mut car) = service.get_car_by_id(&car_id) {
        car.connection_status = ConnectionStatus::Disconnected;
        car.last_seen = Some(SystemTime::now());
        CarUpdatedEvent { car: car.clone() }
            .emit(&handle)
            .context("Failed to emit car-updated event")?;

        let cars_map = service.get_cars();
        {
            let mut guard = match cars_map.lock() {
                Ok(g) => g,
                Err(_) => return Ok(()),
            };
            if let Some(c) = guard.get_mut(&car_id) {
                c.connection_status = ConnectionStatus::Disconnected;
                c.last_seen = Some(SystemTime::now());
            }
        }
    }

    Ok(())
}

#[tauri::command]
#[specta::specta]
pub async fn is_discovery_running(
    discovery_service: State<'_, Arc<Mutex<DiscoveryService>>>,
) -> Result<bool, String> {
    let service = discovery_service.lock().await;
    Ok(service.is_running())
}
