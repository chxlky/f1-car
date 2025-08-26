use anyhow::{Context, Result};
use log::{debug, error, info, trace, warn};
use std::{io::ErrorKind, net::SocketAddr, sync::Arc, time::Duration};
use telemetry::{CarConfiguration, ControlMessage};
use tokio::{
    net::UdpSocket,
    sync::{Mutex, broadcast},
    time::timeout,
};
use tokio_util::sync::CancellationToken;

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
    connected_client: Arc<Mutex<Option<SocketAddr>>>,
}

impl RadioServer {
    pub async fn new() -> Result<Self> {
        let (control_tx, _) = broadcast::channel(100);
        let config_manager = Arc::new(Mutex::new(ConfigManager::new().await?));
        let discovery_service =
            Arc::new(Mutex::new(DiscoveryService::new(config_manager.clone())?));
        let connected_client = Arc::new(Mutex::new(None));

        Ok(Self {
            control_tx,
            config_manager,
            discovery_service,
            connected_client,
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
                // TODO: Broadcast control message to all UART
                if self.control_tx.receiver_count() > 0 {
                    let _ = self.control_tx.send(control_msg.clone());
                } else {
                    trace!("No control subscribers; skipping send");
                }
                debug!("Received control message: {control_msg:?}");
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
                info!("Client disconnected (send failed) : {client_addr}");

                let mut client = self.connected_client.lock().await;
                *client = None;
            }
            Err(_) => {
                warn!("Send to {client_addr} timed out");
                info!("Client disconnected (timeout): {client_addr}");

                let mut client = self.connected_client.lock().await;
                *client = None;
            }
        }
        Ok(())
    }

    async fn send_initial_config(&self, socket: &UdpSocket, client_addr: SocketAddr) {
        let config = self.get_car_config().await;
        let welcome_msg = ServerMessage::Config { config };

        if let Err(e) = self.send_to_client(socket, &welcome_msg, client_addr).await {
            error!("Failed to send welcome message to {client_addr}: {e}");
        }
    }

    pub async fn run(&self, cancel_token: CancellationToken) -> Result<()> {
        info!("Starting Radio Server...");

        let car_config = self.get_car_config().await;
        info!(
            "Car configuration: #{} {} ({})",
            car_config.number, car_config.driver_name, car_config.team_name
        );

        info!("Camera streaming is handled by UDP streamer on port 8080");

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
            tokio::select! {
                _ = cancel_token.cancelled() => {
                    info!("Cancellation requested, breaking server loop");
                    break;
                }
                result = socket.recv_from(&mut buffer) => {
                    match result {
                        Ok((len, client_addr)) => {
                            let data_str = str::from_utf8(&buffer[..len]).unwrap_or("<invalid UTF-8>");
                            trace!("UDP message received from {client_addr}: {data_str}");

                            // Add client to connected list if not already present
                            {
                                let mut client = self.connected_client.lock().await;
                                match *client {
                                    None => {
                                        *client = Some(client_addr);
                                        info!("Client connected: {client_addr}");

                                        self.send_initial_config(&socket, client_addr).await;
                                    }
                                    Some(existing_addr) => {
                                        if existing_addr != client_addr {
                                            info!(
                                                "Previous client {existing_addr} replaced by new client {client_addr}"
                                            );
                                            *client = Some(client_addr);

                                            self.send_initial_config(&socket, client_addr).await;
                                        }
                                    }
                                }
                            }

                            if len == 8 {
                                let seq = u32::from_le_bytes([
                                    buffer[0], buffer[1], buffer[2], buffer[3],
                                ]);
                                let left = i16::from_le_bytes([buffer[4], buffer[5]]);
                                let right = i16::from_le_bytes([buffer[6], buffer[7]]);

                                // Convert i16 -> -100..100 range for ControlMessage
                                let steering = ((right as f32) / 32767.0_f32 * 100.0).round() as i8;
                                let throttle = ((left as f32) / 32767.0_f32 * 100.0).round() as i8;

                                let ctrl = ControlMessage { steering, throttle };
                                debug!("Received joystick from {client_addr}: seq={} left={} right={} -> {:?}", seq, left, right, ctrl);

                                if self.control_tx.receiver_count() > 0 {
                                    let _ = self.control_tx.send(ctrl);
                                } else {
                                    debug!("No control subscribers; skipping send");
                                }
                                continue;
                            }

                            // Otherwise try to parse as JSON ClientMessage
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
            }
        }

        info!("Radio Server shutting down.");
        Ok(())
    }
}

impl Drop for RadioServer {
    fn drop(&mut self) {
        info!("RadioServer dropped, cleaning up resources");

        if let Ok(mut discovery_service) = self.discovery_service.try_lock()
            && let Err(e) = discovery_service.stop_advertising()
        {
            error!("Failed to stop mDNS advertising: {e}");
        }
    }
}
