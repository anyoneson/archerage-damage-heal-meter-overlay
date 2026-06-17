mod config;
mod meter;
mod parser;

use std::sync::Mutex;

use config::{load_config, save_config as write_config, AppConfig};
use meter::{MeterRuntime, MeterSnapshot};
use tauri::{LogicalPosition, LogicalSize, Manager, Position, Size, State, WebviewWindow};

#[derive(Default)]
struct AppState {
    runtime: Mutex<MeterRuntime>,
}

#[tauri::command]
fn get_config() -> Result<AppConfig, String> {
    load_config().map(|(config, _)| config)
}

#[tauri::command]
fn save_config(
    window: WebviewWindow,
    state: State<'_, AppState>,
    mut config: AppConfig,
) -> Result<AppConfig, String> {
    if let Ok(position) = window.outer_position() {
        config.overlay_position = [position.x, position.y];
    }

    let saved = write_config(&config)?;
    apply_window_settings(&window, &saved);

    let mut runtime = state
        .runtime
        .lock()
        .map_err(|_| "Meter state lock poisoned".to_string())?;
    runtime.replace_config(saved.clone());

    Ok(saved)
}

#[tauri::command]
fn get_meter_snapshot(state: State<'_, AppState>) -> Result<MeterSnapshot, String> {
    let mut runtime = state
        .runtime
        .lock()
        .map_err(|_| "Meter state lock poisoned".to_string())?;
    runtime.snapshot()
}

#[tauri::command]
fn set_time_filter_now(state: State<'_, AppState>) -> Result<(), String> {
    let mut runtime = state
        .runtime
        .lock()
        .map_err(|_| "Meter state lock poisoned".to_string())?;
    runtime.set_time_filter_now()
}

#[tauri::command]
fn start_drag(window: WebviewWindow) -> Result<(), String> {
    window
        .start_dragging()
        .map_err(|error| format!("Failed to start dragging: {error}"))
}

#[tauri::command]
fn close_window(window: WebviewWindow) -> Result<(), String> {
    window
        .close()
        .map_err(|error| format!("Failed to close window: {error}"))
}

pub fn run() {
    tauri::Builder::default()
        .manage(AppState::default())
        .setup(|app| {
            if let Some(window) = app.get_webview_window("main") {
                if let Ok((config, _)) = load_config() {
                    apply_window_settings(&window, &config);
                }
            }
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            get_config,
            save_config,
            get_meter_snapshot,
            set_time_filter_now,
            start_drag,
            close_window
        ])
        .run(tauri::generate_context!())
        .expect("error while running Tauri application");
}

fn apply_window_settings(window: &WebviewWindow, config: &AppConfig) {
    let _ = window.set_size(Size::Logical(LogicalSize {
        width: config.overlay_width as f64,
        height: config.overlay_height as f64,
    }));
    let _ = window.set_position(Position::Logical(LogicalPosition {
        x: config.overlay_position[0] as f64,
        y: config.overlay_position[1] as f64,
    }));
}
