use serde::{Deserialize, Serialize};
use std::{
    env, fs,
    path::{Path, PathBuf},
};

use crate::parser::LogType;

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct AppConfig {
    #[serde(default = "default_overlay_position")]
    pub overlay_position: [i32; 2],
    #[serde(default = "default_overlay_width")]
    pub overlay_width: u32,
    #[serde(default = "default_overlay_height")]
    pub overlay_height: u32,
    #[serde(default = "default_overlay_font_size")]
    pub overlay_font_size: u32,
    #[serde(default = "default_overlay_logs_font_size")]
    pub overlay_logs_font_size: u32,
    #[serde(default = "default_overlay_opacity")]
    pub overlay_opacity: String,
    #[serde(default = "default_overlay_log_color")]
    pub overlay_log_color: String,
    #[serde(default = "default_log_file_path")]
    pub log_file_path: String,
    #[serde(default = "default_log_minutes_ago")]
    pub log_minutes_ago: i64,
    #[serde(default)]
    pub target_name: String,
    #[serde(default)]
    pub log_type: LogType,
}

impl Default for AppConfig {
    fn default() -> Self {
        Self {
            overlay_position: default_overlay_position(),
            overlay_width: default_overlay_width(),
            overlay_height: default_overlay_height(),
            overlay_font_size: default_overlay_font_size(),
            overlay_logs_font_size: default_overlay_logs_font_size(),
            overlay_opacity: default_overlay_opacity(),
            overlay_log_color: default_overlay_log_color(),
            log_file_path: default_log_file_path(),
            log_minutes_ago: default_log_minutes_ago(),
            target_name: String::new(),
            log_type: LogType::default(),
        }
    }
}

pub fn load_config() -> Result<(AppConfig, PathBuf), String> {
    let path = find_config_path();
    if !path.exists() {
        let mut config = AppConfig::default();
        normalize_config(&mut config);
        return Ok((config, path));
    }

    let contents = fs::read_to_string(&path)
        .map_err(|error| format!("Failed to read {}: {error}", path.display()))?;
    let mut config = serde_json::from_str::<AppConfig>(&contents)
        .map_err(|error| format!("Failed to parse {}: {error}", path.display()))?;
    normalize_config(&mut config);

    Ok((config, path))
}

pub fn save_config(config: &AppConfig) -> Result<AppConfig, String> {
    let path = find_config_path();
    let contents = serde_json::to_string_pretty(config)
        .map_err(|error| format!("Failed to serialize config: {error}"))?;

    fs::write(&path, format!("{contents}\n"))
        .map_err(|error| format!("Failed to write {}: {error}", path.display()))?;

    Ok(config.clone())
}

fn find_config_path() -> PathBuf {
    for candidate in config_candidates() {
        if candidate.exists() {
            return candidate;
        }
    }

    env::current_dir()
        .unwrap_or_else(|_| PathBuf::from("."))
        .join("config.json")
}

fn config_candidates() -> Vec<PathBuf> {
    let mut candidates = Vec::new();

    if let Ok(current_dir) = env::current_dir() {
        push_config_candidate(&mut candidates, &current_dir);
        if let Some(parent) = current_dir.parent() {
            push_config_candidate(&mut candidates, parent);
        }
    }

    if let Ok(exe_path) = env::current_exe() {
        if let Some(exe_dir) = exe_path.parent() {
            push_config_candidate(&mut candidates, exe_dir);
        }
    }

    candidates
}

fn push_config_candidate(candidates: &mut Vec<PathBuf>, base: &Path) {
    let candidate = base.join("config.json");
    if !candidates.iter().any(|existing| existing == &candidate) {
        candidates.push(candidate);
    }
}

fn default_overlay_position() -> [i32; 2] {
    [30, 30]
}

fn default_overlay_width() -> u32 {
    330
}

fn default_overlay_height() -> u32 {
    270
}

fn default_overlay_font_size() -> u32 {
    14
}

fn default_overlay_logs_font_size() -> u32 {
    12
}

fn default_overlay_opacity() -> String {
    "7".to_string()
}

fn default_overlay_log_color() -> String {
    "#ff55ff".to_string()
}

fn default_log_file_path() -> String {
    env::var_os("USERPROFILE")
        .map(PathBuf::from)
        .map(|profile| {
            profile
                .join("Documents")
                .join("ArcheRage")
                .join("Combat.log")
                .to_string_lossy()
                .to_string()
        })
        .unwrap_or_default()
}

fn default_log_minutes_ago() -> i64 {
    10
}

fn normalize_config(config: &mut AppConfig) {
    let log_file_path = config.log_file_path.trim();
    if log_file_path.is_empty()
        || log_file_path.contains("YOUR-USERNAME")
        || log_file_path.ends_with("Combat.log-FIX-ME")
    {
        config.log_file_path = default_log_file_path();
    }
}
