// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026 vDL Digital Ventures
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat/events/html_message.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/formatted_body_extension.dart';
import 'package:fluffychat/utils/url_launcher.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

class ComposerPreview extends StatefulWidget {
  final Room room;
  final TextEditingController controller;

  const ComposerPreview({
    required this.room,
    required this.controller,
    super.key,
  });

  @override
  State<ComposerPreview> createState() => _ComposerPreviewState();
}

class _ComposerPreviewState extends State<ComposerPreview> {
  String _text = '';
  String _html = '';

  @override
  void initState() {
    super.initState();
    _render();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(ComposerPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_onChanged);
    widget.controller.addListener(_onChanged);
    _render();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (widget.controller.text == _text) return;
    setState(_render);
  }

  void _render() {
    _text = widget.controller.text;
    _html = widget.room.previewHtml(_text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_text.trim().isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        child: Text(
          L10n.of(context).nothingToPreview,
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(AppSettings.fontSizeFactor.value),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 240),
        child: Semantics(
          label: L10n.of(context).preview,
          container: true,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: HtmlMessage(
              html: _html,
              room: widget.room,
              textColor: theme.colorScheme.onSurface,
              fontSize: AppConfig.messageFontSize,
              linkStyle: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: AppConfig.messageFontSize,
                decoration: TextDecoration.underline,
                decorationColor: theme.colorScheme.primary,
              ),
              onOpen: (url) => UrlLauncher(context, url.url).launchUrl(),
            ),
          ),
        ),
      ),
    );
  }
}
