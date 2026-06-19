import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

class MarkdownPreview extends StatelessWidget {
  const MarkdownPreview({super.key, required this.markdown});

  final String markdown;

  @override
  Widget build(BuildContext context) {
    if (markdown.trim().isEmpty) {
      return Center(
        child: Text(
          '预览区域会随着 Markdown 源码实时刷新',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF8A8A8A)),
        ),
      );
    }

    final textTheme = Theme.of(context).textTheme;
    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 56),
        child: DefaultTextStyle.merge(
          style: textTheme.bodyLarge?.copyWith(
            color: const Color(0xFF3A3A3A),
            fontSize: 16,
            height: 1.8,
          ),
          child: GptMarkdown(
            markdown,
            followLinkColor: true,
            useDollarSignsForLatex: true,
            codeBuilder: (context, name, code, closed) =>
                _MarkdownCodeBlock(language: name, code: code),
            style: textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF3A3A3A),
              fontSize: 16,
              height: 1.8,
            ),
            onLinkTap: (url, title) {},
          ),
        ),
      ),
    );
  }
}

class _MarkdownCodeBlock extends StatefulWidget {
  const _MarkdownCodeBlock({required this.language, required this.code});

  final String language;
  final String code;

  @override
  State<_MarkdownCodeBlock> createState() => _MarkdownCodeBlockState();
}

class _MarkdownCodeBlockState extends State<_MarkdownCodeBlock> {
  bool _copied = false;

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) {
      return;
    }
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() => _copied = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.language.trim().isEmpty
        ? 'code'
        : widget.language.trim();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 34,
            padding: const EdgeInsets.only(left: 14, right: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Text(
                  language,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _copyCode,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 28),
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  icon: Icon(
                    _copied ? Icons.check_rounded : Icons.copy_rounded,
                    size: 13,
                  ),
                  label: Text(_copied ? '已复制' : '复制'),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.code,
              style: const TextStyle(
                color: Color(0xFF334155),
                fontFamily: 'Consolas',
                fontSize: 13,
                height: 1.65,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
