use std::sync::Arc;

use tauri::{Manager, Wry};
use tauri_specta::{
    collect_commands as specta_collect_commands, collect_events as specta_collect_events, Builder,
};
use tokio::sync::Mutex;

use crate::discovery::DiscoveryService;

pub mod commands;
pub mod discovery;
pub mod joystick;
pub mod types;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() -> Result<(), Box<dyn std::error::Error>> {
    let discovery_service = Arc::new(Mutex::new(DiscoveryService::new()));

    let builder = Builder::<Wry>::new()
        .commands(collect_commands!())
        .events(collect_events!());

    tauri::Builder::default()
        .plugin(tauri_plugin_haptics::init())
        .manage(discovery_service)
        .invoke_handler(builder.invoke_handler())
        .setup(move |app| {
            builder.mount_events(app);

            if cfg!(debug_assertions) {
                app.handle().plugin(
                    tauri_plugin_log::Builder::default()
                        .level(log::LevelFilter::Info)
                        .build(),
                )?;

                let window = app
                    .get_webview_window("main")
                    .expect("Failed to get webview window");
                window.open_devtools();
            }
            Ok(())
        })
        .run(tauri::generate_context!())?;
    Ok(())
}
