use std::net::SocketAddr;
use std::time::{Duration, Instant};

use futures::StreamExt;
use log::{error, info};
use tokio::sync::mpsc::{self, error::TrySendError, Receiver};
use tokio_tungstenite::tungstenite::Message;

#[derive(Debug, Clone, Copy)]
pub struct Sample {
    pub ts: Instant,
    pub x: f32,
    pub y: f32,
    pub seq: u32,
}

/// Start the joystick service: spawn a websocket server on `ws_port` and
/// forward processed control packets to `pi_addr` over UDP.
pub async fn start_joystick_service(ws_port: u16, pi_addr: SocketAddr) {
    // bounded channel capacity
    let (tx, rx) = mpsc::channel::<Sample>(512);

    // spawn processor task
    tokio::spawn(processor_task(rx, pi_addr));

    // spawn websocket server task
    let bind_addr = format!("127.0.0.1:{}", ws_port);
    let listener = match tokio::net::TcpListener::bind(&bind_addr).await {
        Ok(l) => l,
        Err(e) => {
            eprintln!("Failed to bind websocket listener {}: {}", bind_addr, e);
            return;
        }
    };

    println!("joystick ws listening on {}", bind_addr);

    loop {
        match listener.accept().await {
            Ok((stream, addr)) => {
                let tx = tx.clone();
                tokio::spawn(async move {
                    if let Ok(ws_stream) = tokio_tungstenite::accept_async(stream).await {
                        let mut ws = ws_stream;
                        println!("joystick client connected: {}", addr);
                        while let Some(msg) = ws.next().await {
                            match msg {
                                Ok(Message::Binary(b)) if b.len() >= 4 => {
                                    // log raw bytes received from websocket client for debugging
                                    info!("WS binary recv len={} bytes={:02x?}", b.len(), &b);
                                    let xi = i16::from_le_bytes([b[0], b[1]]);
                                    let yi = i16::from_le_bytes([b[2], b[3]]);
                                    info!("WS parsed xi={} yi={}", xi, yi);
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
            }
            Err(e) => {
                eprintln!("accept error: {}", e);
            }
        }
    }
}

async fn processor_task(mut rx: Receiver<Sample>, pi_addr: SocketAddr) {
    // UDP socket used to send control packets to Pi
    let udp = match tokio::net::UdpSocket::bind("0.0.0.0:0").await {
        Ok(s) => s,
        Err(e) => {
            eprintln!("Failed to bind UDP socket: {}", e);
            return;
        }
    };

    let mut seq: u32 = 0;
    let mut last_sample_time = Instant::now();

    // filter state
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

                        // Direct mapping: treat sample.y as throttle (left UDP field)
                        // and sample.x as steering (right UDP field). This keeps
                        // UI joysticks independent: left UI controls `throttle` and
                        // right UI controls `steering` (as wired in the frontend).
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

                        // log the packet details before sending so the rust console shows
                        info!("Sending joystick packet seq={} li={} ri={} bytes={:02x?}", seq, li, ri, &buf);
                        if let Err(e) = udp.send_to(&buf, &pi_addr).await {
                            error!("UDP send error: {}", e);
                        }

                        seq = seq.wrapping_add(1);
                    }
                    None => {
                        // channel closed; send safe/idle packet then exit
                        // send a final idle packet
                        let idle = [0u8;8];
                        info!("Sending final idle packet bytes={:02x?}", &idle);
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
                    info!("Watchdog idle send seq={} bytes={:02x?}", seq, &buf);
                    let _ = udp.send_to(&buf, &pi_addr).await;
                    seq = seq.wrapping_add(1);
                }
            }
        }
    }
}
