#[derive(Debug, Clone)]
pub struct F1Car {
    pub number: i32,
    pub driver_name: String,
    pub team_name: String,
    pub version: String,
    pub ip_address: Option<String>,
    pub port: Option<i32>,
}

impl F1Car {
    pub fn new(
        number: i32,
        driver_name: String,
        team_name: String,
        version: String,
        ip_address: Option<String>,
        port: Option<i32>,
    ) -> Self {
        Self {
            number,
            driver_name,
            team_name,
            version,
            ip_address,
            port,
        }
    }
}

// Mirror of telemetry::CarIdentity
#[derive(Debug, Clone)]
pub struct CarIdentity {
    pub number: u8,
    pub driver_name: String,
    pub team_name: String,
}

// Mirror of telemetry::CarPhysics
#[derive(Debug, Clone)]
pub struct CarPhysics {
    pub max_steering_angle: i32,
    pub max_throttle: i32,
}

// Mirror of telemetry::ServerMessage
#[derive(Debug, Clone)]
pub enum ServerMessage {
    Identity(CarIdentity),
    Physics(CarPhysics),
    Pong { timestamp: i64 },
    IdentityUpdated { success: bool, message: String },
    PhysicsUpdated { success: bool, message: String },
    Error { message: String },
}

// --- Conversions from `telemetry` types to mirrored types ---

impl From<telemetry::CarIdentity> for CarIdentity {
    fn from(value: telemetry::CarIdentity) -> Self {
        Self {
            number: value.number,
            driver_name: value.driver_name,
            team_name: value.team_name,
        }
    }
}

impl From<telemetry::CarPhysics> for CarPhysics {
    fn from(value: telemetry::CarPhysics) -> Self {
        Self {
            max_steering_angle: value.max_steering_angle,
            max_throttle: value.max_throttle,
        }
    }
}

impl From<telemetry::ServerMessage> for ServerMessage {
    fn from(value: telemetry::ServerMessage) -> Self {
        match value {
            telemetry::ServerMessage::Identity { identity } => Self::Identity(identity.into()),
            telemetry::ServerMessage::Physics { physics } => Self::Physics(physics.into()),
            telemetry::ServerMessage::Pong { timestamp } => Self::Pong { timestamp },
            telemetry::ServerMessage::IdentityUpdated { success, message } => {
                Self::IdentityUpdated { success, message }
            }
            telemetry::ServerMessage::PhysicsUpdated { success, message } => {
                Self::PhysicsUpdated { success, message }
            }
            telemetry::ServerMessage::Error { message } => Self::Error { message },
        }
    }
}

// --- Conversions from mirrored types back to `telemetry` types ---

impl From<CarIdentity> for telemetry::CarIdentity {
    fn from(value: CarIdentity) -> Self {
        Self {
            number: value.number,
            driver_name: value.driver_name,
            team_name: value.team_name,
        }
    }
}

impl From<CarPhysics> for telemetry::CarPhysics {
    fn from(value: CarPhysics) -> Self {
        Self {
            max_steering_angle: value.max_steering_angle,
            max_throttle: value.max_throttle,
        }
    }
}
