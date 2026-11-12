// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026 vDL Digital Ventures
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/app_config.dart';
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

  BorderRadius chipRadius(ThemeData theme) =>
      (theme.chipTheme.shape as RoundedRectangleBorder).borderRadius
          as BorderRadius;

  testWidgets('Without a configured radius the corners stay as they were', (
    tester,
  ) async {
    await AppSettings.store.remove(AppSettings.borderRadius.key);
    expect(AppConfig.borderRadius, 18);
    expect(AppConfig.spaceBorderRadius, 11);
    expect(chipRadius(await theme(tester)).topLeft.x, 18);
  });

  testWidgets('A configured radius shapes the corners', (tester) async {
    await AppSettings.borderRadius.setItem(4);
    expect(AppConfig.borderRadius, 4);
    expect(AppConfig.spaceBorderRadius, 4);
    expect(chipRadius(await theme(tester)).topLeft.x, 4);
  });
}
