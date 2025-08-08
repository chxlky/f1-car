use anyhow::Result;
use log::{error, info};
use std::collections::HashMap;
use std::net::SocketAddr;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};
use tokio::{net::UdpSocket, time::sleep};

use super::CameraCapture;

type FrameBuffer = Arc<Mutex<Option<Vec<u8>>>>;

pub struct UdpStreamer {
    socket: Arc<UdpSocket>,
    clients: Arc<Mutex<HashMap<SocketAddr, Instant>>>,
    frame_buffer: FrameBuffer,
    camera_capture: Option<CameraCapture>,
}

impl UdpStreamer {
    pub async fn new() -> Result<Self> {
        let socket = UdpSocket::bind("0.0.0.0:8081").await?;
        info!("UDP streamer listening on 0.0.0.0:8081");

        let frame_buffer = Arc::new(Mutex::new(None));
        let camera_capture = CameraCapture::new(frame_buffer.clone());

        Ok(Self {
            socket: Arc::new(socket),
            clients: Arc::new(Mutex::new(HashMap::new())),
            frame_buffer,
            camera_capture: Some(camera_capture),
        })
    }

    pub async fn start(&mut self) -> Result<()> {
        if let Some(camera) = &self.camera_capture {
            camera.start().await?;
        }

        self.start_client_discovery().await?;
        self.start_frame_broadcaster().await?;

        Ok(())
    }

    async fn start_client_discovery(&self) -> Result<()> {
        let socket = self.socket.clone();
        let clients = self.clients.clone();

        tokio::spawn(async move {
            let mut buffer = [0u8; 1024];

            loop {
                match socket.recv_from(&mut buffer).await {
                    Ok((len, addr)) => {
                        let message = String::from_utf8_lossy(&buffer[..len]);

                        if message == "DISCOVER" {
                            info!("New client discovered: {addr}");

                            if let Ok(mut clients_map) = clients.lock() {
                                clients_map.insert(addr, Instant::now());
                            }

                            // Send discovery response
                            if let Err(e) = socket.send_to(b"CAMERA_SERVER", addr).await {
                                error!("Failed to send discovery response to {addr}: {e}");
                            }
                        }
                    }
                    Err(e) => {
                        error!("Error receiving UDP message: {e}");
                    }
                }
            }
        });

        let clients_cleanup = self.clients.clone();
        tokio::spawn(async move {
            loop {
                sleep(Duration::from_secs(30)).await;

                if let Ok(mut clients_map) = clients_cleanup.lock() {
                    let now = Instant::now();
                    clients_map.retain(|addr, last_seen| {
                        let keep = now.duration_since(*last_seen) < Duration::from_secs(60);
                        if !keep {
                            info!("Removing inactive client: {addr}");
                        }
                        keep
                    });
                }
            }
        });

        Ok(())
    }

    async fn start_frame_broadcaster(&self) -> Result<()> {
        let socket = self.socket.clone();
        let clients = self.clients.clone();
        let frame_buffer = self.frame_buffer.clone();

        tokio::spawn(async move {
            let mut frame_id = 0u32;

            loop {
                // Check if we have a frame to send
                let frame_data = {
                    if let Ok(buffer) = frame_buffer.lock() {
                        buffer.clone()
                    } else {
                        None
                    }
                };

                if let Some(frame) = frame_data {
                    // Get current clients
                    let client_addrs: Vec<SocketAddr> = {
                        if let Ok(clients_map) = clients.lock() {
                            clients_map.keys().cloned().collect()
                        } else {
                            Vec::new()
                        }
                    };

                    if !client_addrs.is_empty() {
                        // Send frame to all clients using chunked protocol
                        Self::send_chunked_frame(&socket, &client_addrs, &frame, frame_id).await;
                        frame_id = frame_id.wrapping_add(1);
                    }
                }

                // Send frames at ~30fps
                sleep(Duration::from_millis(33)).await;
            }
        });

        Ok(())
    }

    async fn send_chunked_frame(
        socket: &UdpSocket,
        clients: &[SocketAddr],
        frame: &[u8],
        frame_id: u32,
    ) {
        const MAX_CHUNK_SIZE: usize = 1400; // Safe UDP payload size
        const HEADER_SIZE: usize = 10; // frame_id(4) + chunk_id(2) + total_chunks(2) + data_len(2)
        const DATA_SIZE: usize = MAX_CHUNK_SIZE - HEADER_SIZE;

        let total_chunks = frame.len().div_ceil(DATA_SIZE);

        if total_chunks > u16::MAX as usize {
            error!("Frame too large to send: {} bytes", frame.len());
            return;
        }

        for chunk_id in 0..total_chunks {
            let start = chunk_id * DATA_SIZE;
            let end = std::cmp::min(start + DATA_SIZE, frame.len());
            let chunk_data = &frame[start..end];

            // Create packet: [frame_id:4][chunk_id:2][total_chunks:2][data_len:2][data...]
            let mut packet = Vec::with_capacity(HEADER_SIZE + chunk_data.len());
            packet.extend_from_slice(&frame_id.to_be_bytes());
            packet.extend_from_slice(&(chunk_id as u16).to_be_bytes());
            packet.extend_from_slice(&(total_chunks as u16).to_be_bytes());
            packet.extend_from_slice(&(chunk_data.len() as u16).to_be_bytes());
            packet.extend_from_slice(chunk_data);

            for &client_addr in clients {
                if let Err(e) = socket.send_to(&packet, client_addr).await {
                    error!("Failed to send chunk {chunk_id} to {client_addr}: {e}");
                }
            }
        }
    }

    pub async fn stop(&mut self) -> Result<()> {
        info!("Stopping UDP streamer...");
        // UDP streamer doesn't manage camera processes directly
        // Camera capture is handled in a separate spawned task
        Ok(())
    }
}
