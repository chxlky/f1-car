use anyhow::{anyhow, Result};
use log::{debug, error};
use telemetry::ControlMessage;
use tokio::{io::AsyncWriteExt, sync::broadcast};
use tokio_serial::{SerialPortBuilderExt, SerialStream};

pub struct UartHandler {
    port: SerialStream,
}

impl UartHandler {
    pub async fn new(port_path: &str) -> Result<Self> {
        let port = tokio_serial::new(port_path, 115200)
            .open_native_async()
            .map_err(|e| anyhow!("Failed to open UART port {port_path}: {e}"))?;

        Ok(Self { port })
    }

    pub async fn run(mut self, mut rx: broadcast::Receiver<ControlMessage>) -> Result<()> {
        loop {
            match rx.recv().await {
                Ok(msg) => {
                    debug!("Sending control message over UART: {msg:?}");
                    let buf = [msg.steering as u8, msg.throttle as u8];
                    if let Err(e) = self.port.write_all(&buf).await {
                        error!("Failed to send UART data: {}", e);
                    }
                }
                Err(e) => {
                    error!("UART handler receiver error: {e}");
                    break;
                }
            }
        }

        Ok(())
    }
}
