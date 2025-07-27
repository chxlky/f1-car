use log::{LevelFilter, error, info};

mod config;
mod discovery;
mod server;

use server::RadioServer;

#[tokio::main]
async fn main() {
    env_logger::Builder::from_default_env()
        .filter_level(LevelFilter::Debug)
        .init();

    info!("Starting Pi Radio...");

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
