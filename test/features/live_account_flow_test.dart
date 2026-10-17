import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/auth.dart';
import 'package:iqly_mobile/data/drafts_data.dart';
import 'package:iqly_mobile/data/live/live_account.dart';
import 'package:iqly_mobile/data/local/local_providers.dart';
import 'package:iqly_mobile/data/local/local_store.dart';
import 'package:iqly_mobile/data/local/memory_local_store.dart';
import 'package:iqly_mobile/data/onboarding_service.dart';
import 'package:iqly_mobile/data/profile_service.dart';
import 'package:iqly_mobile/features/discover/discover_state.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/entry/landing_screen.dart';
import 'package:iqly_mobile/features/onboarding/about_you_screen.dart';
import 'package:iqly_mobile/features/onboarding/onboarding_draft.dart';
import 'package:iqly_mobile/features/profile/account_sync.dart';
import 'package:iqly_mobile/features/profile/profile_state.dart';
import 'package:iqly_mobile/features/settings/account_closing_screen.dart';
import 'package:iqly_mobile/features/settings/delete_account_screen.dart';
import 'package:iqly_mobile/features/settings/restore_account_screen.dart';
import 'package:iqly_mobile/features/splash/splash_screen.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/surfaces/push.dart';
import 'package:iqly_mobile/ui/button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../golden/screens/app_harness.dart';
import '../golden/screens/more_harness.dart';
import '../golden/screens/profile_harness.dart';
import '../support/live_api.dart';
import '../support/live_app.dart';

IqButton _button(WidgetTester tester, String label) => tester.widget<IqButton>(
  find.byWidgetPredicate((w) => w is IqButton && w.label == label),
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Draft _draft() => Draft(
  briefId: 'c5',
  title: 'Solar for every kiosk',
  answer: 'Pay as you sell.',
  editedAt: DateTime(2026, 10, 3, 9),
);

/// A phone OneSignal has subscribed.
class _Subscribed implements PushSdk {
  @override
  Future<void> initialize(String appId) async {}

  @override
  String? get subscriptionId => 'sub_1';

  @override
  bool get optedIn => true;

  @override
  void onSubscriptionChanged(VoidCallback listener) {}

  @override
  void onOpened(void Function(Map<String, dynamic>) listener) {}

  @override
  void onArrived(VoidCallback listener) {}

  @override
  Future<void> requestPermission() async {}
}

void main() {
  group('Your details', () {
    final device = {
      AccountDetailsNotifier.key: jsonEncode(
        const AccountDetails(phone: '+234 801 111 1111'),
      ),
    };

    testWidgets('a live build shows the account\'s copy over the device\'s', (
      tester,
    ) async {
      await pumpLive(
        tester,
        Routes.yourDetails,
        accountApi(),
        prefs: liveSignedIn(device),
      );
      expect(find.text('+2348012345678'), findsOneWidget);
      expect(find.text('+234 801 111 1111'), findsNothing);
      expect(find.text('9 April 2001'), findsOneWidget);
    });

    testWidgets('with no answer and nothing kept, the device copy stands '
        'in', (tester) async {
      final api = accountApi()..offline = true;
      await pumpLive(
        tester,
        Routes.yourDetails,
        api,
        prefs: liveSignedIn(device),
      );
      expect(find.text('+234 801 111 1111'), findsOneWidget);
    });

    testWidgets('the preview keeps the device copy first', (tester) async {
      await pumpProfileApp(
        tester,
        Routes.yourDetails,
        prefs: {...signedInPrefs(), ...device},
      );
      expect(find.text('+234 801 111 1111'), findsOneWidget);
    });

    testWidgets('a live edit shows at once and queues only what changed', (
      tester,
    ) async {
      final store = liveStore();
      final api = accountApi();
      await pumpLive(tester, Routes.yourDetails, api, store: store);
      api.offline = true;
      await _tap(tester, find.text('City'));
      await _tap(tester, find.text('Ikeja'));
      await _tap(tester, find.text('Save'));
      expect(find.text('Lagos · Ikeja'), findsOneWidget);
      final item = (await store.outbox('u_1')).single;
      expect(item.kind, AccountWrite.profile.kind);
      expect(item.payload, {'city': 'Ikeja'});
    });
  });

  group('Restore your account?', () {
    testWidgets('a restore that does not go through stops loading and says '
        'so; the next one opens Discover', (tester) async {
      final api = accountApi({
        'POST /me/account/restore': (_) => refusal(500, 'HTTP_ERROR'),
      });
      await pumpLive(tester, Routes.restoreAccount, api);
      expect(find.text(ClosingLayout.failedText), findsNothing);
      await _tap(tester, find.text('Restore my account'));
      expect(_button(tester, 'Restore my account').loading, isFalse);
      expect(find.text(ClosingLayout.failedText), findsOneWidget);
      expect(find.byType(RestoreAccountScreen), findsOneWidget);

      api.routes['POST /me/account/restore'] = (_) =>
          answer({'status': 'active'});
      await _tap(tester, find.text('Restore my account'));
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(api.to('POST /me/account/restore'), hasLength(2));
    });

    testWidgets('Keep it closed signs out with the API: the token and '
        'everything of the account on the phone go', (tester) async {
      final store = liveStore();
      await store.writeCache('u_1', AccountKeys.me, meJson());
      await store.saveDraft('u_1', _draft());
      final api = accountApi();
      final (container, _) = await pumpLive(
        tester,
        Routes.restoreAccount,
        api,
        store: store,
      );
      await _tap(tester, find.text('Keep it closed'));
      expect(find.byType(LandingScreen), findsOneWidget);
      expect(api.to('POST /auth/web/sign-out'), hasLength(1));
      expect(await api.tokens.read(), isNull);
      final session = container.read(sessionProvider);
      expect((session.signedIn, session.userId), (false, null));
      expect(await store.readCache('u_1', AccountKeys.me), isNull);
      expect(await store.drafts('u_1'), isEmpty);
    });
  });

  testWidgets('signing in to a closing account opens Restore with its date, '
      'the account id kept from the sign-in answer', (tester) async {
    final api = accountApi({
      'POST /auth/web/sign-in/email': (_) => raw(
        {
          'redirect': false,
          'token': 'raw',
          'user': {'id': 'u_1', 'name': 'Ada Obi', 'email': 'ada@example.com'},
        },
        headers: {'set-auth-token': 'fresh.token'},
      ),
      'GET /me': (_) => answer(
        meJson(status: 'closing', closesAt: '2026-10-31T10:00:00.000Z'),
      ),
    });
    final (container, _) = await pumpLive(
      tester,
      Routes.signIn,
      api,
      prefs: {SplashScreen.litKey: true},
    );
    await tester.enterText(find.byType(EditableText).at(0), 'ada@example.com');
    await tester.enterText(find.byType(EditableText).at(1), 'boldthinker');
    await tester.pumpAndSettle();
    await _tap(
      tester,
      find.byWidgetPredicate((w) => w is IqButton && w.label == 'Sign in'),
    );
    expect(find.byType(RestoreAccountScreen), findsOneWidget);
    expect(
      find.text(
        'Your account closes on 31 October. Sign in now and everything '
        'stays: wallet, submissions and history.',
      ),
      findsOneWidget,
    );
    expect(container.read(sessionProvider).userId, 'u_1');
    expect(container.read(sessionProvider).signedIn, isTrue);
  });

  testWidgets('signing in to an active account lands as before', (
    tester,
  ) async {
    final api = accountApi({
      'POST /auth/web/sign-in/email': (_) => raw({
        'redirect': false,
        'token': 'raw',
        'user': {'id': 'u_1', 'name': 'Ada Obi', 'email': 'ada@example.com'},
      }),
    });
    await pumpLive(
      tester,
      Routes.signIn,
      api,
      prefs: {SplashScreen.litKey: true},
    );
    await tester.enterText(find.byType(EditableText).at(0), 'ada@example.com');
    await tester.enterText(find.byType(EditableText).at(1), 'boldthinker');
    await tester.pumpAndSettle();
    await _tap(
      tester,
      find.byWidgetPredicate((w) => w is IqButton && w.label == 'Sign in'),
    );
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  group('sign out', () {
    testWidgets('one path: what the outbox holds goes first, the API ends '
        'the session once, then the phone forgets the account but keeps its '
        'drafts', (tester) async {
      final store = liveStore();
      await store.writeCache('u_1', AccountKeys.me, meJson());
      await store.saveDraft('u_1', _draft());
      var patched = false;
      bool? patchedFirst;
      final api = accountApi({
        'PATCH /profiles/contributors/me': (_) =>
            Future.delayed(const Duration(milliseconds: 500), () {
              patched = true;
              return answer(profileJson());
            }),
        'POST /auth/web/sign-out': (_) {
          patchedFirst ??= patched;
          return raw({'success': true});
        },
      });
      final (container, _) = await pumpLive(
        tester,
        Routes.profile,
        api,
        store: store,
        prefs: liveSignedIn({
          SavedBriefsNotifier.key: '[]',
          CloseRemindersNotifier.key: <String>['c5'],
        }),
      );
      container.read(accountSyncProvider);
      await container
          .read(profileServiceProvider)
          .saveDetails(
            const AccountDetails(phone: '+2348035554410'),
            const OnboardingProfile(),
            before: const AccountDetails(),
            answersBefore: const OnboardingProfile(),
          );
      await tester.pump();
      expect(api.to('PATCH /profiles/contributors/me'), hasLength(1));

      await _tap(tester, find.text('Sign out'));
      await tester.tap(find.widgetWithText(IqButton, 'Sign out'));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.byType(LandingScreen), findsOneWidget);
      expect(patchedFirst, isTrue);
      expect(api.to('POST /auth/web/sign-out'), hasLength(1));
      expect(await api.tokens.read(), isNull);
      expect(await store.readCache('u_1', AccountKeys.me), isNull);
      expect(await store.outbox('u_1'), isEmpty);
      expect(await store.drafts('u_1'), hasLength(1));
      final prefs = container.read(sharedPreferencesProvider);
      expect(prefs.getString(SavedBriefsNotifier.key), isNull);
      expect(prefs.getStringList(CloseRemindersNotifier.key), isNull);
      final session = container.read(sessionProvider);
      expect((session.signedIn, session.userId), (false, null));
    });

    testWidgets('waits at most 3 s for the outbox', (tester) async {
      final store = liveStore();
      final never = Completer<Never>();
      final api = accountApi({
        'PATCH /profiles/contributors/me': (_) => never.future,
      });
      final (container, _) = await pumpLive(
        tester,
        Routes.profile,
        api,
        store: store,
      );
      container.read(accountSyncProvider);
      await container
          .read(profileServiceProvider)
          .saveDetails(
            const AccountDetails(phone: '+2348035554410'),
            const OnboardingProfile(),
            before: const AccountDetails(),
            answersBefore: const OnboardingProfile(),
          );
      await tester.pump();
      await _tap(tester, find.text('Sign out'));
      await tester.tap(find.widgetWithText(IqButton, 'Sign out'));
      await tester.pump(
        AuthTiming.lastSend - const Duration(milliseconds: 100),
      );
      expect(api.to('POST /auth/web/sign-out'), isEmpty);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(api.to('POST /auth/web/sign-out'), hasLength(1));
      expect(find.byType(LandingScreen), findsOneWidget);
      expect(await store.outbox('u_1'), isEmpty);
      await tester.pump(const Duration(seconds: 30));
    });
  });

  group('delete account', () {
    Future<(ProviderContainer, FakeApi, MemoryLocalStore)> open(
      WidgetTester tester,
      ApiAnswer close,
    ) async {
      final store = liveStore();
      await store.saveDraft('u_1', _draft());
      final api = accountApi({'POST /me/account/close': close});
      final (container, _) = await pumpLive(
        tester,
        Routes.deleteAccount,
        api,
        store: store,
        repository: EmptyWalletRepository(),
      );
      await tester.enterText(find.byType(EditableText), 'delete');
      await tester.pumpAndSettle();
      return (container, api, store);
    }

    testWidgets('the API refusing with money still there fails as the screen '
        'already fails', (tester) async {
      final (_, api, _) = await open(
        tester,
        (_) => refusal(409, 'ACCOUNT_HAS_BALANCE'),
      );
      await _tap(tester, find.text('Delete my account'));
      expect(find.byType(DeleteAccountScreen), findsOneWidget);
      expect(find.text(DeleteAccountScreen.failedText), findsOneWidget);
      expect(_button(tester, 'Delete my account').loading, isFalse);
      expect(await api.tokens.read(), 'signed.token');
    });

    testWidgets('a withdrawal in flight fails the same way', (tester) async {
      await open(tester, (_) => refusal(409, 'WITHDRAWAL_IN_FLIGHT'));
      await _tap(tester, find.text('Delete my account'));
      expect(find.text(DeleteAccountScreen.failedText), findsOneWidget);
    });

    testWidgets('the API ending the account\'s sessions does not sign the '
        'phone out from under Account closing', (tester) async {
      final api = accountApi({
        'POST /me/account/close': (_) => answer({
          'status': 'closing',
          'closesAt': '2026-11-02T09:41:00.000Z',
        }),
        'POST /notifications/devices': (_) => answer({'ok': true}),
        'POST /notifications/devices/remove': (_) =>
            refusal(401, 'UNAUTHORIZED'),
        'POST /auth/web/sign-out': (_) => Future.delayed(
          const Duration(milliseconds: 300),
          () => raw({'success': true}),
        ),
      });
      final (container, router) = await pumpLive(
        tester,
        Routes.deleteAccount,
        api,
        repository: EmptyWalletRepository(),
        overrides: [
          pushProvider.overrideWith(
            (ref) => Push(
              devices: ApiPushDevices(api.client),
              signedIn: () => ref.read(sessionProvider).signedIn,
              onOpen: (_) {},
              onArrive: () {},
              sdk: _Subscribed(),
              platform: TargetPlatform.android,
            ),
          ),
        ],
      );
      container.read(sessionGuardProvider);
      await container.read(pushProvider)!.start();
      final delegate = router.routerDelegate;
      final went = <String>[];
      void moved() => went.add(delegate.currentConfiguration.uri.path);
      delegate.addListener(moved);
      addTearDown(() => delegate.removeListener(moved));
      await tester.enterText(find.byType(EditableText), 'delete');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete my account'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(api.to('POST /notifications/devices/remove'), hasLength(1));
      expect(went, [Routes.accountClosing]);
      expect(find.byType(AccountClosingScreen), findsOneWidget);
      expect(await api.tokens.read(), isNull);
    });

    testWidgets('a close the API takes forgets everything of the account on '
        'the phone and hands off to Account closing', (tester) async {
      final (container, api, store) = await open(
        tester,
        (_) => answer({
          'status': 'closing',
          'closesAt': '2026-11-02T09:41:00.000Z',
        }),
      );
      await _tap(tester, find.text('Delete my account'));
      expect(find.byType(AccountClosingScreen), findsOneWidget);
      expect(api.to('POST /me/account/close').single.body, {
        'confirm': 'DELETE',
      });
      expect(await api.tokens.read(), isNull);
      expect(await store.drafts('u_1'), isEmpty);
      expect(container.read(sessionProvider).signedIn, isFalse);
    });
  });

  group('the outbox and the session', () {
    testWidgets('runs for the signed-in account, holds at sign out and '
        'resumes at the next sign-in', (tester) async {
      final store = liveStore();
      final api = accountApi({
        'PUT /me/notification-preferences': (call) => answer(call.body),
      });
      final (container, _) = await pumpLive(
        tester,
        Routes.profile,
        api,
        store: store,
      );
      container.read(accountSyncProvider);
      final outbox = container.read(outboxProvider);
      await outbox.enqueue(
        'u_1',
        kind: AccountWrite.preferences.kind,
        payload: livePreferences,
      );
      await tester.pump();
      expect(api.to('PUT /me/notification-preferences'), hasLength(1));

      final session = container.read(sessionProvider.notifier);
      await session.setSignedIn(false);
      await outbox.enqueue(
        'u_1',
        kind: AccountWrite.preferences.kind,
        payload: {...livePreferences, 'polls': true},
      );
      await tester.pump();
      expect(api.to('PUT /me/notification-preferences'), hasLength(1));

      await session.setSignedIn(true);
      await tester.pump();
      expect(api.to('PUT /me/notification-preferences'), hasLength(2));
    });

    testWidgets('first-run answers the API refuses as under 18 take first run '
        'back to About you, which says why', (tester) async {
      final api = accountApi({
        'POST /me/onboarding': (_) => refusal(403, 'UNDER_AGE'),
      });
      final (container, router) = await pumpLive(
        tester,
        Routes.home,
        api,
        prefs: liveSignedIn({
          'onboarding.draft': jsonEncode({
            'occupation': 'student',
            'dateOfBirth': DateTime(2008, 10, 3).toIso8601String(),
            'lastStep': 'whatYouLike',
          }),
        }),
      );
      container.read(accountSyncProvider);
      await container
          .read(onboardingServiceProvider)
          .saveProfile(container.read(onboardingDraftProvider).profile);
      await tester.pumpAndSettle();

      expect(
        api.to('POST /me/onboarding').single.body,
        containsPair('dateOfBirth', '2008-10-03'),
      );
      expect(container.read(sessionProvider).onboardingDone, isFalse);
      final draft = container.read(onboardingDraftProvider);
      expect(draft.underAge, isTrue);
      expect(draft.profile.dateOfBirth, isNull);
      expect(draft.lastStep, OnboardingStep.aboutYou);
      expect(draft.profile.occupation, 'student');

      router.go(Routes.onboardingAboutYou);
      await tester.pumpAndSettle();
      expect(find.byType(AboutYouScreen), findsOneWidget);
      expect(find.text(AboutYouScreen.underAge), findsOneWidget);
    });
  });

  group('first run on the API', () {
    testWidgets('Finish counts first run done once the answers are queued, '
        'even with no connection', (tester) async {
      final store = liveStore();
      final api = accountApi()..offline = true;
      final (container, router) = await pumpLive(
        tester,
        Routes.onboardingWhatYouLike,
        api,
        store: store,
        prefs: liveSignedIn({
          'session.onboardingDone': false,
          'onboarding.draft': jsonEncode({
            'occupation': 'student',
            'interests': ['education', 'finance_fintech'],
            'lastStep': 'whatYouLike',
          }),
        }),
      );
      await _tap(tester, find.text('Skip for now'));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(container.read(sessionProvider).onboardingDone, isTrue);
      final item = (await store.outbox('u_1')).single;
      expect(item.kind, AccountWrite.onboarding.kind);
      expect(item.payload['skipped'], isTrue);
      expect(item.payload['interests'], ['education', 'finance_fintech']);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        isNot(Routes.onboardingWhatYouLike),
      );
    });

    Future<ProviderContainer> launch(
      Map<String, Object> prefs,
      LocalStore store,
    ) async {
      SharedPreferences.setMockInitialValues(prefs);
      final shared = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(shared),
          localStoreProvider.overrideWithValue(store),
          ...liveOverrides(accountApi()),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    final unfinished = Me.fromJson(
      meJson(profile: profileJson(onboardingCompletedAt: null)),
    );

    test('done on the phone but not on the account: the answers the phone '
        'holds go to the account', () async {
      final store = liveStore();
      final container = await launch(
        liveSignedIn({
          'onboarding.draft': jsonEncode({'occupation': 'employed'}),
        }),
        store,
      );
      await syncFirstRun(container.read, unfinished);
      final item = (await store.outbox('u_1')).single;
      expect(item.kind, AccountWrite.onboarding.kind);
      expect(item.payload['occupation'], 'employed');
      expect(container.read(sessionProvider).onboardingDone, isTrue);
    });

    test('with no answers left on the phone, first run runs again', () async {
      final store = liveStore();
      final container = await launch(liveSignedIn(), store);
      await syncFirstRun(container.read, unfinished);
      expect(container.read(sessionProvider).onboardingDone, isFalse);
      expect(await store.outbox('u_1'), isEmpty);
    });

    test('done on the account, or checked before, changes nothing', () async {
      final store = liveStore();
      final container = await launch(liveSignedIn(), store);
      await syncFirstRun(container.read, Me.fromJson(meJson()));
      expect(container.read(sessionProvider).onboardingDone, isTrue);
      await syncFirstRun(container.read, unfinished);
      expect(container.read(sessionProvider).onboardingDone, isTrue);
      expect(await store.outbox('u_1'), isEmpty);
    });
  });

  testWidgets('a launch signed in to a closing account hands off from the '
      'splash to Restore', (tester) async {
    final api = accountApi({
      'GET /me': (_) => answer(
        meJson(status: 'closing', closesAt: '2026-10-31T10:00:00.000Z'),
      ),
    });
    final (container, router) = await pumpLive(tester, Routes.splash, api);
    unawaited(checkAccountAtLaunch(container.read, router));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byType(RestoreAccountScreen), findsOneWidget);
    expect(container.read(sessionProvider).userId, 'u_1');
  });

  testWidgets('a launch signed in to an active account stays where the splash '
      'went, with the account\'s name', (tester) async {
    final (container, router) = await pumpLive(
      tester,
      Routes.splash,
      accountApi(),
      prefs: liveSignedIn({'session.name': 'Ada', 'session.userId': 'old'}),
    );
    unawaited(checkAccountAtLaunch(container.read, router));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(container.read(sessionProvider).name, 'Ada Obi');
    expect(container.read(sessionProvider).userId, 'u_1');
  });
}
