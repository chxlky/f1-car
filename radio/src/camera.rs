use anyhow::Result;
use log::{error, info};
use std::collections::HashMap;
use std::net::SocketAddr;
use std::process::Stdio;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};
use tokio::{
    io::{AsyncReadExt, BufReader},
    net::UdpSocket,
    process,
    time::sleep,
};

pub struct UdpStreamer {
    socket: Arc<UdpSocket>,
    clients: Arc<Mutex<HashMap<SocketAddr, Instant>>>,
    frame_buffer: Arc<Mutex<Option<Vec<u8>>>>,
}

impl UdpStreamer {
    pub async fn new() -> Result<Self> {
        let socket = UdpSocket::bind("0.0.0.0:8081").await?;
        info!("UDP streamer listening on 0.0.0.0:8081");

        Ok(Self {
            socket: Arc::new(socket),
            clients: Arc::new(Mutex::new(HashMap::new())),
            frame_buffer: Arc::new(Mutex::new(None)),
        })
    }

    fn find_jpeg_start(buffer: &[u8]) -> Option<usize> {
        buffer.windows(2).position(|w| w == [0xFF, 0xD8])
    }

    fn find_jpeg_end(buffer: &[u8]) -> Option<usize> {
        buffer.windows(2).position(|w| w == [0xFF, 0xD9])
    }

    pub async fn start(&mut self) -> Result<()> {
        // Start camera capture
        self.start_camera_capture().await?;

        // Start client discovery
        self.start_client_discovery().await?;

        // Start frame broadcasting
        self.start_frame_broadcaster().await?;

        Ok(())
    }

    async fn start_camera_capture(&mut self) -> Result<()> {
        info!("Starting camera capture with rpicam-vid MJPEG...");

        let frame_buffer = self.frame_buffer.clone();

        tokio::spawn(async move {
            let mut frame_counter = 0u32;

            loop {
                let mut child = match process::Command::new("rpicam-vid")
                    .args([
                        "-t",
                        "0",
                        "--width",
                        "1600",
                        "--height",
                        "900",
                        "--framerate",
                        "30",
                        "--codec",
                        "mjpeg",
                        "--hflip",
                        "--vflip",
                        "--nopreview",
                        "-o",
                        "-",
                    ])
                    .stdout(Stdio::piped())
                    .stderr(Stdio::null()) // Suppress error output
                    .spawn()
                {
                    Ok(child) => child,
                    Err(e) => {
                        error!("Failed to start rpicam-vid: {e}");
                        sleep(Duration::from_secs(5)).await;
                        continue;
                    }
                };

                let stdout = child.stdout.take().expect("Failed to capture stdout");
                let mut reader = BufReader::new(stdout);
                let mut buffer = Vec::new();
                let mut temp_buf = [0u8; 8192];

                loop {
                    match reader.read(&mut temp_buf).await {
                        Ok(0) => break, // EOF
                        Ok(n) => {
                            buffer.extend_from_slice(&temp_buf[..n]);

                            // Look for complete JPEG frames
                            while let Some(start) = Self::find_jpeg_start(&buffer) {
                                if let Some(end) = Self::find_jpeg_end(&buffer[start..]) {
                                    let frame_end = start + end + 2;
                                    let frame = buffer[start..frame_end].to_vec();
                                    buffer.drain(..frame_end);

                                    // Update the global frame buffer
                                    if let Ok(mut current_frame) = frame_buffer.lock() {
                                        *current_frame = Some(frame);
                                        frame_counter += 1;

                                        if frame_counter % 100 == 0 {
                                            info!("Captured {frame_counter} frames");
                                        }
                                    }
                                } else {
                                    break; // Wait for more data
                                }
                            }
                        }
                        Err(e) => {
                            error!("Error reading from camera: {e}");
                            break;
                        }
                    }
                }

                let _ = child.kill().await;
                let _ = child.wait().await;

                // Restart after a brief delay
                sleep(Duration::from_millis(100)).await;
            }
        });

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

                            // Add client to our list
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

        // Client cleanup task
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

            // Send to all clients
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
