import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:iqly_mobile/data/help_data.dart';
import 'package:iqly_mobile/data/live/live_account.dart';
import 'package:iqly_mobile/data/live/live_help_service.dart';
import 'package:iqly_mobile/data/local/memory_local_store.dart';
import 'package:iqly_mobile/data/local/outbox.dart';
import 'package:iqly_mobile/data/support_files.dart';

import '../../support/live_api.dart';

class _NoFiles implements SupportFiles {
  @override
  Future<HelpAttachment?> pickAttachment(SupportSource source) async => null;

  @override
  Future<HelpAttachment?> pickScreenshot() async => null;
}

Map<String, Object?> _thread({bool unread = true, String body = 'Hi'}) => {
  'id': 't_1',
  'reference': 'IQ-HELP-2041',
  'channel': 'contributor_iqly',
  'subject': 'Payments',
  'topic': 'payments',
  'status': 'replied',
  'unread': unread,
  'updatedAt': '2026-10-19T09:00:00.000Z',
  'messages': [
    {
      'id': 'm_1',
      'author': 'you',
      'body': body,
      'at': '2026-10-19T08:00:00.000Z',
    },
  ],
};

http.Response _tagged(Object data, String tag) => http.Response.bytes(
  utf8.encode(jsonEncode({'success': true, 'data': data})),
  200,
  headers: {'content-type': 'application/json; charset=utf-8', 'etag': tag},
);

LiveHelpService _service(
  FakeApi api,
  MemoryLocalStore store, {
  bool etags = false,
}) => LiveHelpService(
  AccountLink(
    api: api.client,
    store: store,
    outbox: Outbox(store),
    userId: () => 'u_1',
    etags: etags,
  ),
  files: _NoFiles(),
);

void main() {
  test('a thread and the inbox the API answered are kept on the phone and '
      'read back, the thread read once it is opened', () async {
    final api = FakeApi({
      'GET /support/tickets/t_1': (_) => answer(_thread()),
      'GET /support/tickets': (_) => answer({
        'items': [
          {
            ..._thread(),
            'messages': null,
            'lastMessage': _thread()['messages'],
          },
        ],
        'nextCursor': null,
        'unread': 1,
      }),
      'POST /support/tickets/t_1/read': (_) => answer({'unread': 0}),
    });
    final store = MemoryLocalStore();
    final help = _service(api, store);
    expect(await help.keptThread('t_1'), isNull);
    expect(await help.keptConversations(), isNull);

    await help.watch('t_1').single;
    final kept = await help.keptThread('t_1');
    expect(kept!.subject, 'Payments');
    expect(kept.unread, isTrue);
    await help.markRead('t_1');
    expect((await help.keptThread('t_1'))!.unread, isFalse);

    await help.conversations();
    final inbox = await help.keptConversations();
    expect(inbox!.single.id, 't_1');
  });

  test('a reply and a resolve keep the thread they answer', () async {
    final api = FakeApi({
      'POST /support/tickets/t_1/messages': (_) =>
          answer(_thread(body: 'Thank you.')),
      'POST /support/tickets/t_1/resolve': (_) =>
          answer({..._thread(body: 'Thank you.'), 'status': 'resolved'}),
    });
    final store = MemoryLocalStore();
    final help = _service(api, store);
    await help.reply('t_1', 'Thank you.');
    expect((await help.keptThread('t_1'))!.messages.single.body, 'Thank you.');
    await help.resolve('t_1');
    expect((await help.keptThread('t_1'))!.status, HelpTicketStatus.resolved);
  });

  test('with etags live, a thread read sends its tag and a 304 answers the '
      'kept copy', () async {
    var reads = 0;
    final api = FakeApi({
      'GET /support/tickets/t_1': (call) {
        reads++;
        return call.headers['if-none-match'] == 'W/"t1"'
            ? http.Response('', 304, headers: {'etag': 'W/"t1"'})
            : _tagged(_thread(), 'W/"t1"');
      },
    });
    final store = MemoryLocalStore();
    final help = _service(api, store, etags: true);
    final first = await help.watch('t_1').single;
    final again = await help.watch('t_1').single;
    expect(reads, 2);
    expect(api.calls.first.headers['if-none-match'], isNull);
    expect(api.calls.last.headers['if-none-match'], 'W/"t1"');
    expect(again.messages.single.body, first.messages.single.body);
    expect(
      (await store.readCache('u_1', LiveHelpService.threadKey('t_1')))!.etag,
      'W/"t1"',
    );
  });

  test('without etags the read stays plain', () async {
    final api = FakeApi({
      'GET /support/tickets/t_1': (_) => _tagged(_thread(), 'W/"t1"'),
    });
    final help = _service(api, MemoryLocalStore());
    await help.watch('t_1').single;
    await help.watch('t_1').single;
    expect(
      api.calls.map((c) => c.headers['if-none-match']),
      everyElement(isNull),
    );
  });
}
