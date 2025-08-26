use std::sync::{Arc, OnceLock};

use anyhow::Context;
use log::{error, info};
use serde::{Deserialize, Serialize};
use specta::Type;
use tauri::{AppHandle, LogicalSize, Manager, Size, State};
use tauri_specta::Event;
use tokio::sync::Mutex;
use tokio::task::JoinHandle;

// Global holder for the joystick service task so it can be stopped later.
static JOYSTICK_TASK: OnceLock<JoinHandle<()>> = OnceLock::new();

use crate::discovery::DiscoveryService;
use crate::types::{CarUpdatedEvent, DiscoveryError, F1Car};
use std::net::SocketAddr;

use crate::joystick;

#[macro_export]
macro_rules! collect_commands {
    () => {
        specta_collect_commands![
            $crate::commands::get_orientation,
            $crate::commands::set_orientation,
            $crate::commands::start_discovery,
            $crate::commands::stop_discovery,
            $crate::commands::get_discovered_cars,
            $crate::commands::connect_to_car,
            $crate::commands::disconnect_car,
            $crate::commands::get_car_by_id,
            $crate::commands::is_discovery_running,
            $crate::commands::start_joystick_service_command,
            $crate::commands::stop_joystick_service_command,
        ]
    };
}

#[macro_export]
macro_rules! collect_events {
    () => {
        specta_collect_events![
            $crate::types::CarDiscoveredEvent,
            $crate::types::CarUpdatedEvent,
            $crate::types::CarOfflineEvent,
            $crate::types::CarRemovedEvent,
            $crate::types::DiscoveryStatusEvent,
        ]
    };
}

#[derive(Serialize, Deserialize, Debug, Type)]
pub enum Orientation {
    Portrait,
    Landscape,
}

#[tauri::command]
#[specta::specta]
pub fn get_orientation(handle: AppHandle) -> Result<Orientation, String> {
    let window = handle
        .get_webview_window("main")
        .ok_or_else(|| "Main window not found".to_string())?;

    #[cfg(target_os = "android")]
    {
        use jni::{objects::JObject, JavaVM};

        let ctx = ndk_context::android_context();
        let vm = unsafe { JavaVM::from_raw(ctx.vm().cast()) }.map_err(|e| e.to_string())?;
        let mut env = vm.attach_current_thread().map_err(|e| e.to_string())?;
        let activity = unsafe { JObject::from_raw(ctx.context().cast()) };

        let jni_result = env
            .call_method(
                &activity,
                "getCurrentOrientation",
                "()Ljava/lang/String;",
                &[],
            )
            .map_err(|e| format!("Failed to call getCurrentOrientation: {}", e))?;

        let orientation_jstring = jni_result
            .l()
            .map_err(|e| format!("Failed to get string from JValue: {}", e))?;

        let orientation_string: String = env
            .get_string(&orientation_jstring.into())
            .map_err(|e| format!("Failed to convert JString to String: {}", e))?
            .into();

        let orientation = match orientation_string.as_str() {
            "portrait" => Orientation::Portrait,
            "landscape" => Orientation::Landscape,
            other => {
                return Err(format!(
                    "Unknown orientation returned from Android: {}",
                    other
                ))
            }
        };

        Ok(orientation)
    }

    #[cfg(any(target_os = "windows", target_os = "macos", target_os = "linux"))]
    {
        let size = window.inner_size().map_err(|e| e.to_string())?;

        let orientation = if size.height > size.width {
            Orientation::Portrait
        } else {
            Orientation::Landscape
        };

        Ok(orientation)
    }

    #[cfg(not(any(
        target_os = "android",
        target_os = "windows",
        target_os = "macos",
        target_os = "linux"
    )))]
    {
        let _ = handle; // Suppress unused variable warning
        Ok(Orientation::Portrait)
    }
}

#[tauri::command]
#[specta::specta]
pub fn set_orientation(handle: AppHandle, orientation: Orientation) -> Result<(), String> {
    let window = handle
        .get_webview_window("main")
        .ok_or_else(|| "Main window not found".to_string())?;

    #[cfg(target_os = "android")]
    {
        use jni::{
            objects::{JObject, JValue},
            JavaVM,
        };

        window
            .run_on_main_thread(move || {
                let ctx = ndk_context::android_context();
                let vm = unsafe { JavaVM::from_raw(ctx.vm().cast()) }.unwrap();
                let mut env = vm.attach_current_thread().unwrap();
                let activity = unsafe { JObject::from_raw(ctx.context().cast()) };

                let orientation_str = match orientation {
                    Orientation::Portrait => "portrait",
                    Orientation::Landscape => "landscape",
                };

                let jni_orientation_string = env.new_string(orientation_str).unwrap();

                env.call_method(
                    &activity,
                    "setScreenOrientation",
                    "(Ljava/lang/String;)V",
                    &[JValue::from(&jni_orientation_string)],
                )
                .unwrap();
            })
            .map_err(|e| e.to_string())?;

        Ok(())
    }

    #[cfg(any(target_os = "windows", target_os = "macos", target_os = "linux"))]
    {
        match orientation {
            Orientation::Portrait => {
                let _ = window.set_size(Size::Logical(LogicalSize {
                    width: 450.0,
                    height: 900.0,
                }));
            }
            Orientation::Landscape => {
                let _ = window.set_size(Size::Logical(LogicalSize {
                    width: 900.0,
                    height: 450.0,
                }));
            }
        }

        Ok(())
    }

    #[cfg(not(any(
        target_os = "android",
        target_os = "windows",
        target_os = "macos",
        target_os = "linux"
    )))]
    {
        let _ = handle; // Suppress unused variable warning
        let _ = orientation; // Suppress unused variable warning
        Ok(())
    }
}

#[tauri::command]
#[specta::specta]
pub async fn start_discovery(
    handle: AppHandle,
    discovery_service: State<'_, Arc<Mutex<DiscoveryService>>>,
) -> Result<(), String> {
    info!("Starting mDNS discovery...");

    let mut service = discovery_service.lock().await;

    match service.start(handle).await {
        Ok(()) => {
            info!("mDNS discovery started successfully");
            Ok(())
        }
        Err(e) => {
            error!("Failed to start mDNS discovery: {e:?}");
            Err(e.message)
        }
    }
}

#[tauri::command]
#[specta::specta]
pub async fn stop_discovery(
    discovery_service: State<'_, Arc<Mutex<DiscoveryService>>>,
) -> Result<(), DiscoveryError> {
    info!("Stopping mDNS discovery...");

    let mut service = discovery_service.lock().await;

    match service.stop().await {
        Ok(()) => {
            info!("mDNS discovery stopped successfully");
            Ok(())
        }
        Err(e) => {
            error!("Failed to stop mDNS discovery: {e:?}");
            Err(e)
        }
    }
}

#[tauri::command]
#[specta::specta]
pub async fn get_discovered_cars(
    discovery_service: State<'_, Arc<Mutex<DiscoveryService>>>,
) -> Result<Vec<F1Car>, DiscoveryError> {
    let service = discovery_service.lock().await;
    Ok(service.get_all_cars())
}

#[tauri::command]
#[specta::specta]
pub async fn get_car_by_id(
    car_id: String,
    discovery_service: State<'_, Arc<Mutex<DiscoveryService>>>,
) -> Result<Option<F1Car>, DiscoveryError> {
    let service = discovery_service.lock().await;
    Ok(service.get_car_by_id(&car_id))
}

#[tauri::command]
#[specta::specta]
pub async fn connect_to_car(
    car_id: String,
    handle: AppHandle,
    discovery_service: State<'_, Arc<Mutex<DiscoveryService>>>,
) -> Result<(), DiscoveryError> {
    let service = discovery_service.lock().await;
    if let Some(mut car) = service.get_car_by_id(&car_id) {
        // set status to Connecting and emit update
        car.connection_status = crate::types::ConnectionStatus::Connecting;
        CarUpdatedEvent { car: car.clone() }
            .emit(&handle)
            .context("Failed to emit car-updated event")?;

        // spawn a background task to simulate connection and then set Connected
        let cars_map = service.get_cars();
        let handle_clone = handle.clone();
        tokio::spawn(async move {
            // simulate network connect attempt
            tokio::time::sleep(std::time::Duration::from_millis(500)).await;
            // update cached car
            {
                let mut guard = match cars_map.lock() {
                    Ok(g) => g,
                    Err(_) => return,
                };
                if let Some(c) = guard.get_mut(&car_id) {
                    c.connection_status = crate::types::ConnectionStatus::Connected;
                    c.last_seen = Some(std::time::SystemTime::now());
                    let _ = CarUpdatedEvent { car: c.clone() }.emit(&handle_clone);
                }
            }
        });
    }

    Ok(())
}

#[tauri::command]
#[specta::specta]
pub async fn disconnect_car(
    car_id: String,
    handle: AppHandle,
    discovery_service: State<'_, Arc<Mutex<DiscoveryService>>>,
) -> Result<(), DiscoveryError> {
    let service = discovery_service.lock().await;
    if let Some(mut car) = service.get_car_by_id(&car_id) {
        car.connection_status = crate::types::ConnectionStatus::Disconnected;
        car.last_seen = Some(std::time::SystemTime::now());
        CarUpdatedEvent { car: car.clone() }
            .emit(&handle)
            .context("Failed to emit car-updated event")?;

        // update cache
        let cars_map = service.get_cars();
        {
            let mut guard = match cars_map.lock() {
                Ok(g) => g,
                Err(_) => return Ok(()),
            };
            if let Some(c) = guard.get_mut(&car_id) {
                c.connection_status = crate::types::ConnectionStatus::Disconnected;
                c.last_seen = Some(std::time::SystemTime::now());
            }
        }
    }

    Ok(())
}

#[tauri::command]
#[specta::specta]
pub async fn is_discovery_running(
    discovery_service: State<'_, Arc<Mutex<DiscoveryService>>>,
) -> Result<bool, DiscoveryError> {
    let service = discovery_service.lock().await;
    Ok(service.is_running())
}

#[tauri::command]
#[specta::specta]
pub async fn start_joystick_service_command(ws_port: u16, pi_addr: String) -> Result<(), String> {
    let parsed: SocketAddr = pi_addr
        .parse()
        .map_err(|e| format!("Invalid PI address: {}", e))?;

    // spawn the joystick service in background
    let handle = tokio::spawn(async move {
        joystick::start_joystick_service(ws_port, parsed).await;
    });

    // store the handle if not already set; ignore if already running
    let _ = JOYSTICK_TASK.set(handle);

    Ok(())
}

#[tauri::command]
#[specta::specta]
pub async fn stop_joystick_service_command() -> Result<(), String> {
    if let Some(handle) = JOYSTICK_TASK.get() {
        // best-effort abort
        handle.abort();
        // drop the stored handle by replacing the OnceCell with a noop
        // OnceCell has no remove, so we ignore further stops.
        return Ok(());
    }

    Ok(())
}
