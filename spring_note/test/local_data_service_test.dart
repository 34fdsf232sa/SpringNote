import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spring_note/core/models/provider_config.dart';
import 'package:spring_note/core/services/local_data_service.dart';

void main() {
  test('local data service creates first-run data layout', () async {
    final temp = await Directory.systemTemp.createTemp('spring_note_test_');
    addTearDown(() async {
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    });

    final state = await LocalDataService(appDataPath: temp.path).initialize();

    expect(await File(state.configPath).exists(), isTrue);
    expect(await Directory(state.dailyNotesDirectory).exists(), isTrue);
    expect(await Directory(state.weeklyNotesDirectory).exists(), isTrue);
    expect(await Directory(state.monthlyNotesDirectory).exists(), isTrue);
    expect(
      state.config.defaultModels.keys,
      contains('intelligentGenerationModel'),
    );
    expect(state.config.defaultModels.keys, contains('editCompletionModel'));
    expect(state.config.defaultModels.keys, contains('memoryBookModel'));
    expect(state.config.apiLogEnabled, isFalse);
  });

  test('local data service saves and reads provider model config', () async {
    final temp = await Directory.systemTemp.createTemp('spring_note_config_');
    addTearDown(() async {
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    });

    final service = LocalDataService(appDataPath: temp.path);
    final state = await service.initialize();
    final provider = ProviderConfig.template('OpenAI');
    final config = state.config.copyWith(
      dailyWorkHours: 9,
      apiLogEnabled: true,
      providers: [provider],
      defaultModels: {
        ...state.config.defaultModels,
        'intelligentGenerationModel': provider.models.first.modelId,
      },
    );

    await service.saveConfig(config);
    final reloaded = await service.readConfig();

    expect(reloaded.dailyWorkHours, 9);
    expect(reloaded.apiLogEnabled, isTrue);
    expect(reloaded.providers, hasLength(1));
    expect(reloaded.providers.first.name, 'OpenAI');
    expect(reloaded.providers.first.models.first.fimMode, 'none');
    expect(
      reloaded.defaultModels['intelligentGenerationModel'],
      'gpt-4.1-mini',
    );
  });
}
