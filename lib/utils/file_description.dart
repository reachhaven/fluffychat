// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix.dart';

extension FileDescriptionExtension on Event {
  String? get fileDescription {
    if (!{
      MessageTypes.File,
      MessageTypes.Image,
      MessageTypes.Sticker,
      MessageTypes.Video,
      MessageTypes.Audio,
    }.contains(messageType)) {
      return null;
    }
    final filename = content.tryGet<String>('filename');
    final body = calcUnlocalizedBody(hideReply: true, plaintextBody: true);

    if (filename != body &&
        filename != null &&
        content.tryGet<String>('body')?.isNotEmpty == true) {
      return body;
    }
    return null;
  }

  bool get isFileMessage => const {
    MessageTypes.File,
    MessageTypes.Image,
    MessageTypes.Video,
    MessageTypes.Audio,
  }.contains(messageType);

  String editableText(MatrixLocalizations i18n) {
    if (!isFileMessage) {
      return calcLocalizedBodyFallback(
        i18n,
        withSenderNamePrefix: false,
        hideReply: true,
      );
    }
    if (fileDescription == null) return '';
    return calcUnlocalizedBody(hideReply: true);
  }

  Map<String, Object?> contentWithFileDescription(String description) {
    final filename =
        content.tryGet<String>('filename') ??
        content.tryGet<String>('body') ??
        '';
    return {
      for (final entry in content.entries)
        if (!{
          'm.relates_to',
          'm.new_content',
          'm.mentions',
          'format',
          'formatted_body',
        }.contains(entry.key))
          entry.key: entry.value,
      'filename': filename,
      'body': description.trim().isEmpty ? filename : description.trim(),
      'm.mentions': <String, Object?>{},
    };
  }
}
