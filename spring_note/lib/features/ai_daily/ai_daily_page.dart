import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/models/local_data_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/page_scaffold.dart';
import '../notes/markdown_preview.dart';

class AiDailyPage extends StatefulWidget {
  const AiDailyPage({super.key, required this.localDataState});

  final LocalDataState localDataState;

  @override
  State<AiDailyPage> createState() => _AiDailyPageState();
}

class _AiDailyPageState extends State<AiDailyPage> {
  static const _bridgeBasePath =
      r'C:\Users\Administrator\Documents\Codex\2026-06-30\qq';
  static const _priorities = ['高', '中', '低'];

  String _markdown = '';
  String? _message;
  bool _loading = true;
  bool _savingTasks = false;
  List<_PriorityDraft> _tasks = [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant AiDailyPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localDataState.dataDirectory !=
        widget.localDataState.dataDirectory) {
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    for (final task in _tasks) {
      task.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    final path = _todayPath();
    try {
      final tasks = await _loadPriorityTasks();
      final file = File(path);
      final markdown = await file.exists()
          ? await file.readAsString()
          : '# AI 日报 ${_dateStamp(DateTime.now())}\n\n## 优先级事项\n- 暂无\n\n## AI 日报整理\n\n### 今日重点\n- 今晚 19:00 后会自动生成。\n\n### 明日计划\n- 暂无\n';
      if (!mounted) {
        return;
      }
      _replaceTasks(tasks);
      setState(() {
        _markdown = markdown;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _markdown = '';
        _message = '读取 AI 日报失败';
        _loading = false;
      });
    }
  }

  Future<List<_PriorityDraft>> _loadPriorityTasks() async {
    final file = File(_tasksPath());
    if (!await file.exists()) {
      return [];
    }
    final payload = jsonDecode(await file.readAsString());
    if (payload is! Map<String, dynamic>) {
      return [];
    }
    final rawItems = payload['items'];
    if (rawItems is! List) {
      return [];
    }
    return [
      for (final item in rawItems)
        if (item is Map<String, dynamic>) _PriorityDraft.fromJson(item),
    ];
  }

  void _replaceTasks(List<_PriorityDraft> tasks) {
    for (final task in _tasks) {
      task.dispose();
    }
    _tasks = tasks;
  }

  void _addTask() {
    setState(() {
      _tasks.add(_PriorityDraft(priority: '中', text: ''));
    });
  }

  void _removeTask(int index) {
    setState(() {
      _tasks.removeAt(index).dispose();
    });
  }

  Future<void> _saveTasks() async {
    setState(() {
      _savingTasks = true;
      _message = null;
    });
    try {
      final now = DateTime.now().toIso8601String();
      final items = <Map<String, dynamic>>[];
      for (final task in _tasks) {
        final text = task.controller.text.trim();
        if (text.isEmpty) {
          continue;
        }
        items.add({
          'task': '【${task.priority}】$text',
          'source': task.source ??
              {
                'path': _todayPath(),
                'text': 'SpringNote AI 日报手动编辑',
              },
          'updated_at': now,
        });
      }
      final payload = {
        'updated_at': now,
        'items': items,
      };
      final file = File(_tasksPath());
      await file.parent.create(recursive: true);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(payload),
      );
      await _rewriteAiDailyPrioritySection(items);
      await _refreshRainmeter();
      await _load();
      if (!mounted) {
        return;
      }
      setState(() {
        _message = '优先级事项已保存';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = '保存优先级事项失败';
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingTasks = false;
        });
      }
    }
  }

  Future<void> _rewriteAiDailyPrioritySection(
    List<Map<String, dynamic>> items,
  ) async {
    final file = File(_todayPath());
    if (!await file.exists()) {
      await file.parent.create(recursive: true);
      await file.writeAsString(
        '# AI 日报 ${_dateStamp(DateTime.now())}\n\n'
        '## 优先级事项\n- 暂无\n\n'
        '## AI 日报整理\n\n'
        '### 今日重点\n- 暂无\n\n'
        '### 明日计划\n- 暂无\n',
      );
    }
    final content = await file.readAsString();
    final priorityMarkdown = _priorityMarkdown(items);
    final sectionPattern = RegExp(
      r'## 优先级事项\n.*?(?=\n## |$)',
      dotAll: true,
    );
    final nextContent = sectionPattern.hasMatch(content)
        ? content.replaceFirst(sectionPattern, priorityMarkdown.trimRight())
        : content.replaceFirst(
            RegExp(r'^(# .+\n+)', dotAll: true),
            r'$1' + priorityMarkdown + '\n',
          );
    await file.writeAsString(
      nextContent.endsWith('\n') ? nextContent : '$nextContent\n',
    );
  }

  String _priorityMarkdown(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return '## 优先级事项\n- 暂无\n';
    }
    const order = {'高': 0, '中': 1, '低': 2};
    final tasks = items
        .map((item) => (item['task'] ?? '').toString().trim())
        .where((task) => task.isNotEmpty)
        .toList()
      ..sort((left, right) {
        return (order[_priorityOf(left)] ?? 1).compareTo(
          order[_priorityOf(right)] ?? 1,
        );
      });
    return '## 优先级事项\n${tasks.map((task) => '- $task').join('\n')}\n';
  }

  Future<void> _refreshRainmeter() async {
    final script = File(p.join(_bridgeBasePath, 'run_springnote_desktop_todo.ps1'));
    if (!await script.exists()) {
      return;
    }
    await Process.run(
      'powershell.exe',
      [
        '-NoProfile',
        '-WindowStyle',
        'Hidden',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        script.path,
      ],
      workingDirectory: _bridgeBasePath,
    ).timeout(const Duration(seconds: 30));
  }

  String _tasksPath() {
    return p.join(_bridgeBasePath, 'bridge_state', 'claw_desktop_tasks.json');
  }

  String _todayPath() {
    return p.join(
      widget.localDataState.dataDirectory,
      'notes',
      'ai-daily',
      '${_dateStamp(DateTime.now())}.md',
    );
  }

  String _priorityOf(String task) {
    final match = RegExp(r'^【([高中低])】').firstMatch(task);
    return match?.group(1) ?? '中';
  }

  String _dateStamp(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    return SpringNotePageScaffold(
      title: 'AI 日报',
      actions: [
        SpringNoteIconButton(
          tooltip: '刷新',
          onPressed: _loading ? null : () => unawaited(_load()),
          icon: Icons.refresh_rounded,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 12),
            child: Text(
              'DeepSeek 生成的短日报和当前优先级事项',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.textSubtle),
            ),
          ),
          _PriorityTaskEditor(
            tasks: _tasks,
            priorities: _priorities,
            saving: _savingTasks,
            onAdd: _addTask,
            onRemove: _removeTask,
            onSave: () => unawaited(_saveTasks()),
            onPriorityChanged: (index, priority) {
              setState(() {
                _tasks[index].priority = priority;
              });
            },
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 12),
              child: Text(
                _message!,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: colors.textSubtle),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : MarkdownPreview(
                    markdown: _markdown,
                    localImageBasePath: p.dirname(_todayPath()),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PriorityDraft {
  _PriorityDraft({
    required this.priority,
    required String text,
    this.source,
  }) : controller = TextEditingController(text: text);

  factory _PriorityDraft.fromJson(Map<String, dynamic> json) {
    final task = (json['task'] ?? '').toString().trim();
    final match = RegExp(r'^【([高中低])】\s*(.*)$').firstMatch(task);
    return _PriorityDraft(
      priority: match?.group(1) ?? '中',
      text: match?.group(2)?.trim() ?? task,
      source: json['source'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['source'] as Map<String, dynamic>)
          : null,
    );
  }

  String priority;
  final TextEditingController controller;
  final Map<String, dynamic>? source;

  void dispose() {
    controller.dispose();
  }
}

class _PriorityTaskEditor extends StatelessWidget {
  const _PriorityTaskEditor({
    required this.tasks,
    required this.priorities,
    required this.saving,
    required this.onAdd,
    required this.onRemove,
    required this.onSave,
    required this.onPriorityChanged,
  });

  final List<_PriorityDraft> tasks;
  final List<String> priorities;
  final bool saving;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final VoidCallback onSave;
  final void Function(int index, String priority) onPriorityChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(32, 0, 32, 16),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '优先级事项',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              SpringNoteIconButton(
                tooltip: '新增',
                onPressed: saving ? null : onAdd,
                icon: Icons.add_rounded,
              ),
              const SizedBox(width: 4),
              SpringNoteIconButton(
                tooltip: '保存',
                onPressed: saving ? null : onSave,
                icon: Icons.save_outlined,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (tasks.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '暂无',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: colors.textSubtle),
              ),
            )
          else
            Column(
              children: [
                for (var index = 0; index < tasks.length; index++)
                  Padding(
                    padding: EdgeInsets.only(
                      top: index == 0 ? 0 : 8,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 76,
                          child: DropdownButtonFormField<String>(
                            value: tasks[index].priority,
                            items: [
                              for (final priority in priorities)
                                DropdownMenuItem(
                                  value: priority,
                                  child: Text(priority),
                                ),
                            ],
                            onChanged: saving
                                ? null
                                : (value) {
                                    if (value != null) {
                                      onPriorityChanged(index, value);
                                    }
                                  },
                            decoration: InputDecoration(
                              isDense: true,
                              filled: true,
                              fillColor: colors.inputFill,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: colors.border),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: tasks[index].controller,
                            enabled: !saving,
                            minLines: 1,
                            maxLines: 2,
                            decoration: InputDecoration(
                              isDense: true,
                              filled: true,
                              fillColor: colors.inputFill,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: colors.border),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SpringNoteIconButton(
                          tooltip: '删除',
                          onPressed: saving ? null : () => onRemove(index),
                          icon: Icons.delete_outline_rounded,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
