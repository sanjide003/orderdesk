import 'package:flutter/material.dart';

/// Renders WhatsApp-formatted text accurately in preview bubbles:
/// 1. *Bold*
/// 2. _Italic_
/// 3. ~Strikethrough~
/// 4. ```Monospace``` (single-line or multi-line blocks)
/// 5. - Bulleted Lists
/// 6. 1. Numbered Lists
/// 7. > Block Quotes
/// 8. `Inline Code`
class WhatsAppRichText extends StatelessWidget {
  final String text;
  final TextStyle? baseStyle;

  const WhatsAppRichText({
    super.key,
    required this.text,
    this.baseStyle,
  });

  static final RegExp _bulletLineRe = RegExp(r'^(\s*)-\s+(.*)$');
  static final RegExp _numberLineRe = RegExp(r'^(\s*)(\d+)\.\s+(.*)$');
  static final RegExp _quoteLineRe = RegExp(r'^\s*>\s?(.*)$');
  static final RegExp _protectedTokenRe = RegExp(
    r'```[\s\S]*?```|`[^`\n]+`|https?://[^\s<>]+|\{\{[^}]+\}\}',
  );

  @override
  Widget build(BuildContext context) {
    final style = baseStyle ??
        const TextStyle(
          fontSize: 13,
          height: 1.42,
          color: Color(0xFF111B21),
        );

    final blocks = _parseBlocks(text);
    if (blocks.isEmpty) {
      return const SizedBox.shrink();
    }

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: blocks.map((b) => _buildBlock(b, style)).toList(),
      ),
    );
  }

  Widget _buildBlock(_WaBlock block, TextStyle style) {
    switch (block) {
      case _WaSpacerBlock():
        return const SizedBox(height: 6);

      case _WaMonoBlock(:final content):
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.055),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            content,
            style: style.copyWith(
              fontFamily: 'monospace',
              fontSize: (style.fontSize ?? 13) - 0.5,
              height: 1.38,
            ),
          ),
        );

      case _WaQuoteBlock(:final lines):
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.045),
            borderRadius: BorderRadius.circular(8),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: lines
                        .map(
                          (line) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: Text.rich(
                              TextSpan(
                                style: style.copyWith(
                                  color: const Color(0xFF2B3940),
                                ),
                                children: _parseInlineSpans(
                                  line,
                                  style.copyWith(
                                    color: const Color(0xFF2B3940),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        );

      case _WaBulletBlock(:final indentLevel, :final content):
        return Padding(
          padding: EdgeInsets.only(
            left: (indentLevel * 10.0) + 4,
            top: 1.5,
            bottom: 1.5,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 16,
                child: Text(
                  '•',
                  style: style.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: style,
                    children: _parseInlineSpans(content, style),
                  ),
                ),
              ),
            ],
          ),
        );

      case _WaNumberedBlock(:final indentLevel, :final number, :final content):
        final numText = '$number.';
        final numWidth = numText.length >= 3 ? 28.0 : 22.0;
        return Padding(
          padding: EdgeInsets.only(
            left: (indentLevel * 10.0) + 2,
            top: 1.5,
            bottom: 1.5,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: numWidth,
                child: Text(
                  numText,
                  style: style.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: style,
                    children: _parseInlineSpans(content, style),
                  ),
                ),
              ),
            ],
          ),
        );

      case _WaParagraphBlock(:final content):
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Text.rich(
            TextSpan(
              style: style,
              children: _parseInlineSpans(content, style),
            ),
          ),
        );
    }
  }

  List<_WaBlock> _parseBlocks(String input) {
    final lines = input.split('\n');
    final blocks = <_WaBlock>[];
    int i = 0;

    while (i < lines.length) {
      final line = lines[i];

      // Multi-line fenced monospace block: line starts with ``` and does not close on same line
      final trimmed = line.trim();
      if (trimmed.startsWith('```') &&
          (trimmed.length == 3 || !trimmed.substring(3).contains('```'))) {
        final endIdx = _findClosingFence(lines, i + 1);
        if (endIdx != -1) {
          final firstLineRemainder = trimmed.substring(3).trim();
          final bodyLines = <String>[];
          if (firstLineRemainder.isNotEmpty) {
            bodyLines.add(firstLineRemainder);
          }
          for (int k = i + 1; k < endIdx; k++) {
            bodyLines.add(lines[k]);
          }
          final closingRemainder =
              lines[endIdx].trim().replaceFirst(RegExp(r'^```'), '').trim();
          if (closingRemainder.isNotEmpty) {
            bodyLines.add(closingRemainder);
          }
          blocks.add(_WaMonoBlock(bodyLines.join('\n')));
          i = endIdx + 1;
          continue;
        }
      }

      // Consecutive Block Quotes (> ...)
      if (_quoteLineRe.hasMatch(line)) {
        final quoteLines = <String>[];
        while (i < lines.length && _quoteLineRe.hasMatch(lines[i])) {
          final m = _quoteLineRe.firstMatch(lines[i])!;
          quoteLines.add(m.group(1) ?? '');
          i++;
        }
        blocks.add(_WaQuoteBlock(quoteLines));
        continue;
      }

      // Blank line -> vertical spacer
      if (trimmed.isEmpty) {
        blocks.add(const _WaSpacerBlock());
        i++;
        continue;
      }

      // Bulleted List (- item)
      final bulletMatch = _bulletLineRe.firstMatch(line);
      if (bulletMatch != null) {
        final indentLen = (bulletMatch.group(1) ?? '').length ~/ 2;
        blocks.add(_WaBulletBlock(indentLen, bulletMatch.group(2) ?? ''));
        i++;
        continue;
      }

      // Numbered List (1. item)
      final numMatch = _numberLineRe.firstMatch(line);
      if (numMatch != null) {
        final indentLen = (numMatch.group(1) ?? '').length ~/ 2;
        final number = numMatch.group(2) ?? '1';
        blocks.add(
          _WaNumberedBlock(indentLen, number, numMatch.group(3) ?? ''),
        );
        i++;
        continue;
      }

      // Normal paragraph line (handles inline *bold*, _italic_, ~strike~, `code`, ```mono```)
      blocks.add(_WaParagraphBlock(line));
      i++;
    }

    return blocks;
  }

  int _findClosingFence(List<String> lines, int startIdx) {
    for (int i = startIdx; i < lines.length; i++) {
      if (lines[i].contains('```')) return i;
    }
    return -1;
  }

  /// Parses inline spans while protecting ```monospace```, `inline code`, URLs,
  /// and `{{template_variables}}` from accidental emphasis parsing.
  List<InlineSpan> _parseInlineSpans(String input, TextStyle baseStyle) {
    if (input.isEmpty) return const [];

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in _protectedTokenRe.allMatches(input)) {
      if (match.start > lastEnd) {
        spans.addAll(
          _parseEmphasis(input.substring(lastEnd, match.start), baseStyle),
        );
      }

      final token = match.group(0)!;
      if (token.startsWith('```') && token.endsWith('```') && token.length > 6) {
        final inner = token.substring(3, token.length - 3);
        spans.add(
          TextSpan(
            text: inner,
            style: baseStyle.copyWith(
              fontFamily: 'monospace',
              fontSize: (baseStyle.fontSize ?? 13) - 0.5,
              backgroundColor: Colors.black.withValues(alpha: 0.06),
            ),
          ),
        );
      } else if (token.startsWith('`') &&
          token.endsWith('`') &&
          token.length > 2) {
        final inner = token.substring(1, token.length - 1);
        spans.add(
          TextSpan(
            text: inner,
            style: baseStyle.copyWith(
              fontFamily: 'monospace',
              fontSize: (baseStyle.fontSize ?? 13) - 0.5,
              backgroundColor: Colors.black.withValues(alpha: 0.085),
              color: const Color(0xFF0F172A),
            ),
          ),
        );
      } else if (token.startsWith('http://') || token.startsWith('https://')) {
        spans.add(
          TextSpan(
            text: token,
            style: baseStyle.copyWith(
              color: const Color(0xFF027EB5),
              decoration: TextDecoration.underline,
              decorationColor: const Color(0xFF027EB5),
            ),
          ),
        );
      } else {
        // Template variable like {{customer_name}} preserved literally
        spans.add(TextSpan(text: token, style: baseStyle));
      }

      lastEnd = match.end;
    }

    if (lastEnd < input.length) {
      spans.addAll(_parseEmphasis(input.substring(lastEnd), baseStyle));
    }

    return spans;
  }

  List<InlineSpan> _parseEmphasis(String text, TextStyle currentStyle) {
    if (text.isEmpty) return const [];

    final spans = <InlineSpan>[];
    int i = 0;
    int plainStart = 0;

    while (i < text.length) {
      final ch = text[i];
      if (ch == '*' || ch == '_' || ch == '~') {
        final closeIdx = _findClosingMarker(text, i, ch);
        if (closeIdx != -1) {
          if (i > plainStart) {
            spans.add(
              TextSpan(
                text: text.substring(plainStart, i),
                style: currentStyle,
              ),
            );
          }

          final innerText = text.substring(i + 1, closeIdx);
          final nextStyle = _applyMarkerStyle(currentStyle, ch);
          spans.addAll(_parseEmphasis(innerText, nextStyle));

          i = closeIdx + 1;
          plainStart = i;
          continue;
        }
      }
      i++;
    }

    if (plainStart < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(plainStart),
          style: currentStyle,
        ),
      );
    }

    return spans;
  }

  int _findClosingMarker(String text, int openIdx, String marker) {
    if (openIdx + 2 >= text.length) return -1;

    // Opening marker cannot be followed by whitespace
    if (_isWhitespace(text[openIdx + 1])) return -1;

    // WhatsApp ignores _ inside alphanumeric words (e.g. snake_case)
    if (marker == '_' &&
        openIdx > 0 &&
        _isWordChar(text[openIdx - 1])) {
      return -1;
    }

    for (int j = openIdx + 2; j < text.length; j++) {
      if (text[j] == '\n') return -1;
      if (text[j] == marker) {
        // Closing marker cannot be preceded by whitespace
        if (_isWhitespace(text[j - 1])) continue;
        // For underscore, closing marker cannot be followed directly by word char
        if (marker == '_' &&
            j + 1 < text.length &&
            _isWordChar(text[j + 1])) {
          continue;
        }
        return j;
      }
    }
    return -1;
  }

  bool _isWhitespace(String ch) => ch == ' ' || ch == '\t' || ch == '\n';

  bool _isWordChar(String ch) => RegExp(r'[A-Za-z0-9]').hasMatch(ch);

  TextStyle _applyMarkerStyle(TextStyle style, String marker) {
    switch (marker) {
      case '*':
        return style.copyWith(fontWeight: FontWeight.w700);
      case '_':
        return style.copyWith(fontStyle: FontStyle.italic);
      case '~':
        return style.copyWith(
          decoration: style.decoration == null
              ? TextDecoration.lineThrough
              : TextDecoration.combine(
                  [style.decoration!, TextDecoration.lineThrough],
                ),
        );
      default:
        return style;
    }
  }
}

sealed class _WaBlock {
  const _WaBlock();
}

class _WaSpacerBlock extends _WaBlock {
  const _WaSpacerBlock();
}

class _WaMonoBlock extends _WaBlock {
  final String content;
  const _WaMonoBlock(this.content);
}

class _WaQuoteBlock extends _WaBlock {
  final List<String> lines;
  const _WaQuoteBlock(this.lines);
}

class _WaBulletBlock extends _WaBlock {
  final int indentLevel;
  final String content;
  const _WaBulletBlock(this.indentLevel, this.content);
}

class _WaNumberedBlock extends _WaBlock {
  final int indentLevel;
  final String number;
  final String content;
  const _WaNumberedBlock(this.indentLevel, this.number, this.content);
}

class _WaParagraphBlock extends _WaBlock {
  final String content;
  const _WaParagraphBlock(this.content);
}
