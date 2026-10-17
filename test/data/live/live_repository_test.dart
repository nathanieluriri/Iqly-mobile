import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/backend.dart';
import 'package:iqly_mobile/core/deadline.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/drafts_data.dart';
import 'package:iqly_mobile/data/live/live_repository.dart';
import 'package:iqly_mobile/data/local/local_providers.dart';
import 'package:iqly_mobile/data/local/local_store.dart';
import 'package:iqly_mobile/data/local/memory_local_store.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/local_stores.dart';
import 'live_data_fixtures.dart';

Future<void> main() async {
  final sqlite = await sqliteMissing();
  late FakeApi api;
  late TestClock clock;
  late MemoryLocalStore store;
  late DemoRepository demo;

  setUp(() {
    api = FakeApi();
    clock = TestClock();
    store = MemoryLocalStore(clock: clock.call);
    demo = DemoRepository(DemoData(now: clock.now));
  });

  LiveRepository repository({
    Backend? mode,
    String? userId = 'u_1',
    String? name,
  }) => LiveRepository(
    api: api.api(),
    store: store,
    mode: mode ?? allLive,
    demo: demo,
    userId: userId,
    name: () => name,
    clock: clock.call,
  );

  /// Three pages of briefs: 60, 60, then 5.
  void browse({int pages = 3}) => api.on('GET', '/challenges/browse', (r) {
    final page = int.parse(r.url.queryParameters['page']!);
    final count = page < pages ? 60 : 5;
    return ok({
      'items': [
        for (var i = 0; i < count; i++) challengeJson({'id': 'c_${page}_$i'}),
      ],
      'total': (pages - 1) * 60 + 5,
      'pageCount': pages,
      'page': page,
      'perPage': 60,
    });
  });

  group('briefs', () {
    test('pages through every live brief, 60 at a time', () async {
      browse();
      final briefs = await repository().briefs(load: BriefsLoad.feed);
      expect(briefs, hasLength(125));
      expect(briefs.first.id, 'c_1_0');
      expect(briefs.last.id, 'c_3_4');
      expect(
        [for (final r in api.to('/challenges/browse')) r.url.query],
        [
          'status=live&perPage=60&page=1',
          'status=live&perPage=60&page=2',
          'status=live&perPage=60&page=3',
        ],
      );
    });

    test('a single page stops at its page count', () async {
      browse(pages: 1);
      expect(await repository().briefs(), hasLength(5));
      expect(api.to('/challenges/browse'), hasLength(1));
    });

    test(
      'offline, Discover opens on the last copy kept for the person',
      () async {
        browse(pages: 1);
        await repository().briefs(load: BriefsLoad.feed);
        final kept = await store.readCache('u_1', LiveCacheKeys.briefs);
        expect(kept!.json, hasLength(5));

        api.offline = true;
        final relaunched = repository();
        expect(await relaunched.briefs(load: BriefsLoad.feed), hasLength(5));
        await expectLater(
          relaunched.briefs(load: BriefsLoad.refresh),
          throwsA(isA<ApiUnreachable>()),
          reason: 'pull to refresh skips the cache and keeps what is shown',
        );
        await expectLater(
          repository(userId: 'u_2').briefs(load: BriefsLoad.feed),
          throwsA(isA<ApiUnreachable>()),
          reason: 'another person has no copy',
        );
      },
    );

    test('without a user id it reads the network and keeps nothing', () async {
      browse(pages: 1);
      expect(await repository(userId: null).briefs(), hasLength(5));
      expect(await store.readCache('u_1', LiveCacheKeys.briefs), isNull);
    });

    test('joins and the next page answer from what the feed loaded', () async {
      browse(pages: 1);
      final repo = repository();
      await repo.briefs(load: BriefsLoad.feed);
      await repo.briefs();
      await repo.briefs(load: BriefsLoad.nextPage);
      expect(api.to('/challenges/browse'), hasLength(1));
      await repo.briefs(load: BriefsLoad.refresh);
      expect(api.to('/challenges/browse'), hasLength(2));
    });

    test('loads at the same time share one fetch', () async {
      browse(pages: 1);
      final repo = repository();
      await Future.wait([
        repo.briefs(load: BriefsLoad.feed),
        repo.briefs(),
        repo.briefs(),
      ]);
      expect(api.to('/challenges/browse'), hasLength(1));
    });

    test('a definite refusal fails, whatever is kept', () async {
      browse(pages: 1);
      await repository().briefs();
      api.on('GET', '/challenges/browse', (_) => refused(403, 'FORBIDDEN'));
      await expectLater(
        repository().briefs(load: BriefsLoad.feed),
        throwsA(isA<ApiRefused>()),
      );
    });

    test('a fault or a throttle answers what is kept', () async {
      browse(pages: 1);
      await repository().briefs();
      for (final status in [500, 503, 429, 408]) {
        api.on('GET', '/challenges/browse', (_) => refused(status, 'NO'));
        expect(
          await repository().briefs(load: BriefsLoad.feed),
          hasLength(5),
          reason: '$status',
        );
      }
    });

    test('the briefs the phone holds, without asking', () async {
      browse(pages: 1);
      await repository().briefs();
      final before = api.requests.length;
      expect(await repository().keptBriefs(), hasLength(5));
      expect(await repository(userId: 'u_2').keptBriefs(), isEmpty);
      expect(api.requests, hasLength(before));
    });

    test('one brief from the API; offline from the kept list', () async {
      api.data('GET', '/challenges/c_1', challengeJson());
      final repo = repository();
      expect((await repo.brief('c_1'))!.title, 'Make Sunday data day');
      expect(await repo.brief('gone'), isNull, reason: '404');

      browse(pages: 1);
      await repo.briefs();
      api.offline = true;
      expect((await repository().brief('c_1_2'))!.id, 'c_1_2');
      expect(await repository().brief('c_1'), isNull);
    });
  });

  group('submissions', () {
    test('every page, with the embedded briefs and awards', () async {
      api.on('GET', '/submissions/mine', (r) {
        final cursor = r.url.queryParameters['cursor'];
        expect(r.url.queryParameters['limit'], '100');
        return ok(switch (cursor) {
          null => page([submissionJson()], 'cur_2'),
          'cur_2' => page([
            submissionJson({'id': 's_2', 'result': 'not_selected'}),
          ], 'cur_3'),
          _ => page([
            submissionJson({'id': 's_3', 'result': 'under_review'}),
          ]),
        });
      });
      final submissions = await repository().submissions();
      expect([for (final s in submissions) s.id], ['s_1', 's_2', 's_3']);
      expect(submissions.first.brief!.status, BriefStatus.closed);
      expect(submissions.first.award!.amountKobo, 1250000);
      expect(api.to('/submissions/mine'), hasLength(3));

      api.offline = true;
      final kept = await repository().submissions();
      expect([for (final s in kept) s.id], ['s_1', 's_2', 's_3']);
      expect(kept.first.brief!.title, 'Why do people stop saving?');
    });

    test(
      'reads at the same time share one fetch; later ones ask again',
      () async {
        api.data('GET', '/submissions/mine', page([submissionJson()]));
        final repo = repository();
        final [first, second] = await Future.wait([
          repo.submissions(),
          repo.submissions(),
        ]);
        expect(first.single.id, 's_1');
        expect(second.single.id, 's_1');
        expect(api.to('/submissions/mine'), hasLength(1));
        await repo.submissions();
        expect(api.to('/submissions/mine'), hasLength(2));
      },
    );

    test('a cursor that comes back again ends the paging', () async {
      api.data('GET', '/submissions/mine', page([submissionJson()], 'same'));
      expect(await repository().submissions(), hasLength(2));
      expect(api.to('/submissions/mine'), hasLength(2));
    });
  });

  group('wallet', () {
    test('ledger and withdrawals page through and are kept', () async {
      api.on('GET', '/wallet/transactions', (r) {
        final first = r.url.queryParameters['cursor'] == null;
        return ok(
          first
              ? page([transactionJson()], 'next')
              : page([
                  transactionJson({
                    'id': 't_2',
                    'amount': -1000000,
                    'type': 'withdrawal',
                    'submissionId': null,
                  }),
                ]),
        );
      });
      api.data('GET', '/wallet/withdrawals', page([withdrawalJson()]));
      final repo = repository();
      expect(
        [for (final l in await repo.ledger()) l.amountKobo],
        [1250000, -1000000],
      );
      expect(
        (await repo.withdrawals()).single.destination,
        'Access Bank ••6789',
      );

      api.offline = true;
      expect(await repository().ledger(), hasLength(2));
      expect(await repository().withdrawals(), hasLength(1));
      await expectLater(
        repository().ledger(allowCache: false),
        throwsA(isA<ApiUnreachable>()),
      );
    });

    test('totals come from GET /wallet', () async {
      api.data('GET', '/wallet', walletJson());
      final totals = (await repository().walletTotals())!;
      expect(totals.totalEarnedKobo, 6500000);
      expect(totals.pendingWithdrawalsKobo, 1000000);
      expect(totals.withdrawableKobo, 1500000);
      await expectLater(
        repository(mode: Backend.of({LiveFeature.briefs})).walletTotals(),
        throwsA(isA<FeaturePaused>()),
        reason: 'a paused wallet has no figures, the demo\'s least of all',
      );
    });

    test('the payout account is one account or none', () async {
      api.data('GET', '/wallet/bank-account', bankAccountJson());
      final repo = repository();
      expect((await repo.savedBank())!.label, 'Access Bank ••6789');
      expect(await repo.savedBanks(), hasLength(1));
      api.data('GET', '/wallet/bank-account', null);
      expect(await repo.savedBank(), isNull);
      expect(await repo.savedBanks(), isEmpty);
    });

    test('banks are asked for once a day', () async {
      api.data('GET', '/banks', banksJson);
      final repo = repository();
      expect(
        [for (final b in await repo.banks()) b.name],
        ['Access Bank', 'Guaranty Trust Bank'],
      );
      expect(api.to('/banks').single.url.query, 'currency=NGN');
      clock.advance(const Duration(hours: 23));
      await repo.banks();
      expect(api.to('/banks'), hasLength(1));
      clock.advance(const Duration(hours: 2));
      await repo.banks();
      expect(api.to('/banks'), hasLength(2));
      clock.advance(const Duration(days: 3));
      api.offline = true;
      expect(await repo.banks(), hasLength(2), reason: 'an old copy offline');
    });
  });

  group('features a live launch pauses fail; none answers the demo', () {
    Matcher paused(LiveFeature feature) => throwsA(
      isA<FeaturePaused>().having((e) => e.feature, 'feature', feature),
    );

    test('briefs live, the wallet and submissions paused', () async {
      browse(pages: 1);
      final repo = repository(mode: Backend.of({LiveFeature.briefs}));
      expect(await repo.briefs(), hasLength(5));
      await expectLater(repo.submissions(), paused(LiveFeature.submissions));
      await expectLater(repo.ledger(), paused(LiveFeature.wallet));
      await expectLater(repo.withdrawals(), paused(LiveFeature.withdrawals));
      await expectLater(repo.banks(), paused(LiveFeature.wallet));
      await expectLater(repo.savedBank(), paused(LiveFeature.wallet));
      await expectLater(repo.savedBanks(), paused(LiveFeature.wallet));
      expect(await repo.drafts(), isEmpty, reason: 'none of the demo\'s');
      expect(api.requests.map((r) => r.url.path).toSet(), {
        '/challenges/browse',
      });
    });

    test('the wallet live, withdrawals and briefs paused', () async {
      api.data('GET', '/wallet/transactions', page([transactionJson()]));
      final repo = repository(
        mode: Backend.of({LiveFeature.profile, LiveFeature.wallet}),
      );
      expect(await repo.ledger(), hasLength(1));
      await expectLater(repo.withdrawals(), paused(LiveFeature.withdrawals));
      await expectLater(repo.briefs(), paused(LiveFeature.briefs));
      await expectLater(repo.brief('c1'), paused(LiveFeature.briefs));
      await expectLater(repo.keptBriefs(), paused(LiveFeature.briefs));
      expect(api.to('/wallet/withdrawals'), isEmpty);
      expect(api.to('/challenges/browse'), isEmpty);
    });

    test('activations stay preview; points and the board without the '
        'leaderboard, the bell and the user are never the demo\'s', () async {
      final repo = repository(name: 'Ada Obi');
      await expectLater(repo.points(), paused(LiveFeature.leaderboard));
      await expectLater(
        repo.pointsLeaderboard(),
        paused(LiveFeature.leaderboard),
      );
      expect(await repo.activationsSummary(), same(DemoData.activations));
      expect(await repo.unreadNotifications(), 0);
      final user = await repo.user();
      expect(user.name, 'Ada Obi');
      expect(user.email, isEmpty);
      expect(user.state, isEmpty);
      expect(user.interests, isEmpty);
      expect((await repository().user()).firstName, isEmpty);
      expect(api.requests, isEmpty);
    });

    test(
      'saved briefs and close reminders seed nothing in live mode',
      () async {
        final repo = repository(mode: Backend.of({LiveFeature.profile}));
        expect(await repo.savedBriefIds(), isEmpty);
        expect(await repo.closeReminderIds(), isEmpty);
        await repo.setBriefSaved('c1', true);
        await repo.setCloseReminder('c1', true);
        expect(await demo.savedBriefIds(), DemoData.savedBriefIds);
        expect(api.requests, isEmpty);
      },
    );
  });

  group('drafts', () {
    final draft = Draft(
      briefId: 'c_1',
      title: 'Sunday is data day',
      answer: 'Give a bonus bundle on Sundays.',
      answers: const {
        'q_lang': ['Pidgin'],
      },
      step: 2,
      editedAt: DateTime(2026, 10, 17, 9),
    );

    test('live drafts survive a restart, for their person only', () async {
      await repository().saveDraft(draft);
      final relaunched = repository();
      final [kept] = await relaunched.drafts();
      expect(kept.briefId, 'c_1');
      expect(kept.title, 'Sunday is data day');
      expect(kept.answers, {
        'q_lang': ['Pidgin'],
      });
      expect(kept.step, 2);
      expect(await repository(userId: 'u_2').drafts(), isEmpty);
      expect(demo.data.drafts.any((d) => d.briefId == 'c_1'), isFalse);

      await relaunched.discardDrafts(['c_1']);
      expect(await repository().drafts(), isEmpty);
    });

    test('live drafts outlast closing the SQLite store', () async {
      final path = storeFile();
      final first = await openFileStore(clock, path: path);
      LiveRepository on(LocalStore store) => LiveRepository(
        api: api.api(),
        store: store,
        mode: allLive,
        demo: demo,
        userId: 'u_1',
        clock: clock.call,
      );
      await on(first).saveDraft(draft);
      await first.close();
      final reopened = await openFileStore(clock, path: path);
      final [kept] = await on(reopened).drafts();
      expect(kept.title, 'Sunday is data day');
      expect(kept.editedAt, draft.editedAt);
    }, skip: sqlite);

    test('without a user id nothing is kept', () async {
      final repo = repository(userId: null);
      await repo.saveDraft(draft);
      expect(await repo.drafts(), isEmpty);
      expect(await store.drafts('u_1'), isEmpty);
    });

    test('a paused submit keeps the person\'s drafts on the phone, never '
        'in the demo', () async {
      final repo = repository(mode: Backend.of({LiveFeature.briefs}));
      await repo.saveDraft(draft);
      expect(await store.drafts('u_1'), hasLength(1));
      expect(demo.data.drafts.any((d) => d.briefId == 'c_1'), isFalse);
      expect([for (final d in await repo.drafts()) d.briefId], ['c_1']);
    });
  });

  group('the provider', () {
    Future<ProviderContainer> container(List<Override> overrides) async {
      SharedPreferences.setMockInitialValues({'session.userId': 'u_1'});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          localStoreProvider.overrideWithValue(store),
          clockProvider.overrideWithValue(clock.call),
          ...overrides,
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('preview reads the demo at prototype pace', () async {
      final c = await container([]);
      final repo = c.read(repositoryProvider);
      expect(repo, same(c.read(demoRepositoryProvider)));
      expect((repo as DemoRepository).latency, same(DemoLatency.prototype));
      expect(c.read(liveModeProvider).isPreview, isTrue);
    });

    test('a live launch reads the API for its live features', () async {
      final c = await container(
        liveOverrides(api.api(), mode: Backend.of({LiveFeature.briefs})),
      );
      final repo = c.read(repositoryProvider) as LiveRepository;
      expect(repo.userId, 'u_1');
      expect(repo.mode.isLive(LiveFeature.briefs), isTrue);
      expect(repo.demo, same(c.read(demoRepositoryProvider)));
      browse(pages: 1);
      expect(await repo.briefs(), hasLength(5));
    });

    test('a build without an API client stays on the demo', () async {
      final c = await container([
        backendProvider.overrideWith(() => FixedBackend(allLive)),
      ]);
      expect(c.read(repositoryProvider), isA<DemoRepository>());
      expect(c.read(liveModeProvider).isPreview, isTrue);
    });

    test('a new person gets a new repository', () async {
      final c = await container(liveOverrides(api.api()));
      final first = c.read(repositoryProvider);
      await c.read(sessionProvider.notifier).setUserId('u_2');
      final second = c.read(repositoryProvider) as LiveRepository;
      expect(second, isNot(same(first)));
      expect(second.userId, 'u_2');
    });
  });
}
