use std::sync::OnceLock;
use tokio::sync::{watch, Mutex};
use tokio::task::JoinHandle;

pub struct JoystickControl {
    pub handle: JoinHandle<()>,
    pub shutdown: watch::Sender<bool>,
}

pub(crate) static JOYSTICK_TASK: OnceLock<Mutex<Option<JoystickControl>>> = OnceLock::new();

#[macro_export]
macro_rules! collect_commands {
    () => {
        specta_collect_commands![
            $crate::commands::ui::get_orientation,
            $crate::commands::ui::set_orientation,
            $crate::commands::discovery::start_discovery,
            $crate::commands::discovery::stop_discovery,
            $crate::commands::discovery::get_discovered_cars,
            $crate::commands::discovery::connect_to_car,
            $crate::commands::discovery::disconnect_car,
            $crate::commands::discovery::get_car_by_id,
            $crate::commands::discovery::is_discovery_running,
            $crate::commands::joystick::start_joystick_service,
            $crate::commands::joystick::stop_joystick_service,
        ]
    };
}

pub mod discovery;
pub mod joystick;
pub mod ui;
