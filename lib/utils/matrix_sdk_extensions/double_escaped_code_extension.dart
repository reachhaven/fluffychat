// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026 vDL Digital Ventures
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:html/parser.dart' as parser;

extension DoubleEscapedCodeExtension on String {
  /// Workaround for https://github.com/famedly/matrix-dart-sdk/issues/2356:
  /// code in the formatted body is escaped twice. The plain [body] holds what
  /// the sender typed. Each code element is looked up in it in document order,
  /// together with the delimiters of its code span or fenced code block
  /// (https://spec.commonmark.org/0.31.2/#code-spans,
  /// https://spec.commonmark.org/0.31.2/#fenced-code-blocks), and the walk
  /// stops at the first one it does not find.
  String unescapeDoubleEscapedCode(String body) {
    if (!contains('&amp;lt;') && !contains('&amp;gt;')) return this;
    final fragment = parser.parseFragment(this);
    var changed = false;
    var start = 0;
    for (final code in fragment.querySelectorAll('code')) {
      final text = code.text;
      final typed = RegExp.escape(
        text,
      ).replaceAll('&lt;', '(?:&lt;|<)').replaceAll('&gt;', '(?:&gt;|>)');
      final delimited = code.parent?.localName == 'pre'
          ? '(?<![^\\n])[ \\t>]*(?:```|~~~)[^\\n]*\\n[ \\t>]*($typed)[ \\t>]*(?:```|~~~|\$)'
          : '(?<!`)`+ ?($typed) ?`+';
      final match = RegExp(delimited).allMatches(body, start).firstOrNull;
      if (match == null) break;
      start = match.end;
      final typedText = match[1]!;
      if (typedText == text) continue;
      code.text = typedText;
      changed = true;
    }
    return changed ? fragment.outerHtml : this;
  }
}
