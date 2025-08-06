use anyhow::{Context, Result};
use log::{debug, error, info, warn};
use std::{io::ErrorKind, net::SocketAddr, sync::Arc, time::Duration};
use telemetry::{CarIdentity, CarPhysics, ClientMessage, ServerMessage};
use tokio::{
    net::UdpSocket,
    sync::{Mutex, broadcast},
    time::timeout,
};

use crate::{config::ConfigManager, discovery::DiscoveryService};

pub struct RadioServer {
    control_tx: broadcast::Sender<ClientMessage>,
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

    pub async fn get_car_identity(&self) -> CarIdentity {
        let config_manager = self.config_manager.lock().await;
        config_manager.get_identity().clone()
    }

    pub async fn get_car_physics(&self) -> CarPhysics {
        let config_manager = self.config_manager.lock().await;
        config_manager.get_physics().clone()
    }

    pub async fn update_car_identity(&self, identity: CarIdentity) -> Result<()> {
        {
            let mut config_manager = self.config_manager.lock().await;
            config_manager.update_identity(identity).await?;
        }

        let mut discovery_service = self.discovery_service.lock().await;
        discovery_service.update_service(8080).await?;

        Ok(())
    }

    pub async fn update_car_physics(&self, physics: CarPhysics) -> Result<()> {
        let mut config_manager = self.config_manager.lock().await;
        config_manager.update_physics(physics).await
    }

    async fn handle_client_message(
        &self,
        message: ClientMessage,
        client_addr: SocketAddr,
        socket: &UdpSocket,
    ) -> Result<()> {
        match message {
            ClientMessage::Control { .. } => {
                debug!("Received control message: {message:?}");
            }
            ClientMessage::IdentityRequest => {
                let car_identity = self.get_car_identity().await;
                let response = ServerMessage::Identity {
                    identity: car_identity,
                };
                self.send_to_client(socket, &response, client_addr).await?;
            }
            ClientMessage::PhysicsRequest => {
                let car_physics = self.get_car_physics().await;
                let response = ServerMessage::Physics {
                    physics: car_physics,
                };
                self.send_to_client(socket, &response, client_addr).await?;
            }
            ClientMessage::IdentityUpdate { identity } => {
                info!(
                    "Received identity update from {}: #{} {} ({})",
                    client_addr, identity.number, identity.driver_name, identity.team_name
                );

                let response = match self.update_car_identity(identity).await {
                    Ok(()) => {
                        info!("Car identity updated successfully");
                        ServerMessage::IdentityUpdated {
                            success: true,
                            message: "Identity updated successfully".to_string(),
                        }
                    }
                    Err(e) => {
                        error!("Failed to update car identity: {e}");
                        ServerMessage::IdentityUpdated {
                            success: false,
                            message: format!("Failed to update identity: {e}"),
                        }
                    }
                };

                self.send_to_client(socket, &response, client_addr).await?;
            }
            ClientMessage::PhysicsUpdate { physics } => {
                info!("Received physics update from {client_addr}");

                let response = match self.update_car_physics(physics).await {
                    Ok(()) => {
                        info!("Car physics updated successfully");
                        ServerMessage::PhysicsUpdated {
                            success: true,
                            message: "Physics updated successfully".to_string(),
                        }
                    }
                    Err(e) => {
                        error!("Failed to update car physics: {e}");
                        ServerMessage::PhysicsUpdated {
                            success: false,
                            message: format!("Failed to update physics: {e}"),
                        }
                    }
                };

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

    async fn send_initial_configs(&self, socket: &UdpSocket, client_addr: SocketAddr) {
        let identity = self.get_car_identity().await;
        let identity_msg = ServerMessage::Identity { identity };

        if let Err(e) = self
            .send_to_client(socket, &identity_msg, client_addr)
            .await
        {
            error!("Failed to send identity message to {client_addr}: {e}");
        }

        let physics = self.get_car_physics().await;
        let physics_msg = ServerMessage::Physics { physics };

        if let Err(e) = self.send_to_client(socket, &physics_msg, client_addr).await {
            error!("Failed to send physics message to {client_addr}: {e}");
        }
    }

    pub async fn run(&self) -> Result<()> {
        info!("Starting Radio Server...");

        let car_identity = self.get_car_identity().await;
        info!(
            "Car configuration: #{} {} ({})",
            car_identity.number, car_identity.driver_name, car_identity.team_name
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
                    let data_str = std::str::from_utf8(&buffer[..len]).unwrap_or("<invalid UTF-8>");
                    debug!("UDP message received from {client_addr}: {data_str}");

                    // Add client to connected list if not already present
                    {
                        let mut client = self.connected_client.lock().await;
                        match *client {
                            None => {
                                *client = Some(client_addr);
                                info!("Client connected: {client_addr}");

                                self.send_initial_configs(&socket, client_addr).await;
                            }
                            Some(existing_addr) => {
                                if existing_addr != client_addr {
                                    info!(
                                        "Previous client {existing_addr} replaced by new client {client_addr}"
                                    );
                                    *client = Some(client_addr);

                                    self.send_initial_configs(&socket, client_addr).await;
                                }
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
