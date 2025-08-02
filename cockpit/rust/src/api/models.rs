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
