use std::net::SocketAddr;
use std::time::Duration;

use tokio::sync::watch;

use crate::commands::{JoystickControl, JOYSTICK_TASK};
use crate::joystick;

#[tauri::command]
#[specta::specta]
pub async fn start_joystick_service(ws_port: u16, pi_addr: String) -> Result<(), String> {
	let parsed: SocketAddr = pi_addr
		.parse()
		.map_err(|e| format!("Invalid PI address: {}", e))?;

	let (shutdown_tx, shutdown_rx) = watch::channel::<bool>(false);

	let handle = tokio::spawn(async move {
		joystick::start_joystick_service(ws_port, parsed, shutdown_rx).await;
	});

	let ctrl = JoystickControl { handle, shutdown: shutdown_tx };
	let mutex = JOYSTICK_TASK.get_or_init(|| tokio::sync::Mutex::new(None));
	let mut guard = mutex.lock().await;
	if guard.is_none() {
		*guard = Some(ctrl);
	} else {
		// already running; abort the just-created handle
		let _ = ctrl.shutdown.send(true);
		ctrl.handle.abort();
	}

	Ok(())
}

#[tauri::command]
#[specta::specta]
pub async fn stop_joystick_service() -> Result<(), String> {
	if let Some(mutex) = JOYSTICK_TASK.get() {
		let mut guard = mutex.lock().await;
		if let Some(ctrl) = guard.take() {
			let _ = ctrl.shutdown.send(true);
			match tokio::time::timeout(Duration::from_secs(2), ctrl.handle).await {
				Ok(join_res_inner) => {
					let _ = join_res_inner;
				}
				Err(_) => {
					// timed out waiting; we can't abort the moved JoinHandle here. As a fallback
					// the joystick task should notice the shutdown request and exit shortly; nothing
					// further to do safely from here.
				}
			}
		}

		return Ok(());
	}

	Ok(())
}
