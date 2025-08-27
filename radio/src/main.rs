use std::thread::JoinHandle;

use log::{LevelFilter, error, info};
use tokio_util::sync::CancellationToken;

mod accelerometer;
mod camera;
mod config;
mod discovery;
mod server;

use crate::accelerometer::Accelerometer;
use crate::{camera::MjpegStreamer, server::RadioServer};

async fn shutdown_poll(token: CancellationToken, handle: Option<JoinHandle<()>>) {
    token.cancel();
    if let Some(h) = handle {
        let _ = tokio::task::spawn_blocking(move || h.join()).await;
    }
}

#[tokio::main]
async fn main() {
    env_logger::Builder::from_default_env()
        .filter_level(LevelFilter::Debug)
        .init();

    info!("Starting F1 Car Radio with UDP Camera Streaming...");

    let accel = match Accelerometer::new() {
        Ok(a) => {
            info!("Accelerometer initialized");
            Some(a)
        }
        Err(e) => {
            error!("Failed to initialize accelerometer: {e}");
            None
        }
    };

    let cancel_token = CancellationToken::new();
    let mut accel_opt = accel;

    let ctrl_token = cancel_token.clone();
    ctrlc::set_handler(move || {
        info!("SIGINT received, cancelling background tasks");
        ctrl_token.cancel();
    })
    .expect("Error setting Ctrl-C handler");

    let poll_handle = accel_opt
        .take()
        .map(|a| a.start_poller(cancel_token.clone(), 100));

    // Start UDP camera streamer
    tokio::spawn(async move {
        match MjpegStreamer::new().await {
            Ok(mut streamer) => {
                info!("UDP camera streamer initialized");
                if let Err(e) = streamer.start().await {
                    error!("Failed to start UDP streamer: {e}");
                }
            }
            Err(e) => {
                error!("Failed to create UDP streamer: {e}");
            }
        }
    });

    match RadioServer::new().await {
        Ok(server) => {
            if let Err(e) = server.run(cancel_token.clone()).await {
                error!("Radio server error: {e}");
                shutdown_poll(cancel_token.clone(), poll_handle).await;
                info!("Shutdown complete (error path), exiting");

                std::process::exit(1);
            } else {
                shutdown_poll(cancel_token.clone(), poll_handle).await;
                info!("Shutdown complete, exiting");
            }
        }
        Err(e) => {
            error!("Failed to initialize radio server: {e}");
            shutdown_poll(cancel_token.clone(), poll_handle).await;
            info!("Shutdown complete (init error), exiting");

            std::process::exit(1);
        }
    }
}
