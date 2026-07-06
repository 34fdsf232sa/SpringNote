import 'dart:async';
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
  String _markdown = '';
  String? _message;
  bool _loading = true;

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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    final path = _todayPath();
    try {
      final file = File(path);
      final markdown = await file.exists()
          ? await file.readAsString()
          : '# AI 日报 ${_dateStamp(DateTime.now())}\n\n## 优先级事项\n- 暂无\n\n## AI 日报整理\n\n### 今日重点\n- 今晚 19:00 后会自动生成。\n\n### 明日计划\n- 暂无\n';
      if (!mounted) {
        return;
      }
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

  String _todayPath() {
    return p.join(
      widget.localDataState.dataDirectory,
      'notes',
      'ai-daily',
      '${_dateStamp(DateTime.now())}.md',
    );
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
