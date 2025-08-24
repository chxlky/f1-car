use std::{
    collections::HashMap,
    sync::{Arc, Mutex},
};

use serde::{Deserialize, Serialize};
use specta::Type;
use tauri_specta::Event;
pub use telemetry::{CarStatus, ConnectionStatus, F1Car};

#[derive(Debug, Clone, Serialize, Deserialize, Type, Event)]
pub struct CarDiscoveredEvent {
    pub car: F1Car,
}

#[derive(Debug, Clone, Serialize, Deserialize, Type, Event)]
pub struct CarUpdatedEvent {
    pub car: F1Car,
}

#[derive(Debug, Clone, Serialize, Deserialize, Type, Event)]
pub struct CarOfflineEvent {
    pub car: F1Car,
}

#[derive(Debug, Clone, Serialize, Deserialize, Type, Event)]
pub struct CarRemovedEvent {
    pub car_id: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, Type, Event)]
pub struct DiscoveryStatusEvent {
    pub is_running: bool,
    pub message: String,
}

pub type CarsMap = Arc<Mutex<HashMap<String, F1Car>>>;

#[derive(Debug, Clone, Serialize, Deserialize, Type)]
pub struct DiscoveryError {
    pub code: String,
    pub message: String,
}

impl DiscoveryError {
    pub fn mdns_creation_failed(msg: &str) -> Self {
        Self {
            code: "MDNS_CREATION_FAILED".to_string(),
            message: format!("mDNS daemon creation failed: {msg}"),
        }
    }

    pub fn mdns_browse_failed(msg: &str) -> Self {
        Self {
            code: "MDNS_BROWSE_FAILED".to_string(),
            message: format!("mDNS browse failed: {msg}"),
        }
    }

    pub fn websocket_failed(msg: &str) -> Self {
        Self {
            code: "WEBSOCKET_FAILED".to_string(),
            message: format!("WebSocket connection failed: {msg}"),
        }
    }

    pub fn car_not_found(car_id: &str) -> Self {
        Self {
            code: "CAR_NOT_FOUND".to_string(),
            message: format!("Car not found: {car_id}"),
        }
    }

    pub fn service_already_running() -> Self {
        Self {
            code: "SERVICE_ALREADY_RUNNING".to_string(),
            message: "Discovery service is already running".to_string(),
        }
    }

    pub fn service_not_running() -> Self {
        Self {
            code: "SERVICE_NOT_RUNNING".to_string(),
            message: "Discovery service is not running".to_string(),
        }
    }
}

impl From<DiscoveryError> for String {
    fn from(err: DiscoveryError) -> String {
        serde_json::to_string(&err).unwrap_or(err.message)
    }
}

impl From<anyhow::Error> for DiscoveryError {
    fn from(err: anyhow::Error) -> Self {
        Self {
            code: "INTERNAL_ERROR".to_string(),
            message: err.to_string(),
        }
    }
}
