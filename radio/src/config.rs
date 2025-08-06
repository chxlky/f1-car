use std::path::{Path, PathBuf};

use anyhow::{Context, Result};
use log::info;
use telemetry::{CarIdentity, CarPhysics};
use tokio::fs;

pub struct ConfigManager {
    config_path: PathBuf,
    identity: CarIdentity,
    physics: CarPhysics,
}

impl ConfigManager {
    pub async fn new() -> Result<Self> {
        Self::with_config_dir(".f1-car").await
    }

    pub async fn with_config_dir<P: AsRef<Path>>(config_dir: P) -> Result<Self> {
        let config_dir = config_dir.as_ref();
        let config_path = config_dir.join("car_config.toml");

        if !config_dir.exists() {
            fs::create_dir_all(config_dir)
                .await
                .with_context(|| {
                    format!(
                        "Failed to create config directory: {}",
                        config_dir.display()
                    )
                })?;
            info!("Created config directory at {}", config_dir.display());
        }

        let identity = if config_path.exists() {
            Self::load_config(&config_path).await?
        } else {
            info!(
                "No existing config found, creating default configuration at {}",
                config_path.display()
            );
            let default_identity = CarIdentity {
                number: 0,
                driver_name: "Unknown Driver".to_string(),
                team_name: "Unknown Team".to_string(),
            };
            Self::save_config(&config_path, &default_identity)
                .await
                .with_context(|| {
                    format!("Failed to save default config to {}", config_path.display())
                })?;
            default_identity
        };

        let physics = CarPhysics {
            max_steering_angle: 30,
            max_throttle: 100,
        };

        info!(
            "Loaded car config: #{} {} ({})",
            identity.number, identity.driver_name, identity.team_name
        );

        Ok(Self {
            config_path,
            identity,
            physics,
        })
    }

    pub fn get_identity(&self) -> &CarIdentity {
        &self.identity
    }

    pub fn get_physics(&self) -> &CarPhysics {
        &self.physics
    }

    pub async fn update_identity(&mut self, new_identity: CarIdentity) -> Result<()> {
        info!(
            "Updating car identity: #{} {} ({}) -> #{} {} ({})",
            self.identity.number,
            self.identity.driver_name,
            self.identity.team_name,
            new_identity.number,
            new_identity.driver_name,
            new_identity.team_name
        );

        self.identity = new_identity;
        Self::save_config(&self.config_path, &self.identity).await?;
        Ok(())
    }

    pub async fn update_physics(&mut self, new_physics: CarPhysics) -> Result<()> {
        info!(
            "Updating car physics: max_steering_angle={}, max_throttle={} -> max_steering_angle={}, max_throttle={}",
            self.physics.max_steering_angle,
            self.physics.max_throttle,
            new_physics.max_steering_angle,
            new_physics.max_throttle
        );

        self.physics = new_physics;
        Ok(())
    }

    async fn load_config(path: &Path) -> Result<CarIdentity> {
        let content = fs::read_to_string(path)
            .await
            .with_context(|| format!("Failed to read config file: {}", path.display()))?;

        let config: CarIdentity = toml::from_str(&content)
            .with_context(|| format!("Failed to parse config file: {}", path.display()))?;

        Ok(config)
    }

    async fn save_config(path: &Path, config: &CarIdentity) -> Result<()> {
        let content = toml::to_string_pretty(config)
            .with_context(|| format!("Failed to serialize config: {}", path.display()))?;

        fs::write(path, content)
            .await
            .with_context(|| format!("Failed to write config file: {}", path.display()))?;

        Ok(())
    }
}
