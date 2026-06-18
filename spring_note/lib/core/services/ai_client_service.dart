import '../../src/rust/ai.dart' as rust_ai;
import '../../src/rust/api/ai_api.dart' as rust_api;
import '../models/app_config.dart';
import '../models/model_config.dart';
import '../models/provider_config.dart';
import '../models/structured_work_note.dart';

class AiClientService {
  const AiClientService();

  Future<StructuredWorkNote?> generateStructuredNote({
    required String appDataDir,
    required AppConfig config,
    required String input,
  }) async {
    final selection = _selectModel(config, 'intelligentGenerationModel');
    if (selection == null) {
      return null;
    }

    final response = await rust_api.generateStructuredNote(
      request: rust_ai.StructuredNoteRequest(
        appDataDir: appDataDir,
        provider: _toRustProvider(selection.provider),
        model: _toRustModel(selection.model),
        input: input,
        apiLogEnabled: config.apiLogEnabled,
      ),
    );

    if (!response.ok) {
      return null;
    }

    return StructuredWorkNote(
      rawInput: input,
      completed: response.completed,
      issues: response.issues,
      plans: response.plans,
    );
  }

  Future<String?> mergeDailyMarkdown({
    required String appDataDir,
    required AppConfig config,
    required String existingMarkdown,
    required StructuredWorkNote note,
    required DateTime date,
  }) async {
    final selection = _selectModel(config, 'intelligentGenerationModel');
    if (selection == null) {
      return null;
    }

    final response = await rust_api.mergeDailyNote(
      request: rust_ai.DailyMergeRequest(
        appDataDir: appDataDir,
        provider: _toRustProvider(selection.provider),
        model: _toRustModel(selection.model),
        existingMarkdown: existingMarkdown,
        rawInput: note.rawInput,
        completed: note.completed,
        issues: note.issues,
        plans: note.plans,
        date: _formatDate(date),
        apiLogEnabled: config.apiLogEnabled,
      ),
    );

    if (!response.ok || response.content.trim().isEmpty) {
      return null;
    }

    return '${response.content.trimRight()}\n';
  }

  Future<rust_ai.ProviderTestResult> testProviderConnection({
    required String appDataDir,
    required bool apiLogEnabled,
    required ProviderConfig provider,
    required ModelConfig model,
  }) {
    return rust_api.testProviderConnection(
      appDataDir: appDataDir,
      apiLogEnabled: apiLogEnabled,
      provider: _toRustProvider(provider),
      model: _toRustModel(model),
    );
  }

  Future<rust_ai.ModelListResult> fetchProviderModels({
    required String appDataDir,
    required bool apiLogEnabled,
    required ProviderConfig provider,
  }) {
    return rust_api.fetchProviderModels(
      appDataDir: appDataDir,
      apiLogEnabled: apiLogEnabled,
      provider: _toRustProvider(provider),
    );
  }

  _ModelSelection? _selectModel(AppConfig config, String key) {
    final modelId = config.defaultModels[key];
    if (modelId == null || modelId.trim().isEmpty) {
      return null;
    }

    for (final provider in config.providers) {
      if (!provider.enabled || provider.apiKey.trim().isEmpty) {
        continue;
      }
      for (final model in provider.models) {
        if (model.modelId == modelId) {
          return _ModelSelection(provider: provider, model: model);
        }
      }
    }

    return null;
  }

  rust_ai.AiProvider _toRustProvider(ProviderConfig provider) {
    return rust_ai.AiProvider(
      id: provider.id,
      name: provider.name,
      protocol: provider.protocol,
      apiKey: provider.apiKey,
      baseUrl: provider.baseUrl,
      apiPath: provider.apiPath,
    );
  }

  rust_ai.AiModel _toRustModel(ModelConfig model) {
    return rust_ai.AiModel(
      modelId: model.modelId,
      displayName: model.displayName,
    );
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

class _ModelSelection {
  const _ModelSelection({required this.provider, required this.model});

  final ProviderConfig provider;
  final ModelConfig model;
}
