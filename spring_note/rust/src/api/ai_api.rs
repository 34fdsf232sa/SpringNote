use crate::ai::{
    self, AiModel, AiProvider, AiTextResult, DailyMergeRequest, MemoryChatRequest, ModelListResult,
    ProviderTestResult, ReportRequest, StructuredNoteRequest, StructuredNoteResult,
};

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

pub async fn generate_structured_note(request: StructuredNoteRequest) -> StructuredNoteResult {
    ai::generate_structured_note(request).await
}

pub async fn merge_daily_note(request: DailyMergeRequest) -> AiTextResult {
    ai::merge_daily_note(request).await
}

pub async fn generate_weekly_report(request: ReportRequest) -> AiTextResult {
    ai::generate_weekly_report(request).await
}

pub async fn generate_monthly_report(request: ReportRequest) -> AiTextResult {
    ai::generate_monthly_report(request).await
}

pub async fn memory_chat(request: MemoryChatRequest) -> AiTextResult {
    ai::memory_chat(request).await
}

pub async fn test_provider_connection(
    app_data_dir: String,
    provider: AiProvider,
    model: AiModel,
    api_log_enabled: bool,
) -> ProviderTestResult {
    ai::test_provider_connection(app_data_dir, provider, model, api_log_enabled).await
}

pub async fn fetch_provider_models(
    app_data_dir: String,
    provider: AiProvider,
    api_log_enabled: bool,
) -> ModelListResult {
    ai::fetch_provider_models(app_data_dir, provider, api_log_enabled).await
}
