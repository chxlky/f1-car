use anyhow::{Context, Result};
use log::{error, info, warn};
use std::net::SocketAddr;
use std::sync::Arc;
use tokio::net::UdpSocket;
use tokio::sync::Mutex;

use crate::camera::CameraHandler;

pub struct CameraStreamer {
    camera_handler: Arc<Mutex<CameraHandler>>,
    clients: Arc<Mutex<Vec<SocketAddr>>>,
    is_camera_started: Arc<Mutex<bool>>,
}

impl CameraStreamer {
    pub fn new(camera_handler: Arc<Mutex<CameraHandler>>) -> Self {
        Self {
            camera_handler,
            clients: Arc::new(Mutex::new(Vec::new())),
            is_camera_started: Arc::new(Mutex::new(false)),
        }
    }

    pub async fn start_udp_stream(&mut self, port: u16) -> Result<()> {
        let socket = UdpSocket::bind(format!("0.0.0.0:{port}"))
            .await
            .context("Failed to bind UDP socket for camera streaming")?;

        info!("Camera UDP stream listening on port {port}");

        let socket = Arc::new(socket);
        let clients = self.clients.clone();
        let camera_handler = self.camera_handler.clone();
        let is_camera_started = self.is_camera_started.clone();

        // Listen for client registration
        let socket_clone = socket.clone();
        let clients_clone = clients.clone();
        let camera_handler_clone = camera_handler.clone();
        let is_camera_started_clone = is_camera_started.clone();

        tokio::spawn(async move {
            let mut buffer = vec![0u8; 1024];
            loop {
                if let Ok((len, addr)) = socket_clone.recv_from(&mut buffer).await {
                    let message = String::from_utf8_lossy(&buffer[..len]);
                    if message == "CAMERA_SUBSCRIBE" {
                        info!("Camera client subscribed: {addr}");
                        let mut clients_lock = clients_clone.lock().await;

                        let was_empty = clients_lock.is_empty();
                        if !clients_lock.contains(&addr) {
                            clients_lock.push(addr);
                        }

                        // Start camera if this is the first client
                        if was_empty && !clients_lock.is_empty() {
                            drop(clients_lock); // Release lock before starting camera

                            let mut is_started = is_camera_started_clone.lock().await;
                            if !*is_started {
                                info!("Starting camera stream for first client");
                                let mut camera = camera_handler_clone.lock().await;
                                if let Err(e) = camera.start_mjpeg_stream().await {
                                    error!("Failed to start camera stream: {e}");
                                    continue;
                                }
                                *is_started = true;
                                info!("Camera stream started successfully");
                            }
                        }
                    } else if message == "CAMERA_UNSUBSCRIBE" {
                        info!("Camera client unsubscribed: {addr}");
                        let mut clients_lock = clients_clone.lock().await;
                        clients_lock.retain(|&x| x != addr);

                        // Stop camera if no clients remain
                        if clients_lock.is_empty() {
                            drop(clients_lock); // Release lock before stopping camera

                            let mut is_started = is_camera_started_clone.lock().await;
                            if *is_started {
                                info!("No clients remaining, stopping camera stream");
                                let mut camera = camera_handler_clone.lock().await;
                                if let Err(e) = camera.stop().await {
                                    error!("Failed to stop camera stream: {e}");
                                } else {
                                    *is_started = false;
                                    info!("Camera stream stopped to save CPU");
                                }
                            }
                        }
                    }
                }
            }
        });

        // Stream frames to subscribed clients - only when camera is running
        loop {
            // Check if camera is started and get stream
            let camera_rx = {
                let is_started = is_camera_started.lock().await;
                if *is_started {
                    let camera = camera_handler.lock().await;
                    Some(camera.get_stream_receiver())
                } else {
                    None
                }
            };

            if let Some(mut receiver) = camera_rx {
                let mut frame_count = 0u64;
                let mut last_log_time = std::time::Instant::now();

                loop {
                    // Check if we should still be streaming
                    let should_stream = {
                        let is_started = is_camera_started.lock().await;
                        *is_started
                    };

                    if !should_stream {
                        info!("Camera stopped, breaking from stream loop");
                        break;
                    }

                    match receiver.recv().await {
                        Ok(frame) => {
                            let clients_lock = clients.lock().await;
                            let current_clients = clients_lock.clone();
                            drop(clients_lock);

                            if current_clients.is_empty() {
                                continue; // No clients to send to
                            }

                            // Send frame to all subscribed clients
                            for client in &current_clients {
                                if let Err(e) = socket.send_to(&frame, client).await {
                                    if !e.to_string().contains("Message too large") {
                                        warn!("Failed to send frame to {client}: {e}");
                                    }
                                    // Remove failed client
                                    let mut clients_lock = clients.lock().await;
                                    clients_lock.retain(|&x| x != *client);
                                }
                            }

                            frame_count += 1;
                            if last_log_time.elapsed() >= std::time::Duration::from_secs(10) {
                                info!(
                                    "Streaming: {} frames sent (size: {}), {} clients",
                                    frame_count,
                                    frame.len(),
                                    current_clients.len()
                                );
                                last_log_time = std::time::Instant::now();
                            }
                        }
                        Err(_) => {
                            warn!("Camera stream receiver error, will retry");
                            break; // Break inner loop to get new receiver
                        }
                    }
                }
            } else {
                // Camera not started, wait a bit before checking again
                tokio::time::sleep(std::time::Duration::from_millis(500)).await;
            }
        }
    }
}
