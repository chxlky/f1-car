use serde::{Deserialize, Serialize};
use specta::Type;
use tauri::{AppHandle, LogicalSize, Manager, Size};

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
