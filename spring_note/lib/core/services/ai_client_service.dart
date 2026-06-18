import '../../src/rust/ai.dart' as rust_ai;
import '../../src/rust/api/ai_api.dart' as rust_api;
import '../models/app_config.dart';
import '../models/memory_message.dart';
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

  Future<String?> fimCompleteMarkdown({
    required String appDataDir,
    required AppConfig config,
    required String prompt,
    required String suffix,
  }) async {
    if (fimUnavailableReason(config) != null) {
      return null;
    }

    final selection = _selectModel(
      config,
      'editCompletionModel',
      requireCompletion: true,
    );
    if (selection == null ||
        selection.provider.protocol != 'openaiCompatible') {
      return null;
    }

    final response = await rust_api.fimComplete(
      request: rust_ai.FimCompleteRequest(
        appDataDir: appDataDir,
        provider: _toRustProvider(selection.provider),
        model: _toRustModel(selection.model),
        prompt: prompt,
        suffix: suffix,
        apiLogEnabled: config.apiLogEnabled,
      ),
    );

    if (!response.ok || response.content.isEmpty) {
      return null;
    }

    return response.content;
  }

  Future<String?> memoryChat({
    required String appDataDir,
    required AppConfig config,
    required String question,
    required String contextMarkdown,
  }) async {
    final selection = _selectModel(config, 'memoryBookModel');
    if (selection == null) {
      return null;
    }

    final response = await rust_api.memoryChat(
      request: rust_ai.MemoryChatRequest(
        appDataDir: appDataDir,
        provider: _toRustProvider(selection.provider),
        model: _toRustModel(selection.model),
        question: question,
        contextMarkdown: contextMarkdown,
        apiLogEnabled: config.apiLogEnabled,
      ),
    );

    if (!response.ok || response.content.trim().isEmpty) {
      return null;
    }

    return response.content.trim();
  }

  Future<rust_ai.MemoryToolChatResult?> memoryToolChat({
    required String appDataDir,
    required AppConfig config,
    required List<MemoryMessage> messages,
    bool thinkingEnabled = true,
    String reasoningEffort = 'high',
  }) async {
    final selection = _selectModel(config, 'memoryBookModel');
    if (selection == null) {
      return null;
    }

    final response = await rust_api.memoryToolChat(
      request: rust_ai.MemoryToolChatRequest(
        appDataDir: appDataDir,
        provider: _toRustProvider(selection.provider),
        model: _toRustModel(selection.model),
        messages: messages.map(_toRustChatMessage).toList(),
        thinkingEnabled: thinkingEnabled,
        reasoningEffort: reasoningEffort,
        apiLogEnabled: config.apiLogEnabled,
      ),
    );

    return response.ok ? response : null;
  }

  Stream<rust_ai.MemoryToolChatStreamEvent>? memoryToolChatStream({
    required String appDataDir,
    required AppConfig config,
    required List<MemoryMessage> messages,
    required bool thinkingEnabled,
    required String reasoningEffort,
  }) {
    final selection = _selectModel(config, 'memoryBookModel');
    if (selection == null) {
      return null;
    }

    return rust_api.memoryToolChatStream(
      request: rust_ai.MemoryToolChatRequest(
        appDataDir: appDataDir,
        provider: _toRustProvider(selection.provider),
        model: _toRustModel(selection.model),
        messages: messages.map(_toRustChatMessage).toList(),
        thinkingEnabled: thinkingEnabled,
        reasoningEffort: reasoningEffort,
        apiLogEnabled: config.apiLogEnabled,
      ),
    );
  }

  String memoryModelLabel(AppConfig config) {
    final modelId = config.defaultModels['memoryBookModel'];
    if (modelId == null || modelId.trim().isEmpty) {
      return '记忆模型未选择';
    }
    for (final provider in config.providers) {
      for (final model in provider.models) {
        if (model.modelId == modelId) {
          return model.displayName;
        }
      }
    }
    return modelId;
  }

  String? fimUnavailableReason(AppConfig config) {
    final modelId = config.defaultModels['editCompletionModel'];
    if (modelId == null || modelId.trim().isEmpty) {
      return '未选择编辑补全模型';
    }

    for (final provider in config.providers) {
      for (final model in provider.models) {
        if (model.modelId != modelId) {
          continue;
        }
        if (!provider.enabled) {
          return '编辑补全模型所在供应商未启用';
        }
        if (provider.apiKey.trim().isEmpty) {
          return '编辑补全模型所在供应商 API Key 为空';
        }
        if (provider.protocol != 'openaiCompatible') {
          return 'FIM 仅支持 OpenAI-compatible 供应商';
        }
        if (!model.modelTypes.contains('completion')) {
          return '编辑补全模型的模型类型没有勾选“补全”';
        }
        return null;
      }
    }

    return '编辑补全模型不存在或已被删除';
  }

  _ModelSelection? _selectModel(
    AppConfig config,
    String key, {
    bool requireCompletion = false,
  }) {
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
          if (requireCompletion && !model.modelTypes.contains('completion')) {
            return null;
          }
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

  rust_ai.AiChatMessage _toRustChatMessage(MemoryMessage message) {
    return rust_ai.AiChatMessage(
      role: message.role == 'ai' ? 'assistant' : message.role,
      content: message.content,
      reasoningContent: message.reasoningContent,
      toolCallId: message.toolCallId ?? '',
      toolCalls: message.toolCalls
          .map(
            (toolCall) => rust_ai.AiToolCall(
              id: toolCall.id,
              name: toolCall.name,
              arguments: toolCall.arguments,
            ),
          )
          .toList(),
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
