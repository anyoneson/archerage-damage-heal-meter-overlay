use std::{
    collections::{HashMap, VecDeque},
    fs::File,
    io::{BufRead, BufReader, Seek, SeekFrom},
    path::PathBuf,
};

use chrono::{Duration, Local, NaiveDateTime};
use serde::Serialize;

use crate::{
    config::{load_config, AppConfig},
    parser::{format_number, parse_line, CombatEvent, LogType},
};

#[derive(Debug, Default)]
pub struct MeterRuntime {
    config: AppConfig,
    config_path: Option<PathBuf>,
    events: VecDeque<CombatEvent>,
    offset: u64,
    initialized: bool,
    manual_start: Option<NaiveDateTime>,
}

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MeterRow {
    pub rank: usize,
    pub name: String,
    pub total: u64,
    pub total_formatted: String,
}

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MeterSnapshot {
    pub rows: Vec<MeterRow>,
    pub log_type: LogType,
    pub source_path: String,
    pub tracked_events: usize,
    pub updated_at: String,
}

impl MeterRuntime {
    pub fn snapshot(&mut self) -> Result<MeterSnapshot, String> {
        let (config, config_path) = load_config()?;
        let needs_reset = !self.initialized
            || self.config != config
            || self.config_path.as_ref() != Some(&config_path);

        if needs_reset {
            self.reset(config, config_path);
            self.scan_existing_window()?;
        } else {
            self.read_new_lines()?;
        }

        self.prune_old_events();

        Ok(MeterSnapshot {
            rows: self.rows(),
            log_type: self.config.log_type,
            source_path: self.config.log_file_path.clone(),
            tracked_events: self.events.len(),
            updated_at: Local::now().format("%H:%M:%S").to_string(),
        })
    }

    pub fn set_time_filter_now(&mut self) -> Result<(), String> {
        self.manual_start = Some(Local::now().naive_local());
        self.events.clear();

        if self.config.log_file_path.is_empty() {
            return Ok(());
        }

        let metadata = std::fs::metadata(&self.config.log_file_path)
            .map_err(|error| format!("Failed to inspect {}: {error}", self.config.log_file_path))?;
        self.offset = metadata.len();

        Ok(())
    }

    pub fn replace_config(&mut self, config: AppConfig) {
        self.config = config;
        self.events.clear();
        self.offset = 0;
        self.initialized = false;
    }

    fn reset(&mut self, config: AppConfig, config_path: PathBuf) {
        self.config = config;
        self.config_path = Some(config_path);
        self.events.clear();
        self.offset = 0;
        self.initialized = true;
    }

    fn scan_existing_window(&mut self) -> Result<(), String> {
        if self.config.log_file_path.trim().is_empty() {
            return Err("logFilePath is empty in config.json".to_string());
        }

        let file = File::open(&self.config.log_file_path)
            .map_err(|error| format!("Failed to open {}: {error}", self.config.log_file_path))?;
        let metadata = file
            .metadata()
            .map_err(|error| format!("Failed to inspect {}: {error}", self.config.log_file_path))?;
        let reader = BufReader::new(file);

        for line in reader.lines() {
            let line = line.map_err(|error| format!("Failed to read combat log line: {error}"))?;
            self.push_line_if_relevant(&line);
        }

        self.offset = metadata.len();
        Ok(())
    }

    fn read_new_lines(&mut self) -> Result<(), String> {
        if self.config.log_file_path.trim().is_empty() {
            return Err("logFilePath is empty in config.json".to_string());
        }

        let file = File::open(&self.config.log_file_path)
            .map_err(|error| format!("Failed to open {}: {error}", self.config.log_file_path))?;
        let metadata = file
            .metadata()
            .map_err(|error| format!("Failed to inspect {}: {error}", self.config.log_file_path))?;

        if metadata.len() < self.offset {
            self.offset = 0;
            self.events.clear();
            return self.scan_existing_window();
        }

        let mut reader = BufReader::new(file);
        reader
            .seek(SeekFrom::Start(self.offset))
            .map_err(|error| format!("Failed to seek combat log: {error}"))?;

        let mut line = String::new();
        loop {
            line.clear();
            let bytes_read = reader
                .read_line(&mut line)
                .map_err(|error| format!("Failed to read combat log line: {error}"))?;

            if bytes_read == 0 {
                break;
            }

            self.push_line_if_relevant(&line);
        }

        self.offset = reader
            .stream_position()
            .map_err(|error| format!("Failed to track combat log offset: {error}"))?;

        Ok(())
    }

    fn push_line_if_relevant(&mut self, line: &str) {
        let Some(event) = parse_line(line, self.config.log_type) else {
            return;
        };

        if self.accepts_event(&event) {
            self.events.push_back(event);
        }
    }

    fn accepts_event(&self, event: &CombatEvent) -> bool {
        if event.kind != self.config.log_type {
            return false;
        }

        if event.timestamp < self.start_time() || event.timestamp > Local::now().naive_local() {
            return false;
        }

        let target_name = self.config.target_name.trim();
        target_name.is_empty() || event.target.eq_ignore_ascii_case(target_name)
    }

    fn prune_old_events(&mut self) {
        let start_time = self.start_time();
        self.events.retain(|event| event.timestamp >= start_time);
    }

    fn start_time(&self) -> NaiveDateTime {
        self.manual_start.unwrap_or_else(|| {
            Local::now().naive_local() - Duration::minutes(self.config.log_minutes_ago.max(1))
        })
    }

    fn rows(&self) -> Vec<MeterRow> {
        let mut totals = HashMap::<String, u64>::new();

        for event in &self.events {
            *totals.entry(event.character.clone()).or_default() += event.amount;
        }

        let mut totals = totals.into_iter().collect::<Vec<_>>();
        totals.sort_by(|left, right| right.1.cmp(&left.1).then_with(|| left.0.cmp(&right.0)));

        totals
            .into_iter()
            .enumerate()
            .map(|(index, (name, total))| MeterRow {
                rank: index + 1,
                name,
                total,
                total_formatted: format_number(total),
            })
            .collect()
    }
}
