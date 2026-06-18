use crate::ai::{AiChatRequest, AiTextResult};
use chrono::Utc;
use rusqlite::{Connection, Result, params};
use std::fs;
use std::path::Path;

pub fn record_model_call(
    app_data_dir: &str,
    request: &AiChatRequest,
    result: &AiTextResult,
) -> Result<()> {
    fs::create_dir_all(app_data_dir).ok();
    let db_path = Path::new(app_data_dir).join("springnote.db");
    let connection = Connection::open(db_path)?;
    initialize(&connection)?;

    connection.execute(
        "INSERT INTO model_call_records (
            created_at,
            provider_id,
            provider_name,
            protocol,
            model_id,
            purpose,
            ok,
            error_code,
            error_message,
            input_tokens,
            output_tokens,
            cached_tokens
        ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12)",
        params![
            Utc::now().to_rfc3339(),
            &request.provider.id,
            &request.provider.name,
            &request.provider.protocol,
            &request.model.model_id,
            &request.purpose,
            if result.ok { 1 } else { 0 },
            &result.error_code,
            &result.error_message,
            result.input_tokens,
            result.output_tokens,
            result.cached_tokens,
        ],
    )?;

    connection.execute(
        "INSERT INTO token_usage_daily (
            date,
            input_tokens,
            output_tokens,
            cached_tokens,
            call_count
        ) VALUES (date('now', 'localtime'), ?1, ?2, ?3, 1)
        ON CONFLICT(date) DO UPDATE SET
            input_tokens = input_tokens + excluded.input_tokens,
            output_tokens = output_tokens + excluded.output_tokens,
            cached_tokens = cached_tokens + excluded.cached_tokens,
            call_count = call_count + 1",
        params![
            result.input_tokens,
            result.output_tokens,
            result.cached_tokens,
        ],
    )?;

    Ok(())
}

fn initialize(connection: &Connection) -> Result<()> {
    connection.execute_batch(
        "
        CREATE TABLE IF NOT EXISTS model_call_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            created_at TEXT NOT NULL,
            provider_id TEXT NOT NULL,
            provider_name TEXT NOT NULL,
            protocol TEXT NOT NULL,
            model_id TEXT NOT NULL,
            purpose TEXT NOT NULL,
            ok INTEGER NOT NULL,
            error_code TEXT NOT NULL,
            error_message TEXT NOT NULL,
            input_tokens INTEGER NOT NULL DEFAULT 0,
            output_tokens INTEGER NOT NULL DEFAULT 0,
            cached_tokens INTEGER NOT NULL DEFAULT 0
        );

        CREATE TABLE IF NOT EXISTS token_usage_daily (
            date TEXT PRIMARY KEY,
            input_tokens INTEGER NOT NULL DEFAULT 0,
            output_tokens INTEGER NOT NULL DEFAULT 0,
            cached_tokens INTEGER NOT NULL DEFAULT 0,
            call_count INTEGER NOT NULL DEFAULT 0
        );
        ",
    )?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ai::{AiModel, AiProvider};
    use std::time::{SystemTime, UNIX_EPOCH};

    #[test]
    fn writes_model_call_records() {
        let suffix = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let dir = std::env::temp_dir().join(format!("spring_note_stats_{suffix}"));
        let app_data_dir = dir.to_string_lossy().to_string();
        let request = AiChatRequest {
            app_data_dir: app_data_dir.clone(),
            provider: AiProvider {
                id: "p".to_string(),
                name: "OpenAI".to_string(),
                protocol: "openaiCompatible".to_string(),
                api_key: "key".to_string(),
                base_url: "https://api.example.com".to_string(),
                api_path: "/chat/completions".to_string(),
            },
            model: AiModel {
                model_id: "gpt-test".to_string(),
                display_name: "GPT Test".to_string(),
            },
            system_prompt: String::new(),
            user_prompt: String::new(),
            purpose: "test".to_string(),
            api_log_enabled: false,
        };
        let result = AiTextResult::success(&request, "ok", 3, 5, 1);

        record_model_call(&app_data_dir, &request, &result).unwrap();

        let connection = Connection::open(dir.join("springnote.db")).unwrap();
        let count: i64 = connection
            .query_row("SELECT COUNT(*) FROM model_call_records", [], |row| {
                row.get(0)
            })
            .unwrap();
        assert_eq!(count, 1);
        fs::remove_dir_all(dir).ok();
    }
}
