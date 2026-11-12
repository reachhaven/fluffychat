// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026 vDL Digital Ventures
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/utils/markdown_formatting_extension.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

TextEditingValue _value(String text, int start, [int? end]) => TextEditingValue(
  text: text,
  selection: TextSelection(baseOffset: start, extentOffset: end ?? start),
);

void main() {
  group('Code block', () {
    test('puts the selected lines into a block on their own lines', () {
      final result = _value('see\nfoo()\nbar() ok', 4, 15).wrapInCodeBlock();
      expect(result.text, 'see\n```\nfoo()\nbar()\n```\n ok');
      expect(result.selection.textInside(result.text), 'foo()\nbar()');
    });

    test('inserts an empty block with the caret inside', () {
      final result = _value('Look: ', 6).wrapInCodeBlock();
      expect(result.text, 'Look: \n```\n\n```');
      expect(result.selection, const TextSelection.collapsed(offset: 11));
    });

    test('uses a longer fence when the code contains one', () {
      final result = _value('```md\nx\n```', 0, 11).wrapInCodeBlock();
      expect(result.text, '````\n```md\nx\n```\n````');
    });
  });

  group('Inline code', () {
    test('wraps the selection', () {
      final result = _value('call foo() now', 5, 10).wrapInline('`');
      expect(result.text, 'call `foo()` now');
      expect(result.selection.textInside(result.text), 'foo()');
    });

    test('inserts an empty span with the caret inside', () {
      final result = _value('a ', 2).wrapInline('`');
      expect(result.text, 'a ``');
      expect(result.selection, const TextSelection.collapsed(offset: 3));
    });

    test('uses longer backtick strings around backticks', () {
      expect(_value('a`b', 0, 3).wrapInline('`').text, '``a`b``');
      expect(_value('`x', 0, 2).wrapInline('`').text, '`` `x ``');
    });
  });

  Future<TextEditingController> pumpComposer(WidgetTester tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode(
      onKeyEvent: (node, event) {
        final formatted = controller.value.applyMarkdownShortcut(event);
        if (formatted == null) return KeyEventResult.ignored;
        controller.value = formatted;
        return KeyEventResult.handled;
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextField(controller: controller, focusNode: focusNode),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    return controller;
  }

  Future<void> press(
    WidgetTester tester,
    List<LogicalKeyboardKey> modifiers,
    LogicalKeyboardKey key,
  ) async {
    for (final modifier in modifiers) {
      await tester.sendKeyDownEvent(modifier);
    }
    await tester.sendKeyEvent(key);
    for (final modifier in modifiers.reversed) {
      await tester.sendKeyUpEvent(modifier);
    }
    await tester.pump();
  }

  const ctrl = LogicalKeyboardKey.controlLeft;
  const shift = LogicalKeyboardKey.shiftLeft;

  testWidgets('Shortcuts format the selection', (tester) async {
    final controller = await pumpComposer(tester);

    controller.value = _value('say hi', 4, 6);
    await press(tester, [ctrl], LogicalKeyboardKey.keyB);
    expect(controller.text, 'say **hi**');

    controller.value = _value('say hi', 4, 6);
    await press(tester, [ctrl], LogicalKeyboardKey.keyI);
    expect(controller.text, 'say *hi*');

    controller.value = _value('say hi', 4, 6);
    await press(tester, [ctrl, shift], LogicalKeyboardKey.keyC);
    expect(controller.text, 'say `hi`');

    controller.value = _value('see docs', 4, 8);
    await press(tester, [ctrl], LogicalKeyboardKey.keyK);
    expect(controller.text, 'see [docs]()');
    expect(controller.selection, const TextSelection.collapsed(offset: 11));
  });

  testWidgets('Without a selection the markers surround the caret', (
    tester,
  ) async {
    final controller = await pumpComposer(tester);
    controller.value = _value('a ', 2);
    await press(tester, [ctrl], LogicalKeyboardKey.keyB);
    expect(controller.text, 'a ****');
    expect(controller.selection, const TextSelection.collapsed(offset: 4));

    controller.value = _value('', 0);
    await press(tester, [ctrl], LogicalKeyboardKey.keyK);
    expect(controller.text, '[]()');
    expect(controller.selection, const TextSelection.collapsed(offset: 1));
  });

  testWidgets('Keys without Ctrl are left to the text field', (tester) async {
    final controller = await pumpComposer(tester);
    controller.value = _value('say hi', 4, 6);
    await press(tester, [], LogicalKeyboardKey.keyB);
    await press(tester, [shift], LogicalKeyboardKey.keyC);
    expect(controller.text, 'say hi');
  });

  testWidgets(
    'Shortcuts without a valid selection are left to the text field',
    (tester) async {
      await pumpComposer(tester);
      await tester.sendKeyDownEvent(ctrl);
      const keyB = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyB,
        logicalKey: LogicalKeyboardKey.keyB,
        timeStamp: Duration.zero,
      );
      expect(
        const TextEditingValue(text: 'draft').applyMarkdownShortcut(keyB),
        isNull,
      );
      expect(_value('draft', 5).applyMarkdownShortcut(keyB)?.text, 'draft****');
      await tester.sendKeyUpEvent(ctrl);
    },
  );

  testWidgets('Apple platforms use Cmd and leave Ctrl to the text field', (
    tester,
  ) async {
    final controller = await pumpComposer(tester);
    controller.value = _value('say hi', 4, 6);
    await press(tester, [
      LogicalKeyboardKey.metaLeft,
      shift,
    ], LogicalKeyboardKey.keyC);
    expect(controller.text, 'say `hi`');

    controller.value = _value('say hi', 4, 6);
    await press(tester, [ctrl], LogicalKeyboardKey.keyB);
    expect(controller.text, 'say hi');
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
