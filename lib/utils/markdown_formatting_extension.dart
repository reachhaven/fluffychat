// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026 vDL Digital Ventures
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// Code fences and code span markers are longer than any backtick run in the
// code, and a code span that starts or ends with a backtick is padded with a
// space (CommonMark 0.31.2, sections 4.5 and 6.1).
extension MarkdownFormattingExtension on TextEditingValue {
  TextEditingValue wrapInline(String marker) {
    if (!selection.isValid) return this;
    final selected = selection.textInside(text);
    var open = marker;
    var close = marker;
    if (marker == '`') {
      final ticks = '`' * (_longestBacktickRun(selected) + 1);
      final pad = selected.startsWith('`') || selected.endsWith('`') ? ' ' : '';
      open = '$ticks$pad';
      close = '$pad$ticks';
    }
    final start = selection.start + open.length;
    return TextEditingValue(
      text: text.replaceRange(
        selection.start,
        selection.end,
        '$open$selected$close',
      ),
      selection: TextSelection(
        baseOffset: start,
        extentOffset: start + selected.length,
      ),
    );
  }

  TextEditingValue wrapInCodeBlock() {
    if (!selection.isValid) return this;
    final selected = selection.textInside(text);
    final content = selected.endsWith('\n')
        ? selected.substring(0, selected.length - 1)
        : selected;
    final fence = '`' * max(3, _longestBacktickRun(content) + 1);
    final before = selection.start == 0 || text[selection.start - 1] == '\n'
        ? ''
        : '\n';
    final after = selection.end == text.length || text[selection.end] == '\n'
        ? ''
        : '\n';
    final start = selection.start + before.length + fence.length + 1;
    return TextEditingValue(
      text: text.replaceRange(
        selection.start,
        selection.end,
        '$before$fence\n$content\n$fence$after',
      ),
      selection: TextSelection(
        baseOffset: start,
        extentOffset: start + content.length,
      ),
    );
  }

  TextEditingValue wrapInLink() {
    if (!selection.isValid) return this;
    final selected = selection.textInside(text);
    final caret =
        selection.start + (selected.isEmpty ? 1 : selected.length + 3);
    return TextEditingValue(
      text: text.replaceRange(selection.start, selection.end, '[$selected]()'),
      selection: TextSelection.collapsed(offset: caret),
    );
  }

  TextEditingValue? applyMarkdownShortcut(KeyEvent event) {
    if (event is! KeyDownEvent || !selection.isValid) return null;
    final keyboard = HardwareKeyboard.instance;
    final isApple = {
      TargetPlatform.macOS,
      TargetPlatform.iOS,
    }.contains(defaultTargetPlatform);
    final modifier = isApple
        ? keyboard.isMetaPressed
        : keyboard.isControlPressed;
    if (!modifier) return null;
    final shift = keyboard.isShiftPressed;
    return switch (event.logicalKey) {
      LogicalKeyboardKey.keyB when !shift => wrapInline('**'),
      LogicalKeyboardKey.keyI when !shift => wrapInline('*'),
      LogicalKeyboardKey.keyK when !shift => wrapInLink(),
      LogicalKeyboardKey.keyC when shift => wrapInline('`'),
      _ => null,
    };
  }
}

int _longestBacktickRun(String text) =>
    RegExp('`+').allMatches(text).fold(0, (run, m) => max(run, m[0]!.length));
