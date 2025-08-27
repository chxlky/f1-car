use std::{
    sync::{Arc, Mutex},
    time::Duration,
};

use anyhow::Result;
use axum::{
    Router,
    body::Body,
    extract::Query,
    http::{Response, StatusCode},
    response::IntoResponse,
    routing::get,
};
use log::info;
use serde::Deserialize;
use tokio::net::TcpListener;
use tokio_stream::{StreamExt, wrappers::IntervalStream};
use tower_http::cors::{Any, CorsLayer};

use super::CameraCapture;

type FrameBuffer = Arc<Mutex<Option<Vec<u8>>>>;

#[derive(Deserialize)]
struct StreamQuery {
    action: Option<String>,
}

pub struct MjpegStreamer {
    frame_buffer: FrameBuffer,
    camera_capture: CameraCapture,
}

impl MjpegStreamer {
    pub async fn new() -> Result<Self> {
        let frame_buffer = Arc::new(Mutex::new(None));
        let camera_capture = CameraCapture::new(frame_buffer.clone());

        let streamer = Self {
            frame_buffer,
            camera_capture,
        };

        Ok(streamer)
    }

    pub async fn start(&mut self) -> Result<()> {
        self.start_http_server().await?;
        info!("MJPEG streamer started on http://0.0.0.0:8081/stream");

        Ok(())
    }

    async fn start_http_server(&self) -> Result<()> {
        let frame_buffer = self.frame_buffer.clone();
        let camera_capture = self.camera_capture.clone();

        let app = Router::new()
            .route(
                "/stream",
                get(move |Query(query): Query<StreamQuery>| {
                    let frame_buffer = frame_buffer.clone();
                    let camera_capture = camera_capture.clone();

                    async move {
                        match query.action.as_deref() {
                            Some("start") => match camera_capture.start().await {
                                Ok(_) => (StatusCode::OK, "Camera started").into_response(),
                                Err(e) => (
                                    StatusCode::INTERNAL_SERVER_ERROR,
                                    format!("Failed to start camera: {}", e),
                                )
                                    .into_response(),
                            },
                            Some("stop") => match camera_capture.stop().await {
                                Ok(_) => (StatusCode::OK, "Camera stopped").into_response(),
                                Err(e) => (
                                    StatusCode::INTERNAL_SERVER_ERROR,
                                    format!("Failed to stop camera: {}", e),
                                )
                                    .into_response(),
                            },
                            Some("status") => match camera_capture.is_running() {
                                Ok(running) => {
                                    let status = if running { "Running" } else { "Stopped" };
                                    (StatusCode::OK, format!("Camera status: {}", status))
                                        .into_response()
                                }
                                Err(e) => (
                                    StatusCode::INTERNAL_SERVER_ERROR,
                                    format!("Failed to check status: {}", e),
                                )
                                    .into_response(),
                            },
                            None | Some(_) => {
                                if let Err(e) = camera_capture.start().await {
                                    return (
                                        StatusCode::INTERNAL_SERVER_ERROR,
                                        format!("Failed to start camera: {}", e),
                                    )
                                        .into_response();
                                }

                                let stream = IntervalStream::new(tokio::time::interval(
                                    Duration::from_millis(33),
                                ))
                                .then(move |_| {
                                    let buffer = frame_buffer.clone();
                                    async move {
                                        if let Ok(frame_lock) = buffer.lock() {
                                            if let Some(frame) = &*frame_lock {
                                                let part_header =
                                                    b"--frame\r\nContent-Type: image/jpeg\r\n\r\n";
                                                let part_footer = b"\r\n";

                                                let mut data = Vec::with_capacity(
                                                    part_header.len()
                                                        + frame.len()
                                                        + part_footer.len(),
                                                );
                                                data.extend_from_slice(part_header);
                                                data.extend_from_slice(frame);
                                                data.extend_from_slice(part_footer);

                                                Some(Ok::<_, anyhow::Error>(
                                                    axum::body::Bytes::from(data),
                                                ))
                                            } else {
                                                None
                                            }
                                        } else {
                                            None
                                        }
                                    }
                                })
                                .filter_map(|x| x); // Filter out None values

                                let body = Body::from_stream(stream);
                                Response::builder()
                                    .header(
                                        "Content-Type",
                                        "multipart/x-mixed-replace; boundary=frame",
                                    )
                                    .body(body)
                                    .unwrap()
                                    .into_response()
                            }
                        }
                    }
                }),
            )
            .layer(
                CorsLayer::new()
                    .allow_origin(Any)
                    .allow_methods(Any)
                    .allow_headers(Any)
                    .allow_credentials(false),
            );

        let addr = std::net::SocketAddr::from(([0, 0, 0, 0], 8081));
        let listener = TcpListener::bind(addr).await?;
        axum::serve(listener, app).await?;

        Ok(())
    }
}
