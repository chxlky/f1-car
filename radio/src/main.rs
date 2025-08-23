use log::{LevelFilter, error, info};

mod camera;
mod config;
mod discovery;
mod server;

use crate::{camera::UdpStreamer, server::RadioServer};

#[tokio::main]
async fn main() {
    env_logger::Builder::from_default_env()
        .filter_level(LevelFilter::Debug)
        .init();

    info!("Starting F1 Car Radio with UDP Camera Streaming...");

    // Start UDP camera streamer
    tokio::spawn(async move {
        match UdpStreamer::new().await {
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
            if let Err(e) = server.run().await {
                error!("Radio server error: {e}");
                std::process::exit(1);
            }
        }
        Err(e) => {
            error!("Failed to initialize radio server: {e}");
            std::process::exit(1);
        }
    }
}
