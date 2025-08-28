pub mod capture;
pub mod streaming;

use std::sync::{Arc, Mutex};

pub use capture::CameraCapture;
pub use streaming::MjpegStreamer;

pub type FrameBuffer = Arc<Mutex<Option<Vec<u8>>>>;
