use anyhow::{Context, Result};
use log::{error, info, warn};
use std::{io::ErrorKind, net::SocketAddr, sync::Arc, time::Duration};
use telemetry::{CarConfiguration, ControlMessage};
use tokio::{
    net::UdpSocket,
    sync::{Mutex, broadcast},
    time::timeout,
};

use crate::{config::ConfigManager, discovery::DiscoveryService};

#[derive(serde::Deserialize, Debug)]
#[serde(tag = "type")]
enum ClientMessage {
    #[serde(rename = "control")]
    Control(ControlMessage),
    #[serde(rename = "config_update")]
    ConfigUpdate { config: CarConfiguration },
    #[serde(rename = "config_request")]
    ConfigRequest,
    #[serde(rename = "ping")]
    Ping { timestamp: u64 },
}

#[derive(serde::Serialize, Debug)]
#[serde(tag = "type")]
enum ServerMessage {
    #[serde(rename = "config")]
    Config { config: CarConfiguration },
    #[serde(rename = "config_updated")]
    ConfigUpdated { success: bool, message: String },
    #[serde(rename = "pong")]
    Pong { timestamp: u64 },
}

pub struct RadioServer {
    control_tx: broadcast::Sender<ControlMessage>,
    config_manager: Arc<Mutex<ConfigManager>>,
    discovery_service: Arc<Mutex<DiscoveryService>>,
    connected_clients: Arc<Mutex<Vec<SocketAddr>>>,
}

impl RadioServer {
    pub async fn new() -> Result<Self> {
        let (control_tx, _) = broadcast::channel(100);
        let config_manager = Arc::new(Mutex::new(ConfigManager::new().await?));
        let discovery_service =
            Arc::new(Mutex::new(DiscoveryService::new(config_manager.clone())?));
        let connected_clients = Arc::new(Mutex::new(Vec::new()));

        Ok(Self {
            control_tx,
            config_manager,
            discovery_service,
            connected_clients,
        })
    }

    pub async fn get_car_config(&self) -> CarConfiguration {
        let config_manager = self.config_manager.lock().await;
        config_manager.get_config().clone()
    }

    pub async fn update_car_config(&self, config: CarConfiguration) -> Result<()> {
        {
            let mut config_manager = self.config_manager.lock().await;
            config_manager.update_config(config).await?;
        }

        let mut discovery_service = self.discovery_service.lock().await;
        discovery_service.update_service(8080).await?;

        Ok(())
    }

    async fn handle_client_message(
        &self,
        message: ClientMessage,
        client_addr: SocketAddr,
        socket: &UdpSocket,
    ) -> Result<()> {
        match message {
            ClientMessage::Control(control_msg) => {
                // Forward control message to UART/STM32
                if let Err(e) = self.control_tx.send(control_msg) {
                    error!("Failed to send control message: {e}");
                }
            }
            ClientMessage::ConfigUpdate { config } => {
                info!(
                    "Received config update from {}: #{} {} ({})",
                    client_addr, config.number, config.driver_name, config.team_name
                );

                let response = match self.update_car_config(config).await {
                    Ok(()) => {
                        info!("Car configuration updated successfully");
                        ServerMessage::ConfigUpdated {
                            success: true,
                            message: "Configuration updated successfully".to_string(),
                        }
                    }
                    Err(e) => {
                        error!("Failed to update car configuration: {e}",);
                        ServerMessage::ConfigUpdated {
                            success: false,
                            message: format!("Failed to update configuration: {e}"),
                        }
                    }
                };

                self.send_to_client(socket, &response, client_addr).await?;
            }
            ClientMessage::ConfigRequest => {
                let car_config = self.get_car_config().await;
                let response = ServerMessage::Config { config: car_config };
                self.send_to_client(socket, &response, client_addr).await?;
            }
            ClientMessage::Ping { timestamp } => {
                let response = ServerMessage::Pong { timestamp };
                self.send_to_client(socket, &response, client_addr).await?;
            }
        }
        Ok(())
    }

    async fn send_to_client(
        &self,
        socket: &UdpSocket,
        message: &ServerMessage,
        client_addr: SocketAddr,
    ) -> Result<()> {
        let json = serde_json::to_string(message).context("Failed to serialize server message")?;

        match timeout(
            Duration::from_millis(100),
            socket.send_to(json.as_bytes(), client_addr),
        )
        .await
        {
            Ok(Ok(bytes_sent)) => {
                if bytes_sent != json.len() {
                    warn!(
                        "Partial send to {}: {} of {} bytes",
                        client_addr,
                        bytes_sent,
                        json.len()
                    );
                }
            }
            Ok(Err(e)) => {
                error!("Failed to send to {client_addr}: {e}");
                let mut clients = self.connected_clients.lock().await;
                clients.retain(|&addr| addr != client_addr);
            }
            Err(_) => {
                warn!("Send to {client_addr} timed out");
                let mut clients = self.connected_clients.lock().await;
                clients.retain(|&addr| addr != client_addr);
            }
        }
        Ok(())
    }

    pub async fn run(&self) -> Result<()> {
        info!("Starting Radio Server...");

        let car_config = self.get_car_config().await;
        info!(
            "Car configuration: #{} {} ({})",
            car_config.number, car_config.driver_name, car_config.team_name
        );

        {
            let mut discovery_service = self.discovery_service.lock().await;
            discovery_service.start_advertising(8080).await?;
        }

        let socket = UdpSocket::bind("0.0.0.0:8080")
            .await
            .context("Failed to bind UDP socket to port 8080")?;

        info!("UDP server listening on 0.0.0.0:8080");

        let socket = Arc::new(socket);

        let mut buffer = vec![0u8; 65507]; // Max UDP payload size

        loop {
            match socket.recv_from(&mut buffer).await {
                Ok((len, client_addr)) => {
                    // Add client to connected list if not already present
                    {
                        let mut clients = self.connected_clients.lock().await;
                        if !clients.contains(&client_addr) {
                            clients.push(client_addr);
                            info!("New UDP client connected: {client_addr}");

                            // Send initial configuration to new client
                            let car_config = self.get_car_config().await;
                            let welcome_msg = ServerMessage::Config { config: car_config };
                            if let Err(e) = self
                                .send_to_client(&socket, &welcome_msg, client_addr)
                                .await
                            {
                                error!("Failed to send welcome message to {client_addr}: {e}");
                            }
                        }
                    }

                    // Parse and handle the message
                    let message_str = match std::str::from_utf8(&buffer[..len]) {
                        Ok(s) => s,
                        Err(e) => {
                            error!("Invalid UTF-8 from {client_addr}: {e}");
                            continue;
                        }
                    };

                    match serde_json::from_str::<ClientMessage>(message_str) {
                        Ok(client_message) => {
                            if let Err(e) = self
                                .handle_client_message(client_message, client_addr, &socket)
                                .await
                            {
                                error!("Error handling message from {client_addr}: {e}");
                            }
                        }
                        Err(e) => {
                            error!(
                                "Failed to parse message from {client_addr}: {e} - Raw: {message_str}",
                            );
                        }
                    }
                }
                Err(e) => {
                    error!("Error receiving UDP message: {e}");

                    if matches!(e.kind(), ErrorKind::AddrNotAvailable | ErrorKind::AddrInUse) {
                        break;
                    }
                }
            }
        }

        info!("Radio Server shutting down.");
        Ok(())
    }
}

impl Drop for RadioServer {
    fn drop(&mut self) {
        info!("RadioServer dropped, cleaning up resources");

        if let Ok(mut discovery_service) = self.discovery_service.try_lock() {
            if let Err(e) = discovery_service.stop_advertising() {
                error!("Failed to stop mDNS advertising: {e}");
            }
        }
    }
}
