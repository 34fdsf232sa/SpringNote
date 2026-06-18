import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spring_note/core/models/structured_work_note.dart';
import 'package:spring_note/core/services/home_overview_service.dart';

void main() {
  test('home overview service persists daily overview json', () async {
    final temp = await Directory.systemTemp.createTemp('spring_note_overview_');
    addTearDown(() async {
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    });

    const service = HomeOverviewService();
    final date = DateTime(2026, 6, 18, 10, 30);
    final overview = await service.mergeAndSaveOverview(
      appDataDir: temp.path,
      date: date,
      current: const StructuredWorkNote(
        rawInput: 'old',
        completed: ['旧完成'],
        issues: [],
        plans: ['旧计划'],
      ),
      incoming: const StructuredWorkNote(
        rawInput: 'new',
        completed: ['新完成'],
        issues: ['新问题'],
        plans: [],
      ),
    );

    expect(overview.completed, ['新完成', '旧完成']);
    expect(overview.issues, ['新问题']);
    expect(overview.plans, ['旧计划']);

    final path = service.overviewPath(temp.path, date);
    expect(path, endsWith('${Platform.pathSeparator}2026-06-18.json'));
    expect(await File(path).exists(), isTrue);

    final reloaded = await service.readOverview(
      appDataDir: temp.path,
      date: date,
    );
    expect(reloaded.rawInput, 'new');
    expect(reloaded.completed, ['新完成', '旧完成']);
    expect(reloaded.issues, ['新问题']);
    expect(reloaded.plans, ['旧计划']);
  });
}
