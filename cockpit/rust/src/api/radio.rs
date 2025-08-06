use anyhow::{anyhow, Context, Result};
use flutter_rust_bridge::frb;
use log::{error, info, warn};
use std::net::SocketAddr;
use std::sync::Arc;
use telemetry::{ClientMessage, ServerMessage as TelemetryServerMessage};
use tokio::net::UdpSocket;
use tokio::sync::Mutex;

use crate::api::models::{self, F1Car, ServerMessage};
use crate::frb_generated::StreamSink;

#[derive(Debug, Clone)]
pub enum RadioEvent {
    Connected,
    Disconnected,
    Message(ServerMessage),
    Error(String),
}

#[derive(Debug)]
struct RadioState {
    socket: Option<Arc<UdpSocket>>,
    server_addr: Option<SocketAddr>,
}

#[derive(Debug, Clone)]
pub struct UdpRadioService {
    state: Arc<Mutex<RadioState>>,
}

impl Default for UdpRadioService {
    fn default() -> Self {
        Self::new()
    }
}

impl UdpRadioService {
    #[frb(sync)]
    pub fn new() -> Self {
        Self {
            state: Arc::new(Mutex::new(RadioState {
                socket: None,
                server_addr: None,
            })),
        }
    }

    pub fn connect(&self, car: F1Car, sink: StreamSink<RadioEvent>) -> Result<()> {
        let service = self.clone();

        tokio::spawn(async move {
            let result: Result<()> = async {
                info!("Connecting to car #{}...", car.number);

                let ip_addr = car
                    .ip_address
                    .ok_or_else(|| anyhow!("Car has no IP address"))?;
                let port = car.port.ok_or_else(|| anyhow!("Car has no port"))?;
                let server_addr: SocketAddr = format!("{ip_addr}:{port}")
                    .parse()
                    .context("Invalid server address")?;

                let socket = UdpSocket::bind("0.0.0.0:0")
                    .await
                    .context("Failed to bind UDP socket")?;
                let socket = Arc::new(socket);

                {
                    let mut state = service.state.lock().await;
                    state.socket = Some(socket.clone());
                    state.server_addr = Some(server_addr);
                }

                let sink_clone = sink.clone();
                let state_clone = service.state.clone();

                tokio::spawn(async move {
                    let mut buf = [0; 4096];
                    loop {
                        match socket.recv_from(&mut buf).await {
                            Ok((len, _)) => {
                                let data = &buf[..len];
                                match serde_json::from_slice::<TelemetryServerMessage>(data) {
                                    Ok(msg) => {
                                        if sink_clone.add(RadioEvent::Message(msg.into())).is_err() {
                                            warn!("Failed to send message to stream sink.");
                                        }
                                    }
                                    Err(e) => {
                                        warn!("Failed to parse message: {e}");
                                    }
                                }
                            }
                            Err(e) => {
                                error!("Failed to receive from socket: {e}");
                                let _ = sink_clone.add(RadioEvent::Error(e.to_string()));
                                break;
                            }
                        }
                    }
                    let mut state = state_clone.lock().await;
                    state.socket.take();
                    let _ = sink_clone.add(RadioEvent::Disconnected);
                });

                service.ping().await?;
                service.request_identity().await?;
                service.request_physics().await?;

                info!("Successfully connected to car #{}", car.number);
                if sink.add(RadioEvent::Connected).is_err() {
                    warn!("Failed to send Connected event to sink");
                }

                Ok(())
            }
            .await;

            if let Err(e) = result {
                error!("Connection failed: {}", e.to_string());
                if sink.add(RadioEvent::Error(e.to_string())).is_err() {
                    error!("Failed to send error to stream sink.");
                }
            }
        });

        Ok(())
    }

    pub async fn disconnect(&self) -> Result<()> {
        let mut state = self.state.lock().await;
        if state.socket.take().is_some() {
            info!("Disconnecting from radio service.");
        }
        state.server_addr = None;
        Ok(())
    }

    pub async fn send_control(&self, steering: i32, throttle: i32) -> Result<()> {
        self.send_message(ClientMessage::Control { steering, throttle })
            .await
    }

    pub async fn ping(&self) -> Result<()> {
        self.send_message(ClientMessage::Ping {
            timestamp: chrono::Utc::now().timestamp_millis(),
        })
        .await
    }

    pub async fn request_identity(&self) -> Result<()> {
        self.send_message(ClientMessage::IdentityRequest).await
    }

    pub async fn request_physics(&self) -> Result<()> {
        self.send_message(ClientMessage::PhysicsRequest).await
    }

    pub async fn update_identity(&self, identity: models::CarIdentity) -> Result<()> {
        self.send_message(ClientMessage::IdentityUpdate {
            identity: identity.into(),
        })
        .await
    }

    pub async fn update_physics(&self, physics: models::CarPhysics) -> Result<()> {
        self.send_message(ClientMessage::PhysicsUpdate {
            physics: physics.into(),
        })
        .await
    }

    async fn send_message(&self, message: ClientMessage) -> Result<()> {
        let state = self.state.lock().await;
        let socket = state
            .socket
            .as_ref()
            .ok_or_else(|| anyhow!("Not connected"))?;
        let server_addr = state
            .server_addr
            .ok_or_else(|| anyhow!("Server address not set"))?;

        let data = serde_json::to_vec(&message)?;
        socket
            .send_to(&data, server_addr)
            .await
            .context("Failed to send message")?;
        Ok(())
    }
}