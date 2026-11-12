// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026 vDL Digital Ventures
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/platform_infos.dart';
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

  testWidgets('About states the licence, the copyright and the app name', (
    tester,
  ) async {
    await AppSettings.applicationName.setItem('Team Chat');
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
    final notice = find.textContaining('GNU Affero General Public License');
    expect(notice, findsOneWidget);
    final text = tester.widget<Text>(notice).data!;
    expect(text, startsWith('Team Chat is free software'));
    expect(text, contains('no warranty'));
    expect(text, contains('© 2019 Christian Kußowski'));
    expect(find.byIcon(Icons.source_outlined), findsOneWidget);
  });
}
