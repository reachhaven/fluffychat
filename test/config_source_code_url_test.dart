// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026 vDL Digital Ventures
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.init(loadWebConfigFile: false);
    PackageInfo.setMockInitialValues(
      appName: 'FluffyChat',
      packageName: 'chat.fluffy.fluffychat',
      version: '2.11.5',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  Future<String?> openSourceCode(WidgetTester tester) async {
    String? launched;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (call) async {
        if (call.method == 'launch') {
          launched = (call.arguments as Map)['url'] as String;
        }
        return true;
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => PlatformInfos.showDialog(context),
            child: const Text('about'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('about'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.source_outlined));
    await tester.pumpAndSettle();
    return launched;
  }

  testWidgets('About links upstream by default', (tester) async {
    expect(
      await openSourceCode(tester),
      'https://github.com/krille-chan/fluffychat',
    );
  });

  testWidgets('About links the configured source code', (tester) async {
    await AppSettings.sourceCodeUrl.setItem('https://git.example.org/chat');
    expect(await openSourceCode(tester), 'https://git.example.org/chat');
  });
}
