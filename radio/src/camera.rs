use anyhow::{Context, Result};
use log::{error, info};
use std::process::Stdio;
use tokio::{
    io::{AsyncReadExt, BufReader},
    process::{self, Child},
    sync::{
        broadcast::{self, Sender},
        mpsc::{self, UnboundedSender},
    },
    time,
};

pub struct CameraHandler {
    camera_process: Option<Child>,
    stream_tx: Sender<Vec<u8>>,
    control_tx: Option<UnboundedSender<CameraControl>>,
}

#[allow(dead_code)]
enum CameraControl {
    Pause,
    Resume,
    Stop,
}

impl CameraHandler {
    pub fn new() -> Self {
        let (stream_tx, _) = broadcast::channel(128); // Increased from 32 to 128

        Self {
            camera_process: None,
            stream_tx,
            control_tx: None,
        }
    }

    pub async fn start_mjpeg_stream(&mut self) -> Result<()> {
        info!("Starting MJPEG camera stream...");

        let (control_tx, mut control_rx) = mpsc::unbounded_channel::<CameraControl>();
        self.control_tx = Some(control_tx);

        // Resolutions that work: 640x480@30
        // Laggy: 640x480@60

        let mut camera_process = process::Command::new("rpicam-vid")
            .args([
                "--width", "1280",
                "--height", "720",
                "--framerate", "30",
                "--timeout", "0",
                "--output", "-",
                "--codec", "mjpeg",
                "--quality", "50",
                "--nopreview",
                "--hflip",
                "--vflip",
                "--inline"
            ])
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .context("Failed to start MJPEG camera stream. Ensure 'rpicam-vid' is installed and camera is connected.")?;

        let stdout = camera_process
            .stdout
            .take()
            .context("Failed to get camera stdout")?;
        self.camera_process = Some(camera_process);

        let stream_tx = self.stream_tx.clone();
        tokio::spawn(async move {
            let mut reader = BufReader::new(stdout);
            let mut frame_buffer = Vec::new();
            let mut temp_buffer = vec![0u8; 32768]; // Increased from 8192 to 32KB
            let mut is_paused = false;

            loop {
                // Check for control messages
                if let Ok(control) = control_rx.try_recv() {
                    match control {
                        CameraControl::Pause => {
                            info!("Pausing camera processing");
                            is_paused = true;
                        }
                        CameraControl::Resume => {
                            info!("Resuming camera processing");
                            is_paused = false;
                        }
                        CameraControl::Stop => {
                            info!("Stopping camera processing");
                            break;
                        }
                    }
                }

                if stream_tx.receiver_count() == 0 && !is_paused {
                    info!("No receivers, pausing processing");
                    is_paused = true;
                    continue;
                } else if stream_tx.receiver_count() > 0 && is_paused {
                    info!("Receivers available, resuming processing");
                    is_paused = false;
                }

                if is_paused {
                    time::sleep(time::Duration::from_millis(100)).await;
                    continue;
                }

                match reader.read(&mut temp_buffer).await {
                    Ok(0) => {
                        error!("MJPEG stream ended (EOF).");
                        break;
                    }
                    Ok(n) => {
                        frame_buffer.extend_from_slice(&temp_buffer[..n]);

                        let mut start_idx = None;
                        let mut end_idx = None;

                        for i in 0..frame_buffer.len().saturating_sub(1) {
                            if frame_buffer[i] == 0xFF && frame_buffer[i + 1] == 0xD8 {
                                start_idx = Some(i);
                                break;
                            }
                        }

                        if let Some(start) = start_idx {
                            for i in start..frame_buffer.len().saturating_sub(1) {
                                if frame_buffer[i] == 0xFF && frame_buffer[i + 1] == 0xD9 {
                                    end_idx = Some(i + 2);
                                    break;
                                }
                            }
                        }

                        if let (Some(start), Some(end)) = (start_idx, end_idx) {
                            let frame = frame_buffer[start..end].to_vec();
                            if let Err(e) = stream_tx.send(frame) {
                                // Only log error if there are receivers but send failed (e.g., channel full)
                                if stream_tx.receiver_count() > 0 {
                                    error!("Error broadcasting MJPEG data: {e}");
                                }
                            }
                            frame_buffer.drain(..end);
                        }

                        // Prevent buffer from growing too large (e.g., if no start/end markers are found)
                        if frame_buffer.len() > 1_000_000 {
                            error!("MJPEG frame buffer exceeded 1MB, clearing.");
                            frame_buffer.clear();
                        }
                    }
                    Err(e) => {
                        error!("Error reading MJPEG stream from rpicam-vid: {e}");
                        break;
                    }
                }
            }
            info!("MJPEG camera stream reader task finished.");
        });

        info!("MJPEG camera stream started successfully.");
        Ok(())
    }

    pub fn get_stream_receiver(&self) -> broadcast::Receiver<Vec<u8>> {
        self.stream_tx.subscribe()
    }

    pub async fn stop(&mut self) -> Result<()> {
        if let Some(mut process) = self.camera_process.take() {
            info!("Stopping camera stream...");
            process
                .kill()
                .await
                .context("Failed to kill camera process")?;

            match time::timeout(time::Duration::from_secs(5), process.wait()).await {
                Ok(Ok(status)) => info!("Camera process exited with status: {status}"),
                Ok(Err(e)) => error!("Error waiting for camera process: {e}"),
                Err(_) => {
                    error!("Camera process didn't exit within timeout, force killing");
                    let _ = process.kill().await;
                }
            }
        }
        Ok(())
    }
}

impl Drop for CameraHandler {
    fn drop(&mut self) {
        if let Some(mut process) = self.camera_process.take() {
            tokio::spawn(async move {
                let _ = process.kill().await;
            });
        }
    }
}
