import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/live/live_account.dart';
import 'package:iqly_mobile/data/live/live_outcomes_service.dart';
import 'package:iqly_mobile/data/local/memory_local_store.dart';
import 'package:iqly_mobile/data/local/outbox.dart';

import '../../support/live_api.dart';

/// `GET /submissions/:id/outcome` (contract 5), with the person in second.
Map<String, Object?> outcomeJson() => {
  'submissionId': 's_1',
  'challengeId': 'c_1',
  'link': 'https://iqly.net/challenges/sunday-data',
  'resultsPublishedAt': '2026-10-16T12:00:00.000Z',
  'entries': 412,
  'rank': 2,
  'leaders': [
    {'rank': 1, 'name': 'Tobi A.', 'amountKobo': 5000000, 'you': false},
    {'rank': 2, 'name': 'Ada O.', 'amountKobo': 2500000, 'you': true},
    {'rank': 3, 'name': null, 'amountKobo': 1000000, 'you': false},
  ],
  'note': null,
};

void main() {
  test('maps the outcome: the winners without entry titles, the person\'s '
      'own row left to the screen, no note', () {
    final outcome = outcomeFromJson(outcomeJson(), 's_1');
    expect(outcome.submissionId, 's_1');
    expect(outcome.link, 'https://iqly.net/challenges/sunday-data');
    expect(outcome.entries, 412);
    expect(outcome.rank, 2);
    expect(outcome.hasLeaderboard, isTrue);
    expect(outcome.note, isNull);
    expect(
      [
        for (final l in outcome.leaders)
          (l.rank, l.name, l.entry, l.amountKobo),
      ],
      [(1, 'Tobi A.', '', 5000000), (3, 'Anonymous', '', 1000000)],
    );
  });

  test('before the winners are out there is no board', () {
    final outcome = outcomeFromJson({
      ...outcomeJson(),
      'resultsPublishedAt': null,
      'rank': null,
      'leaders': <Object>[],
    }, 's_1');
    expect(outcome.hasLeaderboard, isFalse);
    expect(outcome.leaders, isEmpty);
  });

  group('outcome', () {
    late FakeApi api;
    late LiveOutcomesService service;

    setUp(() {
      api = FakeApi({
        'GET /submissions/s_1/outcome': (_) => answer(outcomeJson()),
      });
      final store = MemoryLocalStore();
      service = LiveOutcomesService(
        AccountLink(
          api: api.client,
          store: store,
          outbox: Outbox(store),
          userId: () => 'u_1',
        ),
      );
    });

    test('reads the API and keeps it for a read offline', () async {
      expect((await service.outcome('s_1'))!.rank, 2);
      api.offline = true;
      expect((await service.outcome('s_1'))!.entries, 412);
      await expectLater(service.outcome('s_2'), throwsA(isA<ApiUnreachable>()));
    });

    test('unknown to the API or not the person\'s own is no outcome', () async {
      expect(await service.outcome('s_9'), isNull);
      api.routes['GET /submissions/s_8/outcome'] = (_) =>
          refusal(403, 'FORBIDDEN');
      expect(await service.outcome('s_8'), isNull);
    });
  });
}
