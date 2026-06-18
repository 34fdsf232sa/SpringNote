import 'dart:convert';
import 'dart:io';

import '../models/structured_work_note.dart';

class HomeOverviewService {
  const HomeOverviewService();

  Future<StructuredWorkNote> readOverview({
    required String appDataDir,
    required DateTime date,
  }) async {
    final file = File(overviewPath(appDataDir, date));
    if (!await file.exists()) {
      return _empty;
    }

    final content = await file.readAsString();
    if (content.trim().isEmpty) {
      return _empty;
    }

    final decoded = jsonDecode(content);
    if (decoded is! Map) {
      return _empty;
    }

    return StructuredWorkNote(
      rawInput: decoded['rawInput'] as String? ?? '',
      completed: _readStringList(decoded['completed']),
      issues: _readStringList(decoded['issues']),
      plans: _readStringList(decoded['plans']),
    );
  }

  Future<StructuredWorkNote> mergeAndSaveOverview({
    required String appDataDir,
    required DateTime date,
    required StructuredWorkNote current,
    required StructuredWorkNote incoming,
  }) async {
    final merged = StructuredWorkNote(
      rawInput: incoming.rawInput,
      completed: [...incoming.completed, ...current.completed],
      issues: [...incoming.issues, ...current.issues],
      plans: [...incoming.plans, ...current.plans],
    );
    await writeOverview(appDataDir: appDataDir, date: date, overview: merged);
    return merged;
  }

  Future<void> writeOverview({
    required String appDataDir,
    required DateTime date,
    required StructuredWorkNote overview,
  }) async {
    final file = File(overviewPath(appDataDir, date));
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(
      '${encoder.convert({'date': _formatDate(date), 'updatedAt': DateTime.now().toIso8601String(), 'rawInput': overview.rawInput, 'completed': overview.completed, 'issues': overview.issues, 'plans': overview.plans})}\n',
    );
  }

  String overviewPath(String appDataDir, DateTime date) {
    final separator = Platform.pathSeparator;
    final root = appDataDir.endsWith(separator)
        ? appDataDir.substring(0, appDataDir.length - 1)
        : appDataDir;
    return [
      root,
      'overview',
      'daily',
      '${_formatDate(date)}.json',
    ].join(separator);
  }

  List<String> _readStringList(Object? value) {
    if (value is! List) {
      return [];
    }
    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static const _empty = StructuredWorkNote(
    rawInput: '',
    completed: [],
    issues: [],
    plans: [],
  );
}
