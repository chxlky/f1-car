use cockpit_lib::{collect_commands, collect_events};
use specta_typescript::{BigIntExportBehavior, Typescript};
use tauri::Wry;
use tauri_specta::{collect_commands as specta_collect_commands, collect_events as specta_collect_events, Builder};

fn main() {
    let builder = Builder::<Wry>::new().commands(collect_commands!()).events(collect_events!());

    builder
        .export(
            Typescript::default().bigint(BigIntExportBehavior::Number),
            "../src/lib/bindings.ts",
        )
        .expect("Failed to export TS bindings");

    println!("TypeScript bindings generated successfully!");
}
