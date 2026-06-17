use chrono::NaiveDateTime;
use once_cell::sync::Lazy;
use regex::Regex;
use serde::{Deserialize, Serialize};

static EVENT_RE: Lazy<Regex> = Lazy::new(|| {
    Regex::new(
        r"^<(?P<timestamp>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})(?P<character>.*?)\|r(?P<body>.*)$",
    )
    .expect("valid event regex")
});

static DAMAGE_AMOUNT_RE: Lazy<Regex> = Lazy::new(|| {
    Regex::new(r"\|c(?:ff[0-9a-fA-F]{6}|[0-9a-fA-F]{8})-(?P<amount>[\d,]+)\|r")
        .expect("valid damage amount regex")
});

static HEAL_AMOUNT_RE: Lazy<Regex> = Lazy::new(|| {
    Regex::new(r"\|c(?:ff[0-9a-fA-F]{6}|[0-9a-fA-F]{8})(?P<amount>[\d,]+)\|r")
        .expect("valid heal amount regex")
});

static COLOR_SPAN_RE: Lazy<Regex> = Lazy::new(|| {
    Regex::new(r"\|c(?:ff[0-9a-fA-F]{6}|[0-9a-fA-F]{8}).*?\|r(?:\|r)?")
        .expect("valid color span regex")
});

static TARGET_TOKEN_RE: Lazy<Regex> =
    Lazy::new(|| Regex::new(r"(?P<target>[^|<>]+?)\|r").expect("valid target token regex"));

static LOG_CODE_RE: Lazy<Regex> = Lazy::new(|| {
    Regex::new(r"\|c(?:ff[0-9a-fA-F]{6}|[0-9a-fA-F]{8})|\|[ic]{2}\d+;|\|r")
        .expect("valid log code regex")
});

const TARGET_PREFIX_MARKERS: &[&str] = &[
    "attacked ",
    "targeted ",
    " attacked ",
    " targeted ",
    "атаковал ",
    "атаковала ",
    "атаковали ",
    "атакует ",
    "атакуют ",
    "выбрал целью ",
    "выбрала целью ",
    "выбрали целью ",
    "нацелился на ",
    "нацелилась на ",
    "нацелились на ",
    " атаковал ",
    " атаковала ",
    " атаковали ",
    " атакует ",
    " атакуют ",
    " выбрал целью ",
    " выбрала целью ",
    " выбрали целью ",
    " нацелился на ",
    " нацелилась на ",
    " нацелились на ",
    "님이 ",
    "님은 ",
    "이 ",
    "가 ",
    "은 ",
    "는 ",
    "对",
];

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum LogType {
    Damage,
    Heal,
}

impl Default for LogType {
    fn default() -> Self {
        Self::Damage
    }
}

#[derive(Clone, Debug)]
pub struct CombatEvent {
    pub timestamp: NaiveDateTime,
    pub character: String,
    pub target: String,
    pub amount: u64,
    pub kind: LogType,
}

pub fn parse_line(line: &str, kind: LogType) -> Option<CombatEvent> {
    match kind {
        LogType::Damage => parse_damage_line(line),
        LogType::Heal => parse_heal_line(line),
    }
}

pub fn format_number(mut value: u64) -> String {
    const SUFFIXES: [&str; 5] = ["", "k", "M", "B", "T"];
    let mut suffix = 0usize;
    let mut scaled = value as f64;

    while value >= 1000 && suffix < SUFFIXES.len() - 1 {
        scaled /= 1000.0;
        value /= 1000;
        suffix += 1;
    }

    if suffix == 0 {
        value.to_string()
    } else {
        format!("{scaled:.1}{}", SUFFIXES[suffix])
    }
}

fn parse_damage_line(line: &str) -> Option<CombatEvent> {
    event_from_line(line, LogType::Damage, &DAMAGE_AMOUNT_RE)
}

fn parse_heal_line(line: &str) -> Option<CombatEvent> {
    event_from_line(line, LogType::Heal, &HEAL_AMOUNT_RE)
}

fn event_from_line(line: &str, kind: LogType, amount_re: &Regex) -> Option<CombatEvent> {
    let captures = EVENT_RE.captures(line)?;
    let body = captures.name("body")?.as_str();
    let amount_captures = amount_re.captures(body)?;
    let amount_match = amount_captures.get(0)?;
    let timestamp =
        NaiveDateTime::parse_from_str(captures.name("timestamp")?.as_str(), "%Y-%m-%d %H:%M:%S")
            .ok()?;
    let character = clean_log_text(captures.name("character")?.as_str());
    let target = extract_target(&body[..amount_match.start()]).unwrap_or_default();
    let amount = parse_amount(amount_captures.name("amount")?.as_str())?;

    Some(CombatEvent {
        timestamp,
        character,
        target,
        amount,
        kind,
    })
}

fn parse_amount(value: &str) -> Option<u64> {
    let digits = value
        .chars()
        .filter(|character| character.is_ascii_digit())
        .collect::<String>();

    digits.parse::<u64>().ok()
}

fn extract_target(pre_amount_body: &str) -> Option<String> {
    let body_without_color_spans = COLOR_SPAN_RE.replace_all(pre_amount_body, "");

    TARGET_TOKEN_RE
        .captures_iter(&body_without_color_spans)
        .filter_map(|captures| {
            let raw_target = captures.name("target")?.as_str();
            let normalized = normalize_target_candidate(raw_target);
            (!normalized.is_empty()).then_some(normalized)
        })
        .next()
}

fn normalize_target_candidate(value: &str) -> String {
    let mut target = clean_log_text(value);

    for marker in TARGET_PREFIX_MARKERS {
        if let Some((_, suffix)) = target.rsplit_once(marker) {
            target = suffix.trim().to_string();
            break;
        }
    }

    target
        .trim_matches(|character: char| {
            character.is_whitespace()
                || matches!(
                    character,
                    ':' | ';' | ',' | '.' | '!' | '?' | '(' | ')' | '[' | ']' | '{' | '}'
                )
        })
        .to_string()
}

fn clean_log_text(value: &str) -> String {
    LOG_CODE_RE
        .replace_all(value, "")
        .trim()
        .trim_start_matches('>')
        .trim()
        .to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn formats_numbers_like_the_python_overlay() {
        assert_eq!(format_number(999), "999");
        assert_eq!(format_number(1_250), "1.2k");
        assert_eq!(format_number(1_250_000), "1.2M");
    }

    #[test]
    fn parses_damage_line() {
        let line = "<2026-06-16 12:00:00|ic23895;Alice|r attacked Bob|r using |cff57d6aeSkill|r|r and caused |cffc13d36-12345|r|r |cffc13d36Health|r|r.";
        let event = parse_line(line, LogType::Damage).expect("damage event");

        assert_eq!(event.character, "Alice");
        assert_eq!(event.target, "Bob");
        assert_eq!(event.amount, 12_345);
    }

    #[test]
    fn parses_heal_line() {
        let line = "<2026-06-16 12:00:00|ic23895;Alice|r targeted Bob|r using |cff57d6aeSkill|r|r to restore |cff9be85a12,345|r|r health.";
        let event = parse_line(line, LogType::Heal).expect("heal event");

        assert_eq!(event.character, "Alice");
        assert_eq!(event.target, "Bob");
        assert_eq!(event.amount, 12_345);
    }

    #[test]
    fn parses_russian_damage_line() {
        let line = "<2026-06-16 12:00:00|ic23895;Alice|r атаковал Bob|r с помощью |cff57d6aeSkill|r|r и нанес |cffc13d36-12345|r|r здоровья.";
        let event = parse_line(line, LogType::Damage).expect("russian damage event");

        assert_eq!(event.character, "Alice");
        assert_eq!(event.target, "Bob");
        assert_eq!(event.amount, 12_345);
    }

    #[test]
    fn parses_russian_heal_line() {
        let line = "<2026-06-16 12:00:00|ic23895;Alice|r выбрал целью Bob|r и использует |cff57d6aeSkill|r|r, восстанавливая |cff9be85a12345|r|r здоровья.";
        let event = parse_line(line, LogType::Heal).expect("russian heal event");

        assert_eq!(event.character, "Alice");
        assert_eq!(event.target, "Bob");
        assert_eq!(event.amount, 12_345);
    }

    #[test]
    fn parses_korean_damage_line() {
        let line = "<2026-06-16 12:00:00|ic23895;Alice|r님이 Bob|r을 |cff57d6aeSkill|r|r로 공격하여 |cffc13d36-12345|r|r 피해를 입혔습니다.";
        let event = parse_line(line, LogType::Damage).expect("korean damage event");

        assert_eq!(event.character, "Alice");
        assert_eq!(event.target, "Bob");
        assert_eq!(event.amount, 12_345);
    }

    #[test]
    fn parses_korean_heal_line() {
        let line = "<2026-06-16 12:00:00|ic23895;Alice|r님이 Bob|r에게 |cff57d6aeSkill|r|r을 사용해 |cff9be85a12345|r|r 생명력을 회복했습니다.";
        let event = parse_line(line, LogType::Heal).expect("korean heal event");

        assert_eq!(event.character, "Alice");
        assert_eq!(event.target, "Bob");
        assert_eq!(event.amount, 12_345);
    }
}
