use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CarIdentity {
    pub number: u8,
    pub driver_name: String,
    pub team_name: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CarPhysics {
    pub max_steering_angle: i32,
    pub max_throttle: i32,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(tag = "type")]
pub enum ClientMessage {
    Ping { timestamp: i64 },
    Control { steering: i32, throttle: i32 },
    IdentityRequest,
    PhysicsRequest,
    IdentityUpdate { identity: CarIdentity },
    PhysicsUpdate { physics: CarPhysics },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum ServerMessage {
    Pong { timestamp: i64 },
    Identity { identity: CarIdentity },
    Physics { physics: CarPhysics },
    IdentityUpdated { success: bool, message: String },
    PhysicsUpdated { success: bool, message: String },
    Error { message: String },
}
