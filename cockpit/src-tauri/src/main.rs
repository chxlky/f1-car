// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use log::error;

fn main() {
    if let Err(e) = cockpit_lib::run() {
        error!("Error: {}", e);
        std::process::exit(1);
    }
}
