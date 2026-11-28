import 'package:flutter/material.dart';

enum WhatsAppInlineFormat {
  bold,
  italic,
  strikethrough,
  monospace,
  inlineCode,
}

enum WhatsAppLineFormat {
  bulletedList,
  numberedList,
  blockQuote,
}

class WhatsAppFormatter {
  static String markerFor(WhatsAppInlineFormat format) {
    switch (format) {
      case WhatsAppInlineFormat.bold:
        return '*';
      case WhatsAppInlineFormat.italic:
        return '_';
      case WhatsAppInlineFormat.strikethrough:
        return '~';
      case WhatsAppInlineFormat.monospace:
        return '```';
      case WhatsAppInlineFormat.inlineCode:
        return '`';
    }
  }

  /// Wraps or unwraps selected text with WhatsApp inline markers, or inserts
  /// markers at the cursor position ready to type inside.
  static void toggleInline(
    TextEditingController ctrl,
    WhatsAppInlineFormat format,
  ) {
    final text = ctrl.text;
    final marker = markerFor(format);
    final mLen = marker.length;

    final rawSel = ctrl.selection;
    final start = rawSel.isValid
        ? rawSel.start.clamp(0, text.length)
        : text.length;
    final end = rawSel.isValid
        ? rawSel.end.clamp(0, text.length)
        : text.length;
    final selStart = start <= end ? start : end;
    final selEnd = start <= end ? end : start;

    // Case 1: Collapsed cursor
    if (selStart == selEnd) {
      final hasBefore =
          selStart >= mLen && text.substring(selStart - mLen, selStart) == marker;
      final hasAfter = selStart + mLen <= text.length &&
          text.substring(selStart, selStart + mLen) == marker;

      if (hasBefore && hasAfter) {
        final next = text.replaceRange(selStart - mLen, selStart + mLen, '');
        ctrl.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: selStart - mLen),
        );
        return;
      }

      final next = text.replaceRange(selStart, selStart, '$marker$marker');
      ctrl.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: selStart + mLen),
      );
      return;
    }

    // Case 2: Text range selected
    final selected = text.substring(selStart, selEnd);

    // Check if selection itself already includes the markers
    if (selected.length >= mLen * 2 &&
        selected.startsWith(marker) &&
        selected.endsWith(marker)) {
      final inner = selected.substring(mLen, selected.length - mLen);
      final next = text.replaceRange(selStart, selEnd, inner);
      ctrl.value = TextEditingValue(
        text: next,
        selection: TextSelection(
          baseOffset: selStart,
          extentOffset: selStart + inner.length,
        ),
      );
      return;
    }

    // Check if markers wrap immediately outside the selection
    final outsideBefore = selStart >= mLen &&
        text.substring(selStart - mLen, selStart) == marker;
    final outsideAfter = selEnd + mLen <= text.length &&
        text.substring(selEnd, selEnd + mLen) == marker;
    if (outsideBefore && outsideAfter) {
      final next =
          text.replaceRange(selStart - mLen, selEnd + mLen, selected);
      ctrl.value = TextEditingValue(
        text: next,
        selection: TextSelection(
          baseOffset: selStart - mLen,
          extentOffset: selEnd - mLen,
        ),
      );
      return;
    }

    // Preserve outer whitespace outside WhatsApp markers so WhatsApp renders properly
    final leadMatch = RegExp(r'^\s+').firstMatch(selected);
    final trailMatch = RegExp(r'\s+$').firstMatch(selected);
    final lead = leadMatch?.group(0) ?? '';
    final trail = trailMatch?.group(0) ?? '';

    if (lead.length + trail.length >= selected.length) {
      final next = text.replaceRange(selStart, selEnd, '$marker$marker');
      ctrl.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: selStart + mLen),
      );
      return;
    }

    final core = selected.substring(lead.length, selected.length - trail.length);
    if (core.length >= mLen * 2 &&
        core.startsWith(marker) &&
        core.endsWith(marker)) {
      final inner = core.substring(mLen, core.length - mLen);
      final replacement = '$lead$inner$trail';
      final next = text.replaceRange(selStart, selEnd, replacement);
      ctrl.value = TextEditingValue(
        text: next,
        selection: TextSelection(
          baseOffset: selStart + lead.length,
          extentOffset: selStart + lead.length + inner.length,
        ),
      );
      return;
    }

    final wrapped = '$lead$marker$core$marker$trail';
    final next = text.replaceRange(selStart, selEnd, wrapped);
    final innerStart = selStart + lead.length + mLen;
    ctrl.value = TextEditingValue(
      text: next,
      selection: TextSelection(
        baseOffset: innerStart,
        extentOffset: innerStart + core.length,
      ),
    );
  }

  static final RegExp _bulletPrefixRe = RegExp(r'^(\s*)-\s(.*)$');
  static final RegExp _bulletEmptyRe = RegExp(r'^(\s*)-\s*$');
  static final RegExp _numberPrefixRe = RegExp(r'^(\s*)(\d+)\.\s(.*)$');
  static final RegExp _numberEmptyRe = RegExp(r'^(\s*)(\d+)\.\s*$');
  static final RegExp _quotePrefixRe = RegExp(r'^(\s*)>\s?(.*)$');
  static final RegExp _anyPrefixRe = RegExp(r'^(\s*)(?:-\s+|\d+\.\s+|>\s?)');

  static bool _lineHasFormat(String line, WhatsAppLineFormat format) {
    switch (format) {
      case WhatsAppLineFormat.bulletedList:
        return _bulletPrefixRe.hasMatch(line) || _bulletEmptyRe.hasMatch(line);
      case WhatsAppLineFormat.numberedList:
        return _numberPrefixRe.hasMatch(line) || _numberEmptyRe.hasMatch(line);
      case WhatsAppLineFormat.blockQuote:
        return _quotePrefixRe.hasMatch(line);
    }
  }

  static String _stripPrefix(String line) {
    final m = _anyPrefixRe.firstMatch(line);
    if (m == null) return line;
    final indent = m.group(1) ?? '';
    return '$indent${line.substring(m.end)}';
  }

  /// Toggles `- `, `1. ` (auto-numbering multi-line selections), or `> ` on
  /// the current line or all selected lines.
  static void toggleLinePrefix(
    TextEditingController ctrl,
    WhatsAppLineFormat format,
  ) {
    final text = ctrl.text;
    final rawSel = ctrl.selection;
    final start = rawSel.isValid
        ? rawSel.start.clamp(0, text.length)
        : text.length;
    final end = rawSel.isValid
        ? rawSel.end.clamp(0, text.length)
        : text.length;
    final selStart = start <= end ? start : end;
    final selEnd = start <= end ? end : start;

    final blockStart =
        selStart == 0 ? 0 : text.lastIndexOf('\n', selStart - 1) + 1;
    final nextNewline = text.indexOf('\n', selEnd);
    final blockEnd = nextNewline == -1 ? text.length : nextNewline;

    final blockText = text.substring(blockStart, blockEnd);
    final lines = blockText.split('\n');

    final nonEmptyLines = lines.where((l) => l.trim().isNotEmpty).toList();
    final alreadyFormatted = lines.length == 1
        ? _lineHasFormat(lines.first, format)
        : (nonEmptyLines.isNotEmpty &&
            nonEmptyLines.every((l) => _lineHasFormat(l, format)));

    int nextNumber = 1;
    if (!alreadyFormatted &&
        format == WhatsAppLineFormat.numberedList &&
        lines.length == 1 &&
        blockStart > 0) {
      final prevLineEnd = blockStart - 1;
      final prevLineStart = prevLineEnd == 0
          ? 0
          : text.lastIndexOf('\n', prevLineEnd - 1) + 1;
      final prevLine = text.substring(prevLineStart, prevLineEnd);
      final prevNumMatch = _numberPrefixRe.firstMatch(prevLine);
      if (prevNumMatch != null) {
        nextNumber = (int.tryParse(prevNumMatch.group(2)!) ?? 0) + 1;
      }
    }

    final updatedLines = <String>[];
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (alreadyFormatted) {
        updatedLines.add(_stripPrefix(line));
      } else {
        if (lines.length > 1 && line.trim().isEmpty) {
          updatedLines.add(line);
          continue;
        }
        final clean = _stripPrefix(line);
        final indentMatch = RegExp(r'^(\s*)').firstMatch(clean);
        final indent = indentMatch?.group(1) ?? '';
        final body = clean.substring(indent.length);
        switch (format) {
          case WhatsAppLineFormat.bulletedList:
            updatedLines.add('$indent- $body');
          case WhatsAppLineFormat.numberedList:
            updatedLines.add('$indent$nextNumber. $body');
            nextNumber++;
          case WhatsAppLineFormat.blockQuote:
            updatedLines.add('$indent> $body');
        }
      }
    }

    final replacement = updatedLines.join('\n');
    final nextText = text.replaceRange(blockStart, blockEnd, replacement);

    final newSel = selStart == selEnd
        ? TextSelection.collapsed(offset: blockStart + replacement.length)
        : TextSelection(
            baseOffset: blockStart,
            extentOffset: blockStart + replacement.length,
          );

    ctrl.value = TextEditingValue(text: nextText, selection: newSel);
  }

  /// Detects a single Enter (`\n`) inserted at the caret inside a `- `,
  /// `N. `, or `> ` line and inserts the continuing prefix on the new line.
  /// Pressing Enter on an empty prefix line exits the list/quote cleanly.
  static String handleEnterAutoContinue(
    TextEditingController ctrl,
    String previousText,
  ) {
    final newText = ctrl.text;
    final sel = ctrl.selection;

    if (!sel.isValid || !sel.isCollapsed) return newText;
    if (newText.length != previousText.length + 1) return newText;

    final cursor = sel.baseOffset;
    if (cursor <= 0 || cursor > newText.length) return newText;
    if (newText[cursor - 1] != '\n') return newText;

    final withoutNewline =
        newText.substring(0, cursor - 1) + newText.substring(cursor);
    if (withoutNewline != previousText) return newText;

    final prevLineEnd = cursor - 1;
    final prevLineStart = prevLineEnd == 0
        ? 0
        : newText.lastIndexOf('\n', prevLineEnd - 1) + 1;
    final prevLine = newText.substring(prevLineStart, prevLineEnd);

    String? nextPrefix;
    bool isEmptyItem = false;

    final numMatch = _numberPrefixRe.firstMatch(prevLine);
    if (numMatch != null) {
      final indent = numMatch.group(1) ?? '';
      final num = int.tryParse(numMatch.group(2) ?? '1') ?? 1;
      final body = numMatch.group(3) ?? '';
      isEmptyItem = body.trim().isEmpty;
      nextPrefix = '$indent${num + 1}. ';
    } else {
      final bulletMatch = _bulletPrefixRe.firstMatch(prevLine);
      if (bulletMatch != null) {
        final indent = bulletMatch.group(1) ?? '';
        final body = bulletMatch.group(2) ?? '';
        isEmptyItem = body.trim().isEmpty;
        nextPrefix = '$indent- ';
      } else {
        final quoteMatch = _quotePrefixRe.firstMatch(prevLine);
        if (quoteMatch != null && prevLine.trimLeft().startsWith('> ')) {
          final indent = quoteMatch.group(1) ?? '';
          final body = quoteMatch.group(2) ?? '';
          isEmptyItem = body.trim().isEmpty;
          nextPrefix = '$indent> ';
        }
      }
    }

    if (nextPrefix == null) return newText;

    if (isEmptyItem) {
      // Remove the empty marker + newly inserted newline so cursor stays on clean line
      final updated = newText.replaceRange(prevLineStart, cursor, '');
      ctrl.value = TextEditingValue(
        text: updated,
        selection: TextSelection.collapsed(offset: prevLineStart),
      );
      return updated;
    }

    final updated = newText.replaceRange(cursor, cursor, nextPrefix);
    ctrl.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: cursor + nextPrefix.length),
    );
    return updated;
  }

  /// Inserts a template variable or snippet at the active cursor/selection.
  static void insertAtCursor(TextEditingController ctrl, String snippet) {
    final text = ctrl.text;
    final rawSel = ctrl.selection;
    final start = rawSel.isValid
        ? rawSel.start.clamp(0, text.length)
        : text.length;
    final end = rawSel.isValid
        ? rawSel.end.clamp(0, text.length)
        : text.length;
    final selStart = start <= end ? start : end;
    final selEnd = start <= end ? end : start;

    final nextText = text.replaceRange(selStart, selEnd, snippet);
    ctrl.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: selStart + snippet.length),
    );
  }
}
