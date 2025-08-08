use anyhow::Result;
use log::{error, info};
use std::process::Stdio;
use std::sync::{Arc, Mutex};
use std::time::Duration;
use tokio::{
    io::{AsyncReadExt, BufReader},
    process,
    time::sleep,
};

pub struct CameraCapture {
    frame_buffer: Arc<Mutex<Option<Vec<u8>>>>,
}

impl CameraCapture {
    pub fn new(frame_buffer: Arc<Mutex<Option<Vec<u8>>>>) -> Self {
        Self { frame_buffer }
    }

    pub async fn start(&self) -> Result<()> {
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

    fn find_jpeg_start(buffer: &[u8]) -> Option<usize> {
        buffer.windows(2).position(|w| w == [0xFF, 0xD8])
    }

    fn find_jpeg_end(buffer: &[u8]) -> Option<usize> {
        buffer.windows(2).position(|w| w == [0xFF, 0xD9])
    }
}
