use std::sync::Arc;

use jni::{objects::JObject, JavaVM};
use log::{error, info};
use serde::{Deserialize, Serialize};
use specta::Type;
use tauri::{AppHandle, Manager, State};
use tokio::sync::Mutex;

use crate::discovery::DiscoveryService;
use crate::types::{DiscoveryError, F1Car};

#[macro_export]
macro_rules! collect_commands {
    () => {
        specta_collect_commands![
            $crate::commands::get_orientation,
            $crate::commands::set_orientation,
            $crate::commands::start_discovery,
            $crate::commands::stop_discovery,
            $crate::commands::get_discovered_cars,
            $crate::commands::get_car_by_id,
            $crate::commands::is_discovery_running,
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
    if cfg!(target_os = "android") {
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
            _ => Orientation::Portrait,
        };

        Ok(orientation)
    } else {
        // Return default Portrait orientation on non-Android platforms
        let _ = handle; // Suppress unused variable warning
        Ok(Orientation::Portrait)
    }
}

#[tauri::command]
#[specta::specta]
pub fn set_orientation(handle: AppHandle, orientation: Orientation) -> Result<(), String> {
    if cfg!(target_os = "android") {
        let window = handle
            .get_webview_window("main")
            .ok_or_else(|| "Main window not found".to_string())?;

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
                    &[jni::objects::JValue::from(&jni_orientation_string)],
                )
                .unwrap();
            })
            .map_err(|e| e.to_string())?;

        Ok(())
    } else {
        // Do nothing on non-Android platforms
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
pub async fn is_discovery_running(
    discovery_service: State<'_, Arc<Mutex<DiscoveryService>>>,
) -> Result<bool, DiscoveryError> {
    let service = discovery_service.lock().await;
    Ok(service.is_running())
}
