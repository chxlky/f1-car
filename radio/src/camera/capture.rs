use anyhow::{Result, anyhow};
use log::{error, info, trace};
use std::process::Stdio;
use std::sync::{Arc, Mutex};
use std::time::Duration;
use tokio::{
    io::{AsyncReadExt, BufReader},
    process,
    time::sleep,
};

#[derive(Clone)]
pub struct CameraCapture {
    frame_buffer: Arc<Mutex<Option<Vec<u8>>>>,
    is_running: Arc<Mutex<bool>>,
}

impl CameraCapture {
    pub fn new(frame_buffer: Arc<Mutex<Option<Vec<u8>>>>) -> Self {
        Self {
            frame_buffer,
            is_running: Arc::new(Mutex::new(false)),
        }
    }

    pub async fn start(&self) -> Result<()> {
        // Check if already running
        {
            let running = self.is_running.lock().unwrap();
            if *running {
                info!("Camera capture is already running");
                return Ok(());
            }
        }

        info!("Starting camera capture with rpicam-vid MJPEG...");

        // Set running state
        {
            let mut running = self.is_running.lock().unwrap();
            *running = true;
        }

        // Clone what we need for the spawned task
        let frame_buffer = self.frame_buffer.clone();
        let is_running = self.is_running.clone();

        tokio::spawn(async move {
            let mut frame_counter = 0u32;

            loop {
                // Check if we should stop
                let should_continue = {
                    let running = is_running.lock().unwrap();
                    *running
                };

                if !should_continue {
                    break;
                }

                // Start the camera process
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
                    .stderr(Stdio::null())
                    .spawn()
                {
                    Ok(child) => child,
                    Err(e) => {
                        error!("Failed to start rpicam-vid: {e}");
                        sleep(Duration::from_secs(5)).await;
                        continue;
                    }
                };

                if let Some(stdout) = child.stdout.take() {
                    let mut reader = BufReader::new(stdout);
                    let mut buffer = Vec::new();
                    let mut temp_buf = [0u8; 8192];

                    loop {
                        // Check if we should stop
                        let should_continue = {
                            let running = is_running.lock().unwrap();
                            *running
                        };

                        if !should_continue {
                            let _ = child.kill().await;
                            break;
                        }

                        match reader.read(&mut temp_buf).await {
                            Ok(0) => {
                                // EOF - process ended
                                break;
                            }
                            Ok(n) => {
                                buffer.extend_from_slice(&temp_buf[..n]);

                                // Look for complete JPEG frames
                                while let Some(start) = Self::find_jpeg_start(&buffer) {
                                    if let Some(end) = Self::find_jpeg_end(&buffer[start..]) {
                                        let frame_end = start + end + 2;
                                        let frame = buffer[start..frame_end].to_vec();
                                        buffer.drain(..frame_end);

                                        // Update the frame buffer
                                        if let Ok(mut current_frame) = frame_buffer.lock() {
                                            *current_frame = Some(frame);
                                            frame_counter += 1;

                                            if frame_counter % 100 == 0 {
                                                trace!("Captured {frame_counter} frames");
                                            }
                                        }
                                    } else {
                                        break;
                                    }
                                }
                            }
                            Err(e) => {
                                error!("Error reading from camera: {e}");
                                break;
                            }
                        }
                    }
                }

                let _ = child.kill().await;
                let _ = child.wait().await;

                // Check if we should restart
                let should_restart = {
                    let running = is_running.lock().unwrap();
                    *running
                };

                if !should_restart {
                    break;
                }

                // Brief delay before restart
                sleep(Duration::from_millis(100)).await;
            }

            // Clear running state
            {
                let mut running = is_running.lock().unwrap();
                *running = false;
            }

            info!("Camera capture task ended");
        });

        Ok(())
    }

    pub async fn stop(&self) -> Result<()> {
        info!("Stopping camera capture...");

        // Set running to false
        {
            let mut running = self.is_running.lock().unwrap();
            *running = false;
        }

        // Clear the frame buffer
        {
            let mut buffer = self.frame_buffer.lock().unwrap();
            *buffer = None;
        }

        info!("Camera capture stopped");
        Ok(())
    }

    pub fn is_running(&self) -> Result<bool> {
        let running = self
            .is_running
            .lock()
            .map_err(|e| anyhow!("Mutex poisoned: {}", e))?;
        Ok(*running)
    }

    fn find_jpeg_start(buffer: &[u8]) -> Option<usize> {
        buffer.windows(2).position(|w| w == [0xFF, 0xD8])
    }

    fn find_jpeg_end(buffer: &[u8]) -> Option<usize> {
        buffer.windows(2).position(|w| w == [0xFF, 0xD9])
    }
}
