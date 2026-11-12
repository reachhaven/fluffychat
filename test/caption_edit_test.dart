// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026 vDL Digital Ventures
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/pages/chat/chat.dart';
import 'package:fluffychat/utils/file_description.dart';
import 'package:fluffychat/widgets/fluffy_chat_app.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const roomId = '!1234:fakeServer.notExisting';

class _FakeNotifications extends FlutterLocalNotificationsPlatform {}

const picture = {
  'msgtype': MessageTypes.Image,
  'body': 'Look at this',
  'filename': 'beach.jpg',
  'url': 'mxc://example.org/beach',
  'info': {'mimetype': 'image/jpeg', 'w': 800, 'h': 600},
  'm.relates_to': {'rel_type': 'm.thread', 'event_id': '\$root'},
  'm.mentions': {
    'user_ids': ['@alice:example.org'],
  },
};

Future<Client> fakeClient() async {
  final client = Client(
    'FluffyChat Test',
    httpClient: FakeMatrixApi(),
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
  group('Caption', () {
    late Room room;

    setUpAll(() async {
      room = Room(id: roomId, client: await fakeClient());
    });

    Event event(
      Map<String, Object?> content, {
      String type = EventTypes.Message,
    }) => Event.fromJson({
      'type': type,
      'event_id': '\$image',
      'sender': '@test:fakeServer.notExisting',
      'origin_server_ts': 0,
      'content': content,
    }, room);

    test('An edit starts with the body of a text message', () {
      final text = event({'msgtype': MessageTypes.Text, 'body': 'Hello'});
      expect(text.isFileMessage, isFalse);
      expect(text.editableText(MatrixDefaultLocalizations()), 'Hello');
    });

    test('An edit starts with the caption of a media message', () {
      expect(event(picture).isFileMessage, isTrue);
      expect(
        event(picture).editableText(MatrixDefaultLocalizations()),
        'Look at this',
      );
      final uncaptioned = event({
        'msgtype': MessageTypes.Image,
        'body': 'beach.jpg',
        'url': 'mxc://example.org/beach',
      });
      expect(uncaptioned.editableText(MatrixDefaultLocalizations()), isEmpty);
      final formatted = event({
        ...picture,
        'body': 'See docs at https://example.org',
        'format': 'org.matrix.custom.html',
        'formatted_body': 'See <a href="https://example.org">docs</a>',
      });
      expect(
        formatted.editableText(MatrixDefaultLocalizations()),
        'See docs at https://example.org',
      );
    });

    test('A sticker is not a media message with a caption', () {
      final sticker = event({
        'body': 'A waving cat',
        'url': 'mxc://example.org/cat',
        'info': {'mimetype': 'image/png'},
      }, type: EventTypes.Sticker);
      expect(sticker.isFileMessage, isFalse);
    });

    test('A new caption keeps the file', () {
      final content = event(picture).contentWithFileDescription(' Sunset ');
      expect(content['msgtype'], MessageTypes.Image);
      expect(content['url'], 'mxc://example.org/beach');
      expect(content['info'], picture['info']);
      expect(content['filename'], 'beach.jpg');
      expect(content['body'], 'Sunset');
      expect(content.containsKey('m.relates_to'), isFalse);
      expect(content['m.mentions'], isEmpty);
      expect(event(content).fileDescription, 'Sunset');
    });

    test('An empty caption removes the caption but keeps the file', () {
      final content = event(picture).contentWithFileDescription(' ');
      expect(content['body'], 'beach.jpg');
      expect(content['url'], 'mxc://example.org/beach');
      expect(event(content).fileDescription, isNull);
    });

    test('A file without a filename field keeps its name', () {
      final content = event({
        'msgtype': MessageTypes.File,
        'body': 'report.pdf',
        'url': 'mxc://example.org/report',
      }).contentWithFileDescription('Q3 numbers');
      expect(content['filename'], 'report.pdf');
      expect(content['body'], 'Q3 numbers');
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
      MatrixEvent message(String id, String type, Map<String, Object?> c) =>
          MatrixEvent(
            type: type,
            content: c,
            senderId: client.userID!,
            eventId: id,
            originServerTs: DateTime.now(),
          );
      await client.handleSync(
        SyncUpdate(
          nextBatch: '',
          rooms: RoomsUpdate(
            join: {
              roomId: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  events: [
                    message('\$file', EventTypes.Message, {
                      'msgtype': MessageTypes.File,
                      'body': 'Look at this',
                      'filename': 'report.pdf',
                      'url': 'mxc://example.org/report',
                    }),
                    message('\$sticker', EventTypes.Sticker, {
                      'body': 'A waving cat',
                      'url': 'mxc://example.org/cat',
                      'info': {'mimetype': 'image/png'},
                    }),
                  ],
                ),
              ),
            },
          ),
        ),
      );
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

    testWidgets('Editing the caption of a file keeps the file', (tester) async {
      client.userDeviceKeys.clear();
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

      final chat = tester.state<ChatController>(find.byType(ChatPageWithRoom));
      for (var i = 0; i < 50 && chat.timeline == null; i++) {
        await settle(tester);
      }
      final room = client.getRoomById(roomId)!;
      final sticker = await tester.runAsync(
        () => room.getEventById('\$sticker'),
      );
      final file = await tester.runAsync(() => room.getEventById('\$file'));
      chat.selectedEvents
        ..clear()
        ..add(sticker!);
      expect(chat.canEditSelectedEvents, isFalse);

      chat.selectedEvents
        ..clear()
        ..add(file!);
      expect(chat.canEditSelectedEvents, isTrue);
      chat.editSelectedEventAction();
      await settle(tester);
      expect(chat.sendController.text, 'Look at this');

      chat.sendController.text = '';
      tester
          .widget<IconButton>(find.byKey(const Key('send_button')))
          .onPressed!();
      await settle(tester);
      final sent = lastSentContent();
      expect(sent['m.relates_to'], {
        'event_id': '\$file',
        'rel_type': RelationshipTypes.edit,
      });
      final newContent = sent['m.new_content'] as Map<String, Object?>;
      expect(newContent['msgtype'], MessageTypes.File);
      expect(newContent['url'], 'mxc://example.org/report');
      expect(newContent['body'], 'report.pdf');
      expect(newContent['m.mentions'], isEmpty);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 1));
    });
  });
}
