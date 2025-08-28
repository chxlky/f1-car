use std::time::SystemTime;

use serde::{Deserialize, Serialize};
use specta::Type;

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ControlMessage {
    pub steering: i8, // -100 to 100 (left to right)
    pub throttle: i8, // -100 to 100 (reverse to forward)
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct CarConfiguration {
    pub number: u8,          // Car number
    pub driver_name: String, // Driver's name
    pub team_name: String,   // Team name
}

impl Default for CarConfiguration {
    fn default() -> Self {
        CarConfiguration {
            number: 0,
            driver_name: "Unknown Driver".into(),
            team_name: "Unknown Team".into(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, Type)]
#[serde(rename_all = "camelCase")]
pub struct F1Car {
    pub id: String,
    pub number: u32,
    pub driver: String,
    pub team: String,
    pub ip: String,
    pub port: u16,
    pub version: String,
    pub connection_status: ConnectionStatus,
    pub last_seen: Option<SystemTime>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Type)]
pub enum CarStatus {
    Online,
    Offline,
}

pub const SERVICE_TYPE: &str = "_f1-car._udp.local.";

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Type, Default)]
pub enum ConnectionStatus {
    #[default]
    Disconnected,
    Connecting,
    Connected,
    Failed(String),
}
