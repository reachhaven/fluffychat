// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026 vDL Digital Ventures
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat/events/message_content.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/double_escaped_code_extension.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as parser;
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
    room = Room(id: '!1234:fakeServer.notExisting', client: client);
  });

  Future<Map<String, Object?>> sendRaw(String body) async {
    await room.sendTextEvent(body, parseCommands: false);
    final request = FakeMatrixApi.calledEndpoints.entries
        .lastWhere((call) => call.key.contains('/send/m.room.message/'))
        .value
        .last;
    return jsonDecode(request as String) as Map<String, Object?>;
  }

  Future<String> send(String body) async {
    final content = await sendRaw(body);
    return (content['formatted_body'] as String).unescapeDoubleEscapedCode(
      content['body'] as String,
    );
  }

  List<String> codeTexts(String html) => parser
      .parseFragment(html)
      .querySelectorAll('code')
      .map((code) => code.text)
      .toList();

  test('Multi-line code blocks show < and > as typed (issue 3615)', () async {
    expect(codeTexts(await send('```\n<>\n```')), ['<>\n']);
    expect(
      codeTexts(
        await send('```dart\nList<String> a = <String>[];\nif (a > b) {}\n```'),
      ),
      ['List<String> a = <String>[];\nif (a > b) {}\n'],
    );
  });

  test('Inline code shows < and > as typed', () async {
    expect(codeTexts(await send('Use `<br>` or `Map<String, int>`')), [
      '<br>',
      'Map<String, int>',
    ]);
  });

  test('Entities the sender typed in code stay as typed', () async {
    expect(codeTexts(await send('```\n&lt;tag&gt; means <tag>\n```')), [
      '&lt;tag&gt; means <tag>\n',
    ]);
    expect(codeTexts(await send('a < b and `&lt;` c >')), ['&lt;']);
    expect(codeTexts(await send('<a>\n```\n&lt;a&gt;\n```')), ['&lt;a&gt;\n']);
    expect(
      codeTexts(await send('Type `<br>` and it is sent as `&lt;br&gt;`')),
      ['<br>', '&lt;br&gt;'],
    );
  });

  test('Nothing after a code element that is not found is changed', () async {
    final html = await send(
      '1. Write:\n   ```md\n   Type `<br>` here\n   and here\n   ```\n'
      '2. It is sent as `&lt;br&gt;`',
    );
    expect(codeTexts(html).last, '&lt;br&gt;');
  });

  test('Long runs of backticks or tildes are scanned in linear time', () {
    final cases = {
      '`<a>` ${'`' * 200000}':
          '<code>&amp;lt;a&amp;gt;</code><code>&amp;lt;b</code>',
      '```\n<a>\n```\n${'~' * 200000}\n':
          '<pre><code>&amp;lt;a&amp;gt;\n</code></pre>'
          '<pre><code>&amp;lt;b\n</code></pre>',
    };
    for (final MapEntry(key: body, value: html) in cases.entries) {
      expect(
        codeTexts(html.unescapeDoubleEscapedCode(body)).first,
        startsWith('<a>'),
      );
    }
  }, timeout: const Timeout(Duration(seconds: 10)));

  test('Text outside of code keeps its escaping', () async {
    final html = await send('<b> is text and `<b>` is code');
    expect(parser.parseFragment(html).text, '<b> is text and <b> is code');
  });

  test('Formatted bodies from other clients stay untouched', () {
    const html = '<pre><code>&lt;div&gt;\n</code></pre>';
    expect(html.unescapeDoubleEscapedCode('```\n<div>\n```'), html);
    const literal = '<code>&amp;lt;</code>';
    expect(literal.unescapeDoubleEscapedCode('`&lt;`'), literal);
  });

  testWidgets('The timeline shows the code as typed', (tester) async {
    final content = await tester.runAsync(() => sendRaw('```\n<>\n```'));
    final event = Event(
      content: content!,
      type: EventTypes.Message,
      eventId: '\$code',
      senderId: '@test:fakeServer.notExisting',
      originServerTs: DateTime.now(),
      room: room,
    );
    final timeline = (await tester.runAsync(room.getTimeline))!;
    addTearDown(timeline.cancelSubscriptions);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Scaffold(
          body: MessageContent(
            event,
            timeline: timeline,
            textColor: Colors.black,
            linkColor: Colors.blue,
            borderRadius: BorderRadius.zero,
            selected: false,
            bigEmojis: const {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('<>', findRichText: true), findsWidgets);
    expect(find.textContaining('&lt;', findRichText: true), findsNothing);
  });
}
