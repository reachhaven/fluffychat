// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026 vDL Digital Ventures
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat/events/html_message.dart';
import 'package:fluffychat/utils/code_highlight_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Room room;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.init(loadWebConfigFile: false);
    final client = Client(
      'html message test',
      database: await MatrixSdkDatabase.init(
        'test',
        database: await databaseFactoryFfi.openDatabase(':memory:'),
        sqfliteFactory: databaseFactoryFfi,
      ),
    );
    room = Room(id: '!room:example.org', client: client);
  });

  Future<void> pumpHtml(
    WidgetTester tester,
    String html, {
    TextDirection textDirection = TextDirection.ltr,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Scaffold(
          body: Directionality(
            textDirection: textDirection,
            child: HtmlMessage(
              html: html,
              room: room,
              fontSize: 16,
              linkStyle: const TextStyle(),
              onOpen: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder codeText(String code) => find.byWidgetPredicate(
    (widget) =>
        widget is RichText &&
        widget.text.toPlainText() == code &&
        widget.text.style?.fontFamily == 'monospace',
  );

  final codeBlock = find.byWidgetPredicate(
    (widget) => widget is Material && widget.color == atomOneBackgroundColor,
  );

  testWidgets('Code blocks and inline code use a monospace font', (
    tester,
  ) async {
    await pumpHtml(
      tester,
      '<p>Run <code>ls -la</code></p><pre><code class="language-dart">final a = 1;\n</code></pre>',
    );
    expect(codeText('ls -la'), findsOneWidget);
    expect(codeText('final a = 1;\n'), findsOneWidget);
  });

  testWidgets('The copy button fits into a one-line block at its end', (
    tester,
  ) async {
    for (final textDirection in TextDirection.values) {
      await pumpHtml(
        tester,
        '<pre><code>x = 1</code></pre>',
        textDirection: textDirection,
      );
      final block = tester.getRect(codeBlock);
      final button = tester.getRect(find.byType(IconButton));
      expect(block.intersect(button), button);
      expect(
        textDirection == TextDirection.ltr ? button.right : button.left,
        textDirection == TextDirection.ltr ? block.right : block.left,
      );
    }
  });

  testWidgets(
    'The copy button copies the code block without the last line break',
    (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      await pumpHtml(
        tester,
        '<pre><code>docker run \\\n  --rm image\n</code></pre><p>and <code>inline</code></p>',
      );
      expect(find.byIcon(Icons.copy_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.copy_outlined));
      await tester.pump();
      expect(copied, 'docker run \\\n  --rm image');
    },
  );
}
