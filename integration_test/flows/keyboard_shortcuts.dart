// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026 vDL Digital Ventures
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/setting_keys.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../utils/fluffy_chat_tester.dart';
import 'auth_flows.dart';
import 'chat_flows.dart';

Future<void> keyboardShortcuts(WidgetTester widgetTester) => widgetTester
    .startFluffyChatTest()
    .then((tester) => tester._keyboardShortcuts());

extension on FluffyChatTester {
  Future<void> _keyboardShortcuts() async {
    await ensureLoggedIn();
    await ensureGroupChatCreated();
    await tapOn(ChatFlows.groupChatName);

    final sendOnEnter = AppSettings.sendOnEnter.value;
    addTearDown(() => AppSettings.sendOnEnter.setItem(sendOnEnter));
    await AppSettings.sendOnEnter.setItem(true);

    final input = find.byKey(const Key('chat_input_field'));
    String inputText() => tester
        .widget<EditableText>(
          find.descendant(of: input, matching: find.byType(EditableText)),
        )
        .controller
        .text;

    await tester.tap(input);
    await tester.enterText(input, 'hello');
    await sendKeyCombo(LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyA);
    await sendKeyCombo(LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyB);
    expect(inputText(), '**hello**');

    await tester.enterText(input, '- first');
    await sendKeyCombo(LogicalKeyboardKey.shiftLeft, LogicalKeyboardKey.enter);
    expect(inputText(), '- first\n- ');

    const message = 'Sent with Enter';
    await tester.enterText(input, message);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await waitFor(message);
    expect(inputText(), isEmpty);
    await goBack();
  }
}
