import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/live/live_account.dart';
import 'package:iqly_mobile/data/live/live_notifications_service.dart';
import 'package:iqly_mobile/data/local/memory_local_store.dart';
import 'package:iqly_mobile/data/local/outbox.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/data/notifications_data.dart';

import '../../support/live_api.dart';

/// A feed row shaped as contract 7 sends it.
Map<String, Object?> feedRow(
  String id,
  String type, {
  String createdAt = '2026-10-17T08:00:00.000Z',
  String? readAt,
  String title = '',
  String body = '',
  Map<String, Object?> refs = const {},
  int? amountKobo,
  Map<String, Object?>? brief,
  Map<String, Object?>? withdrawal,
}) => {
  'id': id,
  'type': type,
  'createdAt': createdAt,
  'readAt': readAt,
  'title': title,
  'body': body,
  'refs': {
    'challengeId': null,
    'submissionId': null,
    'withdrawalId': null,
    'ledgerId': null,
    ...refs,
  },
  'amountKobo': amountKobo,
  'brief': brief,
  'withdrawal': withdrawal,
};

/// The contract's own example row.
final paidOutRow = feedRow(
  'n_1',
  'payout_completed',
  title: '₦10,000.00 paid out',
  body: 'Arrived at Access Bank ••6789.',
  refs: {'withdrawalId': 'w_1'},
  amountKobo: 1000000,
  withdrawal: {
    'id': 'w_1',
    'amountKobo': 1000000,
    'status': 'completed',
    'bankName': 'Access Bank',
    'accountLast4': '6789',
    'reference': 'IQ-WD-261016-AB12',
  },
);

Map<String, Object?> page(
  List<Map<String, Object?>> items, {
  String? next,
  int unseen = 0,
}) => {'items': items, 'nextCursor': next, 'unseen': unseen};

void main() {
  group('a feed row', () {
    test('payout_completed reports its withdrawal, from what it embeds', () {
      final note = notificationFromJson(paidOutRow)!;
      expect(note.event, NotificationEvent.paidOut);
      expect(note.entryId, 'w_1');
      expect(note.unread, isTrue);
      expect(note.at.toUtc(), DateTime.utc(2026, 10, 17, 8));
      final withdrawal = note.facts!.withdrawal!;
      expect(withdrawal.amountKobo, 1000000);
      expect(withdrawal.status, WithdrawalStatus.completed);
      expect(withdrawal.destination, 'Access Bank ••6789');
      expect(withdrawal.reference, 'IQ-WD-261016-AB12');
      expect(note.facts!.title, '₦10,000.00 paid out');
    });

    test('payout_confirmed is a win reporting its ledger credit', () {
      final note = notificationFromJson(
        feedRow(
          'n_2',
          'payout_confirmed',
          readAt: '2026-10-17T09:00:00.000Z',
          refs: {
            'challengeId': 'c_1',
            'submissionId': 's_1',
            'ledgerId': 't_1',
          },
          amountKobo: 1250000,
          brief: {
            'id': 'c_1',
            'title': 'Sunday is data day',
            'businessName': null,
            'logoUrl': null,
          },
        ),
      )!;
      expect(note.event, NotificationEvent.won);
      expect(note.entryId, 't_1');
      expect(note.briefId, 'c_1');
      expect(note.unread, isFalse);
      expect(note.facts!.amountKobo, 1250000);
      expect(note.facts!.submissionId, 's_1');
      expect(note.facts!.brief!.title, 'Sunday is data day');
      expect(note.facts!.brief!.businessName, isNull);
    });

    test('withdrawal_requested and payout_failed report the withdrawal', () {
      final requested = notificationFromJson(
        feedRow('n_3', 'withdrawal_requested', refs: {'withdrawalId': 'w_2'}),
      )!;
      expect(requested.event, NotificationEvent.withdrawalRequested);
      expect(requested.entryId, 'w_2');
      final failed = notificationFromJson(
        feedRow(
          'n_4',
          'payout_failed',
          withdrawal: {...?paidOutRow['withdrawal'] as Map?, 'status': 'odd'},
        ),
      )!;
      expect(failed.event, NotificationEvent.payoutFailed);
      expect(failed.entryId, 'w_1');
      expect(failed.facts!.withdrawal!.status, WithdrawalStatus.pending);
    });

    test('review_ready, deadline_extended and any other type keep the '
        'API\'s words; a row without an id or time is dropped', () {
      expect(
        notificationFromJson(feedRow('n_5', 'review_ready'))!.event,
        NotificationEvent.resultsReady,
      );
      expect(
        notificationFromJson(feedRow('n_6', 'deadline_extended'))!.event,
        NotificationEvent.deadlineExtended,
      );
      final odd = notificationFromJson(
        feedRow('n_7', 'referral_joined', title: 'Tobi joined', body: 'Hi'),
      )!;
      expect(odd.event, NotificationEvent.other);
      expect((odd.facts!.title, odd.facts!.body), ('Tobi joined', 'Hi'));
      expect(notificationFromJson({...paidOutRow, 'id': null}), isNull);
      expect(notificationFromJson({...paidOutRow, 'createdAt': 'x'}), isNull);
    });
  });

  group('the feed', () {
    late FakeApi api;
    late MemoryLocalStore store;
    late Outbox outbox;
    late LiveNotificationsService service;

    setUp(() {
      api = FakeApi();
      store = MemoryLocalStore();
      outbox = Outbox(store);
      registerAccountWrites(outbox, api.client, store);
      service = LiveNotificationsService(
        AccountLink(
          api: api.client,
          store: store,
          outbox: outbox,
          userId: () => 'u_1',
        ),
      );
    });

    Map<String, Object?> row(int i) => feedRow(
      'n_$i',
      'review_ready',
      createdAt: DateTime.utc(
        2026,
        10,
        17,
        9,
      ).subtract(Duration(minutes: i)).toIso8601String(),
    );

    test('loads every page until the API has no more', () async {
      api.routes['GET /notifications'] = (call) =>
          call.url.queryParameters['cursor'] == null
          ? answer(page([row(1), row(2)], next: 'p2', unseen: 3))
          : answer(page([row(3)], unseen: 3));
      final feed = await service.notifications();
      expect([for (final n in feed) n.id], ['n_1', 'n_2', 'n_3']);
      expect(api.to('GET /notifications'), hasLength(2));
      expect(api.to('GET /notifications').last.url.queryParameters, {
        'limit': '98',
        'cursor': 'p2',
      });
    });

    test('stops at 100 rows', () async {
      var served = 0;
      api.routes['GET /notifications'] = (call) {
        final limit = int.parse(call.url.queryParameters['limit']!);
        final rows = [
          for (var i = 0; i < limit.clamp(0, 60); i++) row(served++),
        ];
        return answer(page(rows, next: 'more'));
      };
      final feed = await service.notifications();
      expect(feed, hasLength(LiveNotificationsService.cap));
      expect(
        [
          for (final call in api.to('GET /notifications'))
            call.url.queryParameters['limit'],
        ],
        ['100', '40'],
      );
    });

    test('keeps the feed for a read without a connection', () async {
      api.routes['GET /notifications'] = (_) =>
          answer(page([paidOutRow], unseen: 1));
      await service.notifications();
      api.offline = true;
      expect([for (final n in await service.notifications()) n.id], ['n_1']);
      expect(await service.unseen(), 1);
    });

    test('the bell reads unseen, and a seen mark still to go clears what it '
        'covers at once', () async {
      api.routes['GET /notifications'] = (_) =>
          answer(page([row(1), row(2)], unseen: 2));
      expect(await service.unseen(), 2);
      await service.notifications();
      api.offline = true;
      await service.markSeen();
      api.offline = false;
      expect(await service.unseen(), 0);

      final mark = (await store.outbox('u_1')).single;
      expect(mark.kind, AccountWrite.seen.kind);
      expect(mark.coalesceKey, 'notif:seen');
      expect(mark.payload, {'until': '2026-10-17T08:59:00.000Z'});
    });

    test('a later seen mark replaces one still waiting, never an earlier '
        'one', () async {
      api.offline = true;
      final link = service.link;
      await link.queue(AccountWrite.seen, {
        'until': '2026-10-17T09:00:00.000Z',
      });
      api.routes['GET /notifications'] = (_) =>
          answer(page([row(30)], unseen: 1));
      api.offline = false;
      await service.notifications();
      api.offline = true;
      await service.markSeen();
      expect((await store.outbox('u_1')).single.payload, {
        'until': '2026-10-17T09:00:00.000Z',
      });
    });

    test('read marks fold into one with every id, and read rows stay read '
        'until the API has them', () async {
      api.routes['GET /notifications'] = (_) =>
          answer(page([row(1), row(2), row(3)], unseen: 3));
      api.routes['POST /notifications/read'] = (call) => answer({'read': 2});
      api.offline = true;
      await service.markRead('n_1');
      await service.markRead('n_3');
      await service.markRead('n_1');
      final mark = (await store.outbox('u_1')).single;
      expect(mark.coalesceKey, 'notif:read');
      expect(mark.payload, {
        'ids': ['n_1', 'n_3'],
      });
      api.offline = false;
      final feed = await service.notifications();
      expect([for (final n in feed) n.unread], [false, true, false]);

      await outbox.start('u_1');
      expect(api.to('POST /notifications/read').single.body, {
        'ids': ['n_1', 'n_3'],
      });
    });

    test('a refusal leaves the feed failing, to Try again', () async {
      api.routes['GET /notifications'] = (_) => refusal(500, 'HTTP_ERROR');
      await expectLater(service.notifications(), throwsA(isA<ApiRefused>()));
      api.offline = true;
      await expectLater(
        service.notifications(),
        throwsA(isA<ApiUnreachable>()),
      );
    });
  });
}
