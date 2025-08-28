use std::net::SocketAddr;
use std::time::{Duration, Instant};

use futures::StreamExt;
use log::{error, debug, info};
use tokio::net::{TcpListener, UdpSocket};
use tokio::sync::mpsc::{self, error::TrySendError, Receiver};
use tokio::sync::watch;
use tokio::task::JoinHandle;
use tokio_tungstenite::accept_async;
use tokio_tungstenite::tungstenite::Message;

#[derive(Debug, Clone, Copy)]
pub struct Sample {
    pub ts: Instant,
    pub x: f32,
    pub y: f32,
    pub seq: u32,
}

pub async fn start_joystick_service(
    ws_port: u16,
    pi_addr: SocketAddr,
    mut shutdown_rx: watch::Receiver<bool>,
) {
    let (tx, rx) = mpsc::channel::<Sample>(512);

    tokio::spawn(processor_task(rx, pi_addr));

    let bind_addr = format!("127.0.0.1:{}", ws_port);
    let listener = match TcpListener::bind(&bind_addr).await {
        Ok(l) => l,
        Err(e) => {
            error!("Failed to bind websocket listener {}: {}", bind_addr, e);
            return;
        }
    };

    info!("joystick ws listening on {}", bind_addr);

    // keep track of spawned client tasks so we can abort them on shutdown
    let mut client_handles: Vec<JoinHandle<()>> = Vec::new();

    loop {
        tokio::select! {
            accept = listener.accept() => {
                match accept {
                    Ok((stream, addr)) => {
                        let tx = tx.clone();
                        let handle = tokio::spawn(async move {
                            if let Ok(ws_stream) = accept_async(stream).await {
                                let mut ws = ws_stream;
                                info!("joystick client connected: {}", addr);
                                while let Some(msg) = ws.next().await {
                                    match msg {
                                        Ok(Message::Binary(b)) if b.len() >= 4 => {
                                            // info!("WS binary recv len={} bytes={:02x?}", b.len(), &b);
                                            let xi = i16::from_le_bytes([b[0], b[1]]);
                                            let yi = i16::from_le_bytes([b[2], b[3]]);

                                            // info!("WS parsed xi={} yi={}", xi, yi);

                                            let xf = (xi as f32) / 32767.0;
                                            let yf = (yi as f32) / 32767.0;

                                            let sample = Sample {
                                                ts: Instant::now(),
                                                x: xf,
                                                y: yf,
                                                seq: 0,
                                            };

                                            // try to enqueue, drop on full
                                            match tx.try_send(sample) {
                                                Ok(_) => {}
                                                Err(TrySendError::Full(_)) => {
                                                    // queue full: drop sample
                                                }
                                                Err(TrySendError::Closed(_)) => break,
                                            }
                                        }
                                        Ok(Message::Close(_)) | Err(_) => break,
                                        _ => {}
                                    }
                                }
                            }
                        });
                        client_handles.push(handle);
                    }
                    Err(e) => {
                        error!("accept error: {}", e);
                    }
                }
            }
            _ = shutdown_rx.changed() => {
                if *shutdown_rx.borrow() {
                    info!("joystick shutdown requested");
                    // abort all client handlers so their tx clones drop
                    for h in client_handles.iter() {
                        h.abort();
                    }
                    // drop our own tx so the processor receives None and can send final idle
                    drop(tx);
                    break;
                }
            }
        }
    }
}

async fn processor_task(mut rx: Receiver<Sample>, pi_addr: SocketAddr) {
    let udp = match UdpSocket::bind("0.0.0.0:0").await {
        Ok(s) => s,
        Err(e) => {
            error!("Failed to bind UDP socket: {}", e);
            return;
        }
    };

    let mut seq: u32 = 0;
    let mut last_sample_time = Instant::now();

    let mut last_x = 0.0f32;
    let mut last_y = 0.0f32;
    let alpha = 0.12f32; // low-pass factor
    let deadzone = 0.04f32;

    loop {
        tokio::select! {
            maybe = rx.recv() => {
                match maybe {
                    Some(s) => {
                        last_sample_time = Instant::now();
                        // heavy math in Rust
                        let mut x = s.x;
                        let mut y = s.y;

                        // deadzone
                        if (x*x + y*y).sqrt() < deadzone {
                            x = 0.0; y = 0.0;
                        }

                        // low-pass filter
                        last_x = alpha * x + (1.0 - alpha) * last_x;
                        last_y = alpha * y + (1.0 - alpha) * last_y;

                        let left = last_y;   // throttle
                        let right = last_x;  // steering

                        // clamp
                        let li = (left.clamp(-1.0, 1.0) * 32767.0) as i16;
                        let ri = (right.clamp(-1.0, 1.0) * 32767.0) as i16;

                        // packet: [seq:u32 LE][li:i16 LE][ri:i16 LE] = 8 bytes
                        let mut buf = [0u8;8];
                        buf[0..4].copy_from_slice(&seq.to_le_bytes());
                        buf[4..6].copy_from_slice(&li.to_le_bytes());
                        buf[6..8].copy_from_slice(&ri.to_le_bytes());

                        debug!("Sending joystick packet seq={} li={} ri={} bytes={:02x?}", seq, li, ri, &buf);
                        if let Err(e) = udp.send_to(&buf, &pi_addr).await {
                            error!("UDP send error: {}", e);
                        }

                        seq = seq.wrapping_add(1);
                    }
                    None => {
                        // channel closed; send safe/idle packet then exit
                        // send a final idle packet
                        let idle = [0u8;8];
                        debug!("Sending final idle packet bytes={:02x?}", &idle);
                        let _ = udp.send_to(&idle, &pi_addr).await;
                        break;
                    }
                }
            }
            // watchdog: if no samples for 200ms, send idle periodically
            _ = tokio::time::sleep(Duration::from_millis(200)) => {
                if last_sample_time.elapsed() > Duration::from_millis(200) {
                    // send idle command
                    let mut buf = [0u8;8];
                    buf[0..4].copy_from_slice(&seq.to_le_bytes());
                    buf[4..6].copy_from_slice(&0i16.to_le_bytes());
                    buf[6..8].copy_from_slice(&0i16.to_le_bytes());
                    debug!("Watchdog idle send seq={} bytes={:02x?}", seq, &buf);
                    let _ = udp.send_to(&buf, &pi_addr).await;
                    seq = seq.wrapping_add(1);
                }
            }
        }
    }
}
