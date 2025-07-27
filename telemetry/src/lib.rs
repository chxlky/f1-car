use serde::{Deserialize, Serialize};

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

impl CarConfiguration {
    fn default() -> Self {
        CarConfiguration {
            number: 0,
            driver_name: "Unknown Driver".into(),
            team_name: "Unknown Team".into(),
        }
    }
}
