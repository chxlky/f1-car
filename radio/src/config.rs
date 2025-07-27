use std::path::{Path, PathBuf};

use anyhow::{Context, Result};
use log::info;
use telemetry::CarConfiguration;
use tokio::fs;

pub struct ConfigManager {
    config_path: PathBuf,
    config: CarConfiguration,
}

impl ConfigManager {
    pub async fn new() -> Result<Self> {
        Self::with_config_dir(".f1-car").await
    }

    pub async fn with_config_dir<P: AsRef<Path>>(config_dir: P) -> Result<Self> {
        let config_dir = config_dir.as_ref();
        let config_path = config_dir.join("car_config.toml");

        if !config_dir.exists() {
            fs::create_dir_all(config_dir).await.with_context(|| {
                format!(
                    "Failed to create config directory: {}",
                    config_dir.display()
                )
            })?;
            info!("Created config directory at {}", config_dir.display());
        }

        let config = if config_path.exists() {
            Self::load_config(&config_path).await?
        } else {
            info!(
                "No existing config found, creating default configuration at {}",
                config_path.display()
            );
            let default_config = CarConfiguration::default();
            Self::save_config(&config_path, &default_config)
                .await
                .with_context(|| {
                    format!("Failed to save default config to {}", config_path.display())
                })?;

            default_config
        };

        info!(
            "Loaded car config: #{} {} ({})",
            config.number, config.driver_name, config.team_name
        );

        Ok(Self {
            config_path,
            config,
        })
    }

    pub fn get_config(&self) -> &CarConfiguration {
        &self.config
    }

    pub async fn update_config(&mut self, new_config: CarConfiguration) -> Result<()> {
        info!(
            "Updating car config: #{} {} ({}) -> #{} {} ({})",
            self.config.number,
            self.config.driver_name,
            self.config.team_name,
            new_config.number,
            new_config.driver_name,
            new_config.team_name
        );

        self.config = new_config;
        Self::save_config(&self.config_path, &self.config).await?;

        Ok(())
    }

    async fn load_config(path: &Path) -> Result<CarConfiguration> {
        let content = fs::read_to_string(path)
            .await
            .with_context(|| format!("Failed to read config file: {}", path.display()))?;

        let config: CarConfiguration = toml::from_str(&content)
            .with_context(|| format!("Failed to parse config file: {}", path.display()))?;

        Ok(config)
    }

    async fn save_config(path: &Path, config: &CarConfiguration) -> Result<()> {
        let content = toml::to_string_pretty(config)
            .with_context(|| format!("Failed to serialize config: {}", path.display()))?;

        fs::write(path, content)
            .await
            .with_context(|| format!("Failed to write config file: {}", path.display()))?;

        Ok(())
    }
}
