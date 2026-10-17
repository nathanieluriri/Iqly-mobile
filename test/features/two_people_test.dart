import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iqly_mobile/core/backend.dart';
import 'package:iqly_mobile/core/deadline.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/activations_service.dart';
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/auth.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/drafts_data.dart';
import 'package:iqly_mobile/data/live/live_account.dart';
import 'package:iqly_mobile/data/live_auth.dart';
import 'package:iqly_mobile/data/local/local_providers.dart';
import 'package:iqly_mobile/data/local/local_store.dart';
import 'package:iqly_mobile/data/local/memory_local_store.dart';
import 'package:iqly_mobile/data/onboarding_service.dart';
import 'package:iqly_mobile/data/profile_service.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/data/submit_data.dart';
import 'package:iqly_mobile/data/submit_service.dart';
import 'package:iqly_mobile/data/token_store.dart';
import 'package:iqly_mobile/features/avatar/avatar_state.dart';
import 'package:iqly_mobile/features/discover/discover_state.dart';
import 'package:iqly_mobile/features/drafts/drafts_state.dart';
import 'package:iqly_mobile/features/entry/entry_state.dart';
import 'package:iqly_mobile/features/notifications/notifications_state.dart';
import 'package:iqly_mobile/features/onboarding/onboarding_draft.dart';
import 'package:iqly_mobile/features/profile/account_sync.dart';
import 'package:iqly_mobile/features/profile/profile_state.dart';
import 'package:iqly_mobile/features/settings/settings_state.dart';
import 'package:iqly_mobile/features/splash/splash_screen.dart';
import 'package:iqly_mobile/features/submissions/submissions_state.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/live/live_data_fixtures.dart' as data;
import '../golden/screens/app_harness.dart';
import '../support/live_api.dart';
import '../support/live_app.dart';

const _brief = 'c_1';

String _ago(int hours) =>
    figmaNow.subtract(Duration(hours: hours)).toUtc().toIso8601String();

Map<String, Object?> _row(String id, String title, int hoursAgo) => {
  'id': id,
  'type': 'review_ready',
  'createdAt': _ago(hoursAgo),
  'readAt': null,
  'title': title,
  'body': 'Winners have been published.',
  'refs': {
    'challengeId': null,
    'submissionId': null,
    'withdrawalId': null,
    'ledgerId': null,
  },
  'amountKobo': null,
  'brief': null,
  'withdrawal': null,
};

/// One account on the API: what it holds and the token each sign-in hands
/// out.
class _Person {
  _Person(
    this.key,
    this.name, {
    required this.feed,
    required this.preferences,
    List<Map<String, Object?>>? entries,
    this.onboarded = true,
  }) : entries = entries ?? [];

  final String key;
  final String name;
  final List<Map<String, Object?>> feed;
  Map<String, Object?> preferences;
  final List<Map<String, Object?>> entries;
  bool onboarded;
  var signIns = 0;

  String get id => 'u_$key';
  String get email => '$key@example.com';
  String get token => 'tok.$key.$signIns';
}

/// The API for two people on one phone: every answer is the account's
/// whose token the request carries, and a token the API has ended answers
/// 401.
class _TwoPeopleApi {
  _TwoPeopleApi(this.people);

  final List<_Person> people;
  final tokens = MemoryTokenStore();
  final ended = <String>{};

  /// Each preference PUT the API took, `by` the account whose token it
  /// carried.
  final puts = <Map<String, Object?>>[];

  late final client = ApiClient(
    tokens: tokens,
    baseUrl: 'https://api.test',
    client: MockClient(_answer),
  );

  _Person person(String key) => people.firstWhere((p) => p.key == key);

  /// The API ends [key]'s session, as after a week idle.
  void end(String key) => ended.add(person(key).token);

  _Person? _of(http.Request request) {
    final bearer = request.headers['authorization'];
    for (final p in people) {
      if (bearer == 'Bearer ${p.token}' && !ended.contains(p.token)) return p;
    }
    return null;
  }

  Future<http.Response> _answer(http.Request request) async {
    final route = '${request.method} ${request.url.path}';
    final who = _of(request);
    if (route == 'POST /auth/web/sign-in/email') {
      final email = (jsonDecode(request.body) as Map)['email'];
      final p = people.firstWhere((p) => p.email == email);
      p.signIns++;
      return raw(
        {
          'token': p.token,
          'user': {'id': p.id, 'name': p.name, 'email': p.email},
        },
        headers: {'set-auth-token': p.token},
      );
    }
    if (route == 'POST /auth/web/sign-out') return raw({'success': true});
    if (who == null) return refusal(401, 'UNAUTHORIZED');
    switch (route) {
      case 'GET /auth/web/get-session':
        return raw({
          'user': {'id': who.id, 'name': who.name},
        });
      case 'GET /me':
        return answer({
          ...meJson(),
          'id': who.id,
          'name': who.name,
          'email': who.email,
        });
      case 'GET /profiles/contributors/me':
        return who.onboarded
            ? answer({...profileJson(), 'userId': who.id})
            : refusal(404, 'CONTRIBUTOR_PROFILE_NOT_FOUND');
      case 'POST /me/onboarding':
        who.onboarded = true;
        return answer({...profileJson(), 'userId': who.id});
      case 'GET /me/notification-preferences':
        return answer(who.preferences);
      case 'PUT /me/notification-preferences':
        final body = (jsonDecode(request.body) as Map).cast<String, Object?>();
        puts.add({'by': who.key, ...body});
        who.preferences = body;
        return answer(body);
      case 'GET /notifications':
        return answer({
          'items': who.feed,
          'nextCursor': null,
          'unseen': who.feed.length,
        });
      case 'POST /notifications/seen' || 'POST /notifications/read':
        return answer({'ok': true});
      case 'GET /challenges/browse':
        return answer({
          'items': [data.challengeJson()],
          'page': 1,
          'pageCount': 1,
        });
      case 'GET /challenges/$_brief':
        return answer(data.challengeJson());
      case 'GET /submissions/mine':
        return answer({'items': who.entries, 'nextCursor': null});
      case 'GET /submissions/mine/by-challenge/$_brief':
        final mine = who.entries
            .where((e) => e['challengeId'] == _brief)
            .firstOrNull;
        return mine == null ? refusal(404, 'NOT_FOUND') : answer(mine);
      case 'POST /submissions/challenges/$_brief':
        final entry = data.submissionJson({
          'id': 's_${who.key}',
          'challengeId': _brief,
          'title': '${who.name}: the plan I would pay for',
          'bodyText': 'Weekly bundles that roll over.',
          'status': 'pending',
          'result': null,
          'createdAt': figmaNow.toUtc().toIso8601String(),
          'files': <Object>[],
          'award': null,
          'brief': {
            'id': _brief,
            'slug': 'make-sunday-data-day',
            'title': 'Make Sunday data day',
            'businessName': 'Kudi Box',
            'logoUrl': null,
            'coverUrl': null,
            'deadline': '2026-10-25T17:00:00.000Z',
            'rewardPool': 15000000,
            'status': 'live',
          },
        });
        who.entries.insert(0, entry);
        return answer(entry, status: 201);
    }
    return refusal(404, 'NOT_FOUND');
  }
}

_TwoPeopleApi _api() => _TwoPeopleApi([
  _Person(
    'ada',
    'Ada Obi',
    feed: [
      _row('n_ada_1', 'Ada: results are in', 2),
      _row('n_ada_2', 'Ada: one more', 30),
    ],
    preferences: {...livePreferences},
  ),
  _Person(
    'bob',
    'Bob Ade',
    feed: [_row('n_bob_1', 'Bob: results are in', 3)],
    preferences: {
      'closingSoon': true,
      'results': true,
      'payouts': false,
      'newBriefs': true,
      'polls': true,
    },
    entries: [data.submissionJson()],
  ),
  _Person(
    'cleo',
    'Cleo Eze',
    feed: [],
    preferences: {...livePreferences},
    onboarded: false,
  ),
]);

/// A live build of the app on [api]: the real router, sign-in and sign out
/// through the app's own code, the outbox and the session guard running as
/// main.dart runs them.
class _Phone {
  _Phone(this.api, {LocalStore? store})
    : store = store ?? MemoryLocalStore(clock: () => figmaNow);

  final _TwoPeopleApi api;
  final LocalStore store;
  late ProviderContainer c;
  late GoRouter router;
  late WidgetRef ref;

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    SharedPreferences.setMockInitialValues({SplashScreen.litKey: true});
    final prefs = await SharedPreferences.getInstance();
    router = buildRouter(initialLocation: Routes.landing);
    addTearDown(router.dispose);
    c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        clockProvider.overrideWithValue(() => figmaNow),
        routerProvider.overrideWithValue(router),
        apiClientProvider.overrideWithValue(api.client),
        localStoreProvider.overrideWithValue(store),
        backendProvider.overrideWith(() => FixedBackend(allLive)),
        authServiceProvider.overrideWithValue(
          LiveAuthService(api: api.client, social: NoSocial()),
        ),
        activationsServiceProvider.overrideWithValue(
          DemoActivationsService(
            clock: () => figmaNow,
            load: Duration.zero,
            delay: Duration.zero,
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    c
      ..read(sessionGuardProvider)
      ..read(accountSyncProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: Consumer(
          builder: (context, ref, _) {
            this.ref = ref;
            return MaterialApp.router(
              theme: buildTheme(),
              routerConfig: router,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<SignInLanding> signIn(WidgetTester tester, String key) async {
    final p = api.person(key);
    final result = await c
        .read(authServiceProvider)
        .signIn(email: p.email, password: 'iqly-local-123');
    expect(result.ok, isTrue);
    final landing = await completeSignIn(
      ref,
      newAccount: result.newAccount,
      name: result.name,
      userId: result.userId,
    );
    await tester.pumpAndSettle();
    return landing;
  }

  Future<void> signOut(WidgetTester tester) async {
    await forgetAccount(ref);
    router.go(Routes.landing);
    await tester.pumpAndSettle();
  }

  Future<void> visit(WidgetTester tester, String location) async {
    router.go(location);
    await tester.pumpAndSettle();
  }

  Future<List<String>> feed() async => [
    for (final n in await c.read(notificationsProvider.future)) n.id,
  ];

  Future<void> flip(NotificationTopic topic, bool on) async {
    await c.read(notificationPreferencesProvider.future);
    expect(
      await c.read(notificationPreferencesProvider.notifier).set(topic, on),
      isTrue,
    );
    await c.read(outboxProvider).kick();
  }

  /// The API ends [key]'s session; a switch flipped after it is refused 401.
  Future<void> lose(WidgetTester tester, String key) async {
    await c.read(notificationPreferencesProvider.future);
    api.end(key);
    await c
        .read(notificationPreferencesProvider.notifier)
        .set(NotificationTopic.closingSoon, false);
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.path, Routes.landing);
    expect(c.read(sessionProvider).signedIn, isFalse);
  }

  /// Sends an entry on [_brief] as the submit screen does, receipt handed to
  /// My submissions.
  Future<String> send() async {
    final submit = c.read(submitServiceProvider);
    final opening = await submit.open(_brief);
    final result = await submit.submit(
      const SubmitRequest(
        briefId: _brief,
        title: 'The plan I would pay for',
        answer: 'Weekly bundles that roll over.',
      ),
    );
    final receipt = result.receipt!;
    c
        .read(sentSubmissionsProvider.notifier)
        .add(
          SubmissionItem(submission: receipt.submission, brief: opening.brief),
        );
    return receipt.submission.id;
  }

  Future<List<String>> mine() async => [
    for (final i in (await c.read(mySubmissionsProvider.future)).items) i.id,
  ];
}

const _bobsOwn = {
  'closingSoon': true,
  'results': true,
  'payouts': false,
  'newBriefs': true,
  'polls': true,
};

/// Ada has used the app: her feed and bell loaded, Results switched off, an
/// entry sent on [_brief] that its detail page offers to show.
Future<void> _adaUses(WidgetTester tester, _Phone phone) async {
  await phone.signIn(tester, 'ada');
  expect(await phone.feed(), ['n_ada_1', 'n_ada_2']);
  expect(await phone.c.read(unreadNotificationsProvider.future), 2);
  await phone.flip(NotificationTopic.results, false);
  expect(phone.api.puts, [
    {'by': 'ada', ...livePreferences, 'results': false},
  ]);
  await phone.c
      .read(draftsProvider.notifier)
      .save(
        Draft(
          briefId: 'c_2',
          title: 'Ada\'s draft',
          answer: 'Not sent yet',
          editedAt: figmaNow,
        ),
      );
  expect(await phone.send(), 's_ada');
  expect(await phone.mine(), ['s_ada']);
  expect(phone.c.read(briefSubmissionProvider(_brief)), 's_ada');
  await phone.visit(tester, Routes.brief(_brief));
  expect(find.text('View your submission'), findsOneWidget);
}

/// Bob, signed in after Ada, sees only his own: feed, bell, switches,
/// entries and the brief Ada answered as one he has not; his first flip
/// sends his own switches.
Future<void> _bobSeesOnlyHis(WidgetTester tester, _Phone phone) async {
  final c = phone.c;
  expect(c.read(sessionProvider).userId, 'u_bob');
  expect(await phone.feed(), ['n_bob_1']);
  expect(await c.read(unreadNotificationsProvider.future), 1);
  final switches = await c.read(notificationPreferencesProvider.future);
  expect(switches[NotificationTopic.results], isTrue);
  expect(switches[NotificationTopic.payouts], isFalse);
  expect(switches[NotificationTopic.polls], isTrue);
  expect(c.read(sentSubmissionsProvider), isEmpty);
  expect(await phone.mine(), ['s_1']);
  expect(await c.read(draftsProvider.future), isEmpty);
  expect(
    [for (final d in await phone.store.drafts('u_ada')) d.title],
    ['Ada\'s draft'],
  );

  await phone.visit(tester, Routes.brief(_brief));
  expect(find.text('View your submission'), findsNothing);
  expect(find.text('Start your submission'), findsOneWidget);
  expect(c.read(briefSubmissionProvider(_brief)), isNull);
  await phone.visit(tester, Routes.notifications);
  expect(find.text('Bob: results are in', findRichText: true), findsOneWidget);
  expect(find.text('Ada: results are in', findRichText: true), findsNothing);

  final before = phone.api.puts.length;
  await phone.flip(NotificationTopic.newBriefs, false);
  expect(phone.api.puts.skip(before), [
    {'by': 'bob', ..._bobsOwn, 'newBriefs': false},
  ]);
}

void main() {
  testWidgets('after a sign-out, the next person to sign in sees nothing of '
      'the first', (tester) async {
    final phone = _Phone(_api());
    await phone.open(tester);
    await _adaUses(tester, phone);

    await phone.signOut(tester);
    await phone.signIn(tester, 'bob');
    await _bobSeesOnlyHis(tester, phone);
  });

  testWidgets('after a lost session (401), the next person to sign in sees '
      'nothing of the first, and what the first left queued never goes '
      'under the second', (tester) async {
    final store = MemoryLocalStore(clock: () => figmaNow);
    final phone = _Phone(_api(), store: store);
    await phone.open(tester);
    await _adaUses(tester, phone);

    await phone.lose(tester, 'ada');
    expect(phone.c.read(sessionProvider).lostUserId, 'u_ada');
    expect(
      [for (final i in await store.outbox('u_ada')) i.payload['closingSoon']],
      [false],
    );

    await phone.signIn(tester, 'bob');
    expect(phone.c.read(sessionProvider).lostUserId, isNull);
    expect(await store.outbox('u_ada'), isEmpty);
    expect(await store.readCache('u_ada', AccountKeys.notifications), isNull);
    await _bobSeesOnlyHis(tester, phone);
    await phone.c.read(outboxProvider).kick();
    expect(phone.api.puts.where((put) => put['by'] == 'bob'), [
      {'by': 'bob', ..._bobsOwn, 'newBriefs': false},
    ]);
  });

  testWidgets('a lost session keeps what the account has on the phone, and '
      'the same account finds all of it when it signs in again', (
    tester,
  ) async {
    final store = MemoryLocalStore(clock: () => figmaNow);
    final phone = _Phone(_api(), store: store);
    await phone.open(tester);
    await phone.signIn(tester, 'ada');
    final c = phone.c;
    final photo = IqPhotoAvatar(Uint8List.fromList(List.filled(64, 7)));
    await c.read(avatarProvider.notifier).choose(photo);
    c.read(onboardingDraftProvider.notifier).setCity('Yaba');
    await c
        .read(draftsProvider.notifier)
        .save(
          Draft(
            briefId: _brief,
            title: 'Sunday plan',
            answer: 'Bundles',
            editedAt: figmaNow,
          ),
        );
    expect(await phone.feed(), ['n_ada_1', 'n_ada_2']);

    await phone.lose(tester, 'ada');
    final prefs = c.read(sharedPreferencesProvider);
    expect(prefs.getString('avatar.photo'), isNotNull);
    expect(prefs.getString('onboarding.draft'), contains('Yaba'));
    expect(await store.drafts('u_ada'), hasLength(1));
    expect(
      await store.readCache('u_ada', AccountKeys.notifications),
      isNotNull,
    );
    expect(await store.outbox('u_ada'), hasLength(1));
    expect(phone.api.puts, isEmpty);

    await phone.signIn(tester, 'ada');
    await c.read(outboxProvider).kick();
    expect(phone.api.puts, [
      {'by': 'ada', ...livePreferences, 'closingSoon': false},
    ]);
    expect(await store.outbox('u_ada'), isEmpty);
    final avatar = c.read(avatarProvider);
    expect(avatar.spec, isA<IqPhotoAvatar>());
    expect(avatar.photo, photo.bytes);
    expect(c.read(onboardingDraftProvider).profile.city, 'Yaba');
    expect(
      [for (final d in await c.read(draftsProvider.future)) d.briefId],
      [_brief],
    );
  });

  testWidgets('a new account whose first-run answers a lost session held '
      'back signs in again to where it left off: Discover, its avatar, and '
      'its answers on their way', (tester) async {
    final store = MemoryLocalStore(clock: () => figmaNow);
    final phone = _Phone(_api(), store: store);
    await phone.open(tester);
    expect((await phone.signIn(tester, 'cleo')).route, Routes.onboarding);
    final c = phone.c;
    final avatar = c.read(avatarProvider).spec;
    c.read(onboardingDraftProvider.notifier)
      ..setOccupation('student')
      ..setCity('Yaba');

    phone.api.end('cleo');
    await c
        .read(onboardingServiceProvider)
        .saveProfile(c.read(onboardingDraftProvider).profile);
    await c.read(sessionProvider.notifier).setOnboardingDone(true);
    await c.read(outboxProvider).kick();
    await tester.pumpAndSettle();
    expect(c.read(sessionProvider).signedIn, isFalse);
    expect(phone.api.person('cleo').onboarded, isFalse);

    expect((await phone.signIn(tester, 'cleo')).route, Routes.home);
    await c.read(outboxProvider).kick();
    expect(phone.api.person('cleo').onboarded, isTrue);
    expect(await store.outbox('u_cleo'), isEmpty);
    expect(c.read(avatarProvider).spec.toJson(), avatar.toJson());
    expect(c.read(onboardingDraftProvider).profile.city, 'Yaba');
  });

  testWidgets('a lost session\'s things are forgotten, as sign out would, '
      'before anyone else signs in: drafts stay with their account', (
    tester,
  ) async {
    final store = MemoryLocalStore(clock: () => figmaNow);
    final phone = _Phone(_api(), store: store);
    await phone.open(tester);
    await phone.signIn(tester, 'ada');
    final c = phone.c;
    await c
        .read(avatarProvider.notifier)
        .choose(IqPhotoAvatar(Uint8List.fromList(List.filled(64, 7))));
    c.read(onboardingDraftProvider.notifier).setCity('Yaba');
    final brief = (await c.read(briefDetailProvider(_brief).future))!;
    await c.read(savedBriefsProvider.future);
    await c.read(savedBriefsProvider.notifier).setSaved(brief, true);
    await c.read(closeRemindersProvider.future);
    await c.read(closeRemindersProvider.notifier).setReminder(_brief, true);
    expect(await phone.feed(), ['n_ada_1', 'n_ada_2']);
    await c
        .read(draftsProvider.notifier)
        .save(
          Draft(
            briefId: _brief,
            title: 'Sunday plan',
            answer: 'Bundles',
            editedAt: figmaNow,
          ),
        );

    final prefs = c.read(sharedPreferencesProvider);
    expect(prefs.getString(SavedBriefsNotifier.key), contains(_brief));
    expect(prefs.getStringList(CloseRemindersNotifier.key), [_brief]);
    expect(
      await store.readCache('u_ada', AccountKeys.notifications),
      isNotNull,
    );

    phone.api.end('ada');
    c.invalidate(unreadNotificationsProvider);
    await expectLater(c.read(unreadNotificationsProvider.future), completes);
    await tester.pumpAndSettle();
    expect(c.read(sessionProvider).lostUserId, 'u_ada');

    await phone.signIn(tester, 'bob');
    expect(prefs.getString('avatar.photo'), isNull);
    expect(prefs.getString('onboarding.draft'), isNull);
    expect(await c.read(savedBriefsProvider.future), isEmpty);
    expect(await c.read(closeRemindersProvider.future), isEmpty);
    expect(c.read(onboardingDraftProvider).profile.city, isEmpty);
    expect(await c.read(draftsProvider.future), isEmpty);
    expect(await store.drafts('u_ada'), hasLength(1));
    expect(await store.readCache('u_ada', AccountKeys.notifications), isNull);
  });

  testWidgets('in the preview, the next person starts from the sample as it '
      'ships, not from what the first did with it', (tester) async {
    SharedPreferences.setMockInitialValues({SplashScreen.litKey: true});
    final prefs = await SharedPreferences.getInstance();
    final router = buildRouter(initialLocation: Routes.landing);
    addTearDown(router.dispose);
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        routerProvider.overrideWithValue(router),
        authServiceProvider.overrideWithValue(
          DemoAuthService(delay: Duration.zero),
        ),
      ],
    );
    addTearDown(c.dispose);
    late WidgetRef ref;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: Consumer(
          builder: (context, widgetRef, _) {
            ref = widgetRef;
            return const SizedBox();
          },
        ),
      ),
    );

    await tester.runAsync(() async {
      Future<void> signIn() async {
        final result = await c
            .read(authServiceProvider)
            .signIn(
              email: DemoData.user.email,
              password: DemoAuthService.password,
            );
        await completeSignIn(ref, newAccount: false, name: result.name);
      }

      await signIn();
      expect(await c.read(unreadNotificationsProvider.future), 3);
      await c.read(notificationsProvider.future);
      await c.read(notificationsProvider.notifier).markSeen();
      expect(await c.read(unreadNotificationsProvider.future), 0);
      await c.read(notificationPreferencesProvider.future);
      await c
          .read(notificationPreferencesProvider.notifier)
          .set(NotificationTopic.results, false);
      final submit = c.read(submitServiceProvider);
      final open = [
        for (final b in await c.read(repositoryProvider).briefs())
          if ((await submit.open(b.id)).form != null) b,
      ];
      final live = open.first;
      final result = await submit.submit(
        SubmitRequest(briefId: live.id, title: 'Mine', answer: 'Mine'),
      );
      c
          .read(sentSubmissionsProvider.notifier)
          .add(
            SubmissionItem(submission: result.receipt!.submission, brief: live),
          );
      final sent = result.receipt!.submission.id;
      expect([
        for (final i in (await c.read(mySubmissionsProvider.future)).items)
          i.id,
      ], contains(sent));

      await forgetAccount(ref);
      await signIn();
      expect(await c.read(unreadNotificationsProvider.future), 3);
      final switches = await c.read(notificationPreferencesProvider.future);
      expect(switches[NotificationTopic.results], isTrue);
      expect(c.read(sentSubmissionsProvider), isEmpty);
      expect([
        for (final i in (await c.read(mySubmissionsProvider.future)).items)
          i.id,
      ], isNot(contains(sent)));
    });
  });
}
