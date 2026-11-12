// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026 vDL Digital Ventures
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/setting_keys.dart';
import 'package:matrix/matrix.dart';
// Workaround: the Matrix Dart SDK does not export markdown().
// ignore: implementation_imports
import 'package:matrix/src/utils/markdown.dart';

extension FormattedBodyExtension on Room {
  String formattedBodyFor(String text) => markdown(
    text,
    getEmotePacks: () => getImagePacksFlat(ImagePackUsage.emoticon),
    getMention: getMention,
    convertLinebreaks: client.convertLinebreaksInFormatting,
    enableLatex: client.enableLatexMarkdown,
  );

  String previewHtml(String text) => AppSettings.renderHtml.value
      ? formattedBodyFor(text)
      : text.replaceAll('<', '&lt;').replaceAll('>', '&gt;');
}
