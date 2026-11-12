// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026 vDL Digital Ventures
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.init(loadWebConfigFile: false);
  });

  Future<ThemeData> theme(WidgetTester tester) async {
    late ThemeData theme;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          theme = FluffyThemes.buildTheme(context, Brightness.light);
          return const SizedBox();
        },
      ),
    );
    return theme;
  }

  testWidgets('Without a configured font the default stays', (tester) async {
    await AppSettings.store.remove(AppSettings.fontFamily.key);
    final defaultFamily = ThemeData(
      useMaterial3: true,
    ).textTheme.bodyMedium?.fontFamily;
    expect(
      (await theme(tester)).textTheme.bodyMedium?.fontFamily,
      defaultFamily,
    );
  });

  testWidgets('A configured font family is used for all text', (tester) async {
    await AppSettings.fontFamily.setItem('Inter');
    final textTheme = (await theme(tester)).textTheme;
    expect(textTheme.bodyMedium?.fontFamily, 'Inter');
    expect(textTheme.titleLarge?.fontFamily, 'Inter');
    expect(textTheme.labelSmall?.fontFamily, 'Inter');
  });
}
