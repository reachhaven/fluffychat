// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026 vDL Digital Ventures
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat/composer_preview.dart';
import 'package:fluffychat/pages/chat/events/html_message.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/formatted_body_extension.dart';
import 'package:fluffychat/widgets/fluffy_chat_app.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const roomId = '!1234:fakeServer.notExisting';

const message = '''||Spoiler|| for @Alice :emote:

```dart
final list = [1, 2];
```

- one
- two

| Name | Value |
| --- | --- |
| a | 1 |

A [link](https://example.org).''';

final withoutAvatars = message.replaceFirst(' for @Alice :emote:', '');

Future<Room> joinFixtureRoom(Client client) async {
  await client.handleSync(
    SyncUpdate(
      nextBatch: '',
      rooms: RoomsUpdate(join: {roomId: JoinedRoomUpdate()}),
    ),
  );
  final room = client.getRoomById(roomId)!;
  for (final (type, stateKey, content) in [
    (
      EventTypes.RoomMember,
      client.userID!,
      {'membership': 'join', 'displayname': 'Test User'},
    ),
    (
      EventTypes.RoomMember,
      '@alice:example.org',
      {'membership': 'join', 'displayname': 'Alice'},
    ),
    (
      'im.ponies.room_emotes',
      '',
      {
        'images': {
          'emote': {'url': 'mxc://example.org/emote'},
        },
      },
    ),
  ]) {
    room.setState(
      Event(
        type: type,
        stateKey: stateKey,
        content: content,
        senderId: '@alice:example.org',
        eventId: '\$$type$stateKey',
        originServerTs: DateTime.now(),
        room: room,
      ),
    );
  }
  return room;
}

class _FakeNotifications extends FlutterLocalNotificationsPlatform {}

Future<Client> fakeClient({bool convertLinebreaksInFormatting = true}) async {
  final client = Client(
    'FluffyChat Test',
    httpClient: FakeMatrixApi(),
    convertLinebreaksInFormatting: convertLinebreaksInFormatting,
    database: await MatrixSdkDatabase.init(
      'test',
      database: await databaseFactoryFfi.openDatabase(':memory:'),
      sqfliteFactory: databaseFactoryFfi,
    ),
  );
  await client.init(
    newHomeserver: Uri.parse('https://fakeServer.notExisting'),
    newDeviceID: 'ABCD1234',
    newDeviceName: 'Test',
    newToken: '1234',
    newUserID: '@test:fakeServer.notExisting',
  );
  addTearDown(client.dispose);
  return client;
}

Map<String, Object?> lastSentContent() => jsonDecode(
  FakeMatrixApi.calledEndpoints.entries
          .lastWhere((call) => call.key.contains('/send/m.room.message/'))
          .value
          .last
      as String,
);

void main() {
  group('Preview', () {
    late Room room;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      await AppSettings.init(loadWebConfigFile: false);
      room = await joinFixtureRoom(
        await fakeClient(convertLinebreaksInFormatting: false),
      );
    });

    Future<TextEditingController> pumpPreview(
      WidgetTester tester,
      String text,
    ) async {
      final controller = TextEditingController(text: text);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: Scaffold(
            body: ComposerPreview(room: room, controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return controller;
    }

    test('The preview is the formatted body that is sent', () async {
      await room.sendTextEvent(message, parseCommands: false);
      final html = lastSentContent()['formatted_body'] as String;
      expect(html, contains('data-mx-spoiler'));
      expect(html, contains('https://matrix.to/#/@alice:example.org'));
      expect(html, contains('<img data-mx-emoticon'));
      expect(room.previewHtml(message), html);
    });

    testWidgets('The preview renders the message', (tester) async {
      await pumpPreview(tester, withoutAvatars);
      final texts = tester
          .widgetList<RichText>(
            find.descendant(
              of: find.byType(ComposerPreview),
              matching: find.byType(RichText),
            ),
          )
          .map((text) => text.text.toPlainText())
          .join('\n');
      expect(texts, contains('final list = [1, 2];'));
      expect(texts, contains('• one'));
      expect(texts, contains('link'));
      expect(find.byType(Table), findsOneWidget);
      expect(find.bySemanticsLabel('Preview'), findsOneWidget);
    });

    testWidgets('Moving the caret does not render the preview again', (
      tester,
    ) async {
      final controller = await pumpPreview(tester, withoutAvatars);
      final before = tester.widget<HtmlMessage>(find.byType(HtmlMessage));
      controller.selection = const TextSelection.collapsed(offset: 4);
      await tester.pump();
      expect(tester.widget(find.byType(HtmlMessage)), same(before));
      controller.text = '$withoutAvatars!';
      await tester.pump();
      expect(tester.widget(find.byType(HtmlMessage)), isNot(same(before)));
    });

    testWidgets('Empty input shows an empty state', (tester) async {
      await pumpPreview(tester, ' ');
      expect(find.text('Nothing to preview yet.'), findsOneWidget);
    });

    testWidgets('Unfinished markdown still renders', (tester) async {
      final controller = await pumpPreview(tester, '');
      for (final text in ['```\nnever closed', '**bold', '| a |\n| -', '<b>']) {
        controller.text = text;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('Without HTML rendering the preview shows the plain text', (
      tester,
    ) async {
      await AppSettings.renderHtml.setItem(false);
      addTearDown(() => AppSettings.renderHtml.setItem(true));
      await pumpPreview(tester, '**<b>bold</b>**');
      expect(find.text('**<b>bold</b>**', findRichText: true), findsOneWidget);
    });
  });

  group('Chat page', () {
    late Client client;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const wakelock =
          'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle';
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMessageHandler(
        wakelock,
        (_) async =>
            const StandardMessageCodec().encodeMessage(<Object?>[null]),
      );
      addTearDown(() => messenger.setMockMessageHandler(wakelock, null));
      SharedPreferences.setMockInitialValues({});
      FlutterLocalNotificationsPlatform.instance = _FakeNotifications();
      await AppSettings.init(loadWebConfigFile: false);
      await AppSettings.sendTypingNotifications.setItem(false);
      client = await fakeClient();
      client.backgroundSync = false;
      await joinFixtureRoom(client);
    });

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
      }
      await tester.pump(const Duration(seconds: 1));
    }

    Future<TextEditingController> openChat(
      WidgetTester tester,
      Size size,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        FluffyChatApp(
          clients: [client],
          store: await SharedPreferences.getInstance(),
          appLockSettings: (pincode: null, useBiometrics: false),
        ),
      );
      await tester.pump();
      FluffyChatApp.router.go('/rooms/$roomId');
      await settle(tester);
      final input = find.byKey(const Key('chat_input_field'));
      await tester.enterText(input, 'Hello **world**');
      await tester.pump();
      return tester
          .widget<EditableText>(
            find.descendant(of: input, matching: find.byType(EditableText)),
          )
          .controller;
    }

    Future<void> press(WidgetTester tester, Finder button) async {
      tester.widget<IconButton>(button).onPressed!();
      await settle(tester);
    }

    Future<void> closeChat(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 1));
    }

    for (final (layout, size, replacesInput) in [
      ('a phone', const Size(400, 800), true),
      ('a wide window', const Size(1400, 900), false),
    ]) {
      testWidgets('The preview toggle on $layout keeps text and caret', (
        tester,
      ) async {
        final controller = await openChat(tester, size);
        controller.selection = const TextSelection.collapsed(offset: 3);

        await press(
          tester,
          find.widgetWithIcon(IconButton, Icons.preview_outlined),
        );
        expect(find.byType(ComposerPreview), findsOneWidget);
        expect(
          find.byKey(const Key('chat_input_field')),
          replacesInput ? findsNothing : findsOneWidget,
        );

        await press(
          tester,
          find.widgetWithIcon(IconButton, Icons.edit_outlined),
        );
        expect(find.byType(ComposerPreview), findsNothing);
        expect(controller.text, 'Hello **world**');
        expect(controller.selection, const TextSelection.collapsed(offset: 3));
        await closeChat(tester);
      });
    }

    testWidgets('Sending with the preview open sends the message', (
      tester,
    ) async {
      await openChat(tester, const Size(400, 800));
      await press(
        tester,
        find.widgetWithIcon(IconButton, Icons.preview_outlined),
      );
      await press(tester, find.byKey(const Key('send_button')));
      expect(lastSentContent()['body'], 'Hello **world**');
      expect(find.text('Nothing to preview yet.'), findsOneWidget);
      await closeChat(tester);
    });

    testWidgets('The toggle only shows with text or an open preview', (
      tester,
    ) async {
      await openChat(tester, const Size(400, 800));
      expect(find.byIcon(Icons.preview_outlined), findsOneWidget);
      await tester.enterText(find.byKey(const Key('chat_input_field')), '');
      await settle(tester);
      expect(find.byIcon(Icons.preview_outlined), findsNothing);
      await closeChat(tester);
    });
  });
}
