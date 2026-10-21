import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iqly_mobile/core/backend.dart';
import 'package:iqly_mobile/core/deadline.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/profile_service.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/data/token_store.dart';
import 'package:iqly_mobile/features/discover/discover_state.dart';
import 'package:iqly_mobile/features/profile/profile_state.dart';
import 'package:iqly_mobile/surfaces/notification_content.dart';
import 'package:iqly_mobile/surfaces/surfaces.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Answers each check with [answer].
class _Health implements HealthService {
  _Health(this.answer);

  Future<HealthReport> Function() answer;
  int calls = 0;

  @override
  Future<HealthReport> check() {
    calls++;
    return answer();
  }
}

/// A live account: nothing saved and no reminders yet.
class _LiveRepository extends DemoRepository {
  _LiveRepository() : super(DemoData());

  @override
  Future<List<String>> savedBriefIds() async => const [];

  @override
  Future<List<String>> closeReminderIds() async => const [];
}

Map<String, dynamic> _health({
  bool ready = true,
  Object? contract = 1,
  Set<LiveFeature> off = const {},
}) => {
  'success': true,
  'data': {
    'ok': true,
    'db': true,
    'mobile': {
      'contract': contract,
      'ready': ready,
      'features': {
        for (final f in LiveFeature.values) f.name: !off.contains(f),
      },
    },
  },
};

Backend _decide(Map<String, dynamic> body) =>
    Backend.from(HealthReport.fromJson(body));

final _all = Backend(LiveFeature.values.toSet());

HealthReport _report(Map<String, dynamic> body) => HealthReport.fromJson(body);

void main() {
  group('health', () {
    test('a ready API runs every feature live', () {
      expect(_decide(_health()), _all);
      expect(_decide(_health()).isPreview, isFalse);
    });

    test('a 503 is still read', () async {
      final body = _health(off: {LiveFeature.wallet, LiveFeature.withdrawals});
      (body['data'] as Map)['ok'] = false;
      final service = LiveHealthService(
        ApiClient(
          tokens: MemoryTokenStore(),
          baseUrl: 'https://api.test',
          client: MockClient(
            (request) async => http.Response(
              jsonEncode(body),
              request.url.path == '/health' ? 503 : 404,
            ),
          ),
        ),
      );
      expect(
        Backend.from(await service.check()),
        const Backend({
          LiveFeature.profile,
          LiveFeature.briefs,
          LiveFeature.submit,
          LiveFeature.submissions,
          LiveFeature.notifications,
          LiveFeature.avatar,
          LiveFeature.leaderboard,
          LiveFeature.referrals,
          LiveFeature.support,
          LiveFeature.polls,
          LiveFeature.businessNote,
          LiveFeature.avatarPhoto,
          LiveFeature.phoneVerification,
          LiveFeature.savedBriefsSync,
          LiveFeature.closeRemindersSync,
          LiveFeature.uploads,
          LiveFeature.etags,
          LiveFeature.config,
          LiveFeature.briefAudience,
          LiveFeature.helpAuthorNames,
          LiveFeature.supportChannels,
          LiveFeature.pollQuestions,
          LiveFeature.genderRequired,
          LiveFeature.supportDocuments,
        }),
      );
    });

    test('no mobile block is preview', () {
      expect(
        _decide({
          'success': true,
          'data': {'ok': true, 'db': true},
        }),
        Backend.preview,
      );
    });

    test('any contract but this build\'s, or none, is preview', () {
      expect(_decide(_health(contract: 0)), Backend.preview);
      expect(_decide(_health(contract: null)), Backend.preview);
      expect(_decide(_health(contract: '1')), Backend.preview);
      expect(_decide(_health(contract: 2)), Backend.preview);
      expect(_decide(_health(contract: 1)), _all);
    });

    test('not ready is preview', () {
      expect(_decide(_health(ready: false)), Backend.preview);
    });

    test('anything unreadable is preview', () async {
      expect(_decide(const {}), Backend.preview);
      expect(
        _decide({
          'data': [1, 2],
        }),
        Backend.preview,
      );
      expect(
        _decide({
          'data': {'mobile': 'ready'},
        }),
        Backend.preview,
      );
      expect(
        _decide({
          'data': {
            'mobile': {
              'contract': 1,
              'ready': true,
              'features': ['profile'],
            },
          },
        }),
        Backend.preview,
      );
      final garbled = LiveHealthService(
        ApiClient(
          tokens: MemoryTokenStore(),
          client: MockClient((_) async => http.Response('<html>', 502)),
        ),
      );
      expect(Backend.from(await garbled.check()), Backend.preview);
    });

    test('the API reports the features on, apart from what they need', () {
      final report = _report(_health(off: {LiveFeature.briefs}));
      expect(report.ready, isTrue);
      expect(report.contract, 1);
      expect(report.features, contains(LiveFeature.submit));
      expect(report.features, isNot(contains(LiveFeature.briefs)));
    });
  });

  group('what each feature needs', () {
    test('runs all the way down', () {
      expect(LiveFeature.account.closure, {
        LiveFeature.account,
        LiveFeature.profile,
        LiveFeature.wallet,
      });
      expect(LiveFeature.withdrawals.closure, {
        LiveFeature.withdrawals,
        LiveFeature.wallet,
        LiveFeature.profile,
      });
      expect(LiveFeature.submit.closure, {
        LiveFeature.submit,
        LiveFeature.briefs,
        LiveFeature.profile,
      });
      expect(LiveFeature.submissions.closure, {
        LiveFeature.submissions,
        LiveFeature.briefs,
      });
      for (final f in [
        LiveFeature.profile,
        LiveFeature.briefs,
        LiveFeature.notifications,
      ]) {
        expect(f.closure, {f});
      }
    });

    test('profile off takes submit, wallet, withdrawals and account with '
        'it', () {
      expect(
        _decide(_health(off: {LiveFeature.profile})),
        const Backend({
          LiveFeature.briefs,
          LiveFeature.submissions,
          LiveFeature.notifications,
          LiveFeature.leaderboard,
          LiveFeature.businessNote,
          LiveFeature.savedBriefsSync,
          LiveFeature.closeRemindersSync,
          LiveFeature.etags,
          LiveFeature.config,
          LiveFeature.briefAudience,
        }),
      );
    });

    test('wallet off takes withdrawals and account with it', () {
      final backend = _decide(_health(off: {LiveFeature.wallet}));
      expect(backend.isLive(LiveFeature.profile), isTrue);
      expect(backend.isLive(LiveFeature.wallet), isFalse);
      expect(backend.isLive(LiveFeature.withdrawals), isFalse);
      expect(backend.isLive(LiveFeature.account), isFalse);
      expect(backend.isLive(LiveFeature.submit), isTrue);
    });

    test('briefs off takes submit and submissions with it', () {
      final backend = _decide(_health(off: {LiveFeature.briefs}));
      expect(backend.names, [
        'profile',
        'wallet',
        'withdrawals',
        'notifications',
        'account',
        'avatar',
        'bankAccounts',
        'referrals',
        'support',
        'polls',
        'activations',
        'referralRewards',
        'avatarPhoto',
        'withdrawalPin',
        'phoneVerification',
        'etags',
        'config',
        'activationStepProof',
        'helpAuthorNames',
        'supportChannels',
        'pollQuestions',
        'genderRequired',
        'supportDocuments',
      ]);
    });

    test('support needs the profile, the note submissions, rewards '
        'referrals and the wallet, and photos the avatar', () {
      expect(LiveFeature.support.closure, {
        LiveFeature.support,
        LiveFeature.profile,
      });
      expect(LiveFeature.businessNote.closure, {
        LiveFeature.businessNote,
        LiveFeature.submissions,
        LiveFeature.briefs,
      });
      expect(LiveFeature.referralRewards.closure, {
        LiveFeature.referralRewards,
        LiveFeature.referrals,
        LiveFeature.wallet,
        LiveFeature.profile,
      });
      expect(LiveFeature.avatarPhoto.closure, {
        LiveFeature.avatarPhoto,
        LiveFeature.avatar,
        LiveFeature.profile,
      });
      final noReferrals = _decide(_health(off: {LiveFeature.referrals}));
      expect(noReferrals.isLive(LiveFeature.referralRewards), isFalse);
      expect(noReferrals.isLive(LiveFeature.wallet), isTrue);
    });

    test('avatar and referrals need the profile, saved accounts the '
        'wallet and the leaderboard submissions', () {
      expect(LiveFeature.avatar.closure, {
        LiveFeature.avatar,
        LiveFeature.profile,
      });
      expect(LiveFeature.referrals.closure, {
        LiveFeature.referrals,
        LiveFeature.profile,
      });
      expect(LiveFeature.bankAccounts.closure, {
        LiveFeature.bankAccounts,
        LiveFeature.wallet,
        LiveFeature.profile,
      });
      expect(LiveFeature.leaderboard.closure, {
        LiveFeature.leaderboard,
        LiveFeature.submissions,
        LiveFeature.briefs,
      });
      expect(LiveFeature.polls.closure, {
        LiveFeature.polls,
        LiveFeature.profile,
      });
      expect(LiveFeature.support.closure, {
        LiveFeature.support,
        LiveFeature.profile,
      });
      expect(LiveFeature.activations.closure, {
        LiveFeature.activations,
        LiveFeature.profile,
        LiveFeature.wallet,
      });
      final backend = _decide(_health(off: {LiveFeature.wallet}));
      expect(backend.isLive(LiveFeature.bankAccounts), isFalse);
      expect(backend.isLive(LiveFeature.activations), isFalse);
      expect(backend.isLive(LiveFeature.avatar), isTrue);
      expect(backend.isLive(LiveFeature.polls), isTrue);
    });

    test('section 13 features need what they call into', () {
      expect(LiveFeature.withdrawalPin.closure, {
        LiveFeature.withdrawalPin,
        LiveFeature.withdrawals,
        LiveFeature.wallet,
        LiveFeature.profile,
      });
      expect(LiveFeature.phoneVerification.closure, {
        LiveFeature.phoneVerification,
        LiveFeature.profile,
      });
      for (final f in [
        LiveFeature.savedBriefsSync,
        LiveFeature.closeRemindersSync,
      ]) {
        expect(f.closure, {f, LiveFeature.briefs});
      }
      expect(LiveFeature.uploads.closure, {
        LiveFeature.uploads,
        LiveFeature.submit,
        LiveFeature.briefs,
        LiveFeature.profile,
      });
      expect(LiveFeature.etags.closure, {LiveFeature.etags});
      expect(LiveFeature.config.closure, {LiveFeature.config});
      final backend = _decide(_health(off: {LiveFeature.withdrawals}));
      expect(backend.isLive(LiveFeature.withdrawalPin), isFalse);
      expect(backend.isLive(LiveFeature.uploads), isTrue);
    });

    test('an older API without the four new features runs the rest', () {
      final body = _health();
      final features =
          ((body['data'] as Map)['mobile'] as Map)['features'] as Map;
      for (final name in [
        'avatar',
        'bankAccounts',
        'leaderboard',
        'referrals',
      ]) {
        features.remove(name);
      }
      final backend = _decide(body);
      expect(backend.isLive(LiveFeature.wallet), isTrue);
      for (final f in [
        LiveFeature.avatar,
        LiveFeature.bankAccounts,
        LiveFeature.leaderboard,
        LiveFeature.referrals,
      ]) {
        expect(backend.isLive(f), isFalse, reason: f.name);
        expect(backend.isPaused(f), isTrue, reason: f.name);
      }
    });

    test('a feature on its own without what it needs stays preview', () {
      expect(Backend.of({LiveFeature.withdrawals}), Backend.preview);
      expect(
        Backend.of({LiveFeature.withdrawals, LiveFeature.wallet}),
        Backend.preview,
      );
      expect(
        Backend.of({
          LiveFeature.withdrawals,
          LiveFeature.wallet,
          LiveFeature.profile,
        }).names,
        ['profile', 'wallet', 'withdrawals'],
      );
    });
  });

  group('the preview build', () {
    test('stays preview whatever is kept or asked', () async {
      SharedPreferences.setMockInitialValues({
        LiveBackendNotifier.decidedKey: ['profile', 'briefs'],
      });
      final prefs = await SharedPreferences.getInstance();
      final health = _Health(() async => _report(_health()));
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          healthServiceProvider.overrideWithValue(health),
        ],
      );
      addTearDown(c.dispose);
      final backend = c.read(backendProvider.notifier);
      await backend.check();
      await backend.lock();
      backend.resumed();
      expect(c.read(backendProvider), Backend.preview);
      expect(backend.checking, isFalse);
      expect(backend.checkedAt, isNull);
      expect(health.calls, 0);
      expect(prefs.getStringList(LiveBackendNotifier.launchedKey), isNull);
    });
  });

  group('a live launch', () {
    late DateTime now;
    late _Health health;
    late SharedPreferences prefs;
    late List<String> forgot;

    setUp(() async {
      now = DateTime(2026, 10, 17, 9, 41);
      health = _Health(() async => _report(_health()));
      forgot = [];
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    /// A launch on the same phone: a new container on the kept prefs.
    ProviderContainer launch() {
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          clockProvider.overrideWithValue(() => now),
          healthServiceProvider.overrideWithValue(health),
          backendProvider.overrideWith(
            () => LiveBackendNotifier(
              forgetPreview: (ref) async => forgot.add('preview'),
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    group('forced from Try notifications', () {
      test('a forced preview wins over a ready API on this launch and the '
          'next, while health still keeps its answer', () async {
        final c = launch();
        final backend = c.read(backendProvider.notifier);
        await backend.check();
        await backend.lock();
        expect(c.read(backendProvider), _all);

        await backend.force(preview: true);
        expect(c.read(backendProvider), Backend.preview);
        expect(prefs.getString(LiveBackendNotifier.forcedKey), 'preview');
        await backend.check();
        expect(c.read(backendProvider), Backend.preview);
        await backend.lock();
        expect(prefs.getStringList(LiveBackendNotifier.launchedKey), isEmpty);
        expect(prefs.getStringList(LiveBackendNotifier.decidedKey), _all.names);

        final next = launch();
        expect(next.read(backendProvider), Backend.preview);
        await next.read(backendProvider.notifier).check();
        expect(next.read(backendProvider), Backend.preview);
        expect(next.read(backendProvider.notifier).forcedPreview, isTrue);
      });

      test('switching back to live hands the mode to health, which still '
          'needs the API ready', () async {
        final c = launch();
        final backend = c.read(backendProvider.notifier);
        await backend.force(preview: true);
        await backend.lock();

        health.answer = () async => _report(_health(ready: false));
        await backend.force(preview: false);
        expect(prefs.getString(LiveBackendNotifier.forcedKey), isNull);
        await backend.check();
        expect(c.read(backendProvider), Backend.preview);

        health.answer = () async => _report(_health());
        await backend.check();
        expect(c.read(backendProvider), _all);
        await backend.lock();
        expect(
          prefs.getStringList(LiveBackendNotifier.launchedKey),
          _all.names,
        );
      });

      test('the preview build cannot be forced', () async {
        final c = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(c.dispose);
        expect(c.read(backendProvider.notifier).canForce, isFalse);
      });
    });

    test('with nothing kept and no answer, it is preview', () async {
      health.answer = () => Future.error(const ApiUnreachable());
      final c = launch();
      final backend = c.read(backendProvider.notifier);
      await backend.check();
      await backend.lock();
      expect(c.read(backendProvider), Backend.preview);
      expect(backend.checkedAt, isNull);
      expect(prefs.getStringList(LiveBackendNotifier.decidedKey), isNull);
      expect(prefs.getStringList(LiveBackendNotifier.launchedKey), isEmpty);
    });

    test('an answer before the lock decides the launch, and is kept for '
        'the next', () async {
      health.answer = () async => _report(_health(off: {LiveFeature.wallet}));
      final c = launch();
      final backend = c.read(backendProvider.notifier);
      expect(c.read(backendProvider), Backend.preview);
      await backend.check();
      expect(c.read(backendProvider).isLive(LiveFeature.briefs), isTrue);
      expect(c.read(backendProvider).isLive(LiveFeature.wallet), isFalse);
      expect(prefs.getStringList(LiveBackendNotifier.decidedKey), [
        'profile',
        'briefs',
        'submit',
        'submissions',
        'notifications',
        'avatar',
        'leaderboard',
        'referrals',
        'support',
        'polls',
        'businessNote',
        'avatarPhoto',
        'phoneVerification',
        'savedBriefsSync',
        'closeRemindersSync',
        'uploads',
        'etags',
        'config',
        'briefAudience',
        'helpAuthorNames',
        'supportChannels',
        'pollQuestions',
        'genderRequired',
        'supportDocuments',
      ]);
      expect(backend.checkedAt, now);
      await backend.lock();
      expect(prefs.getStringList(LiveBackendNotifier.launchedKey), [
        'profile',
        'briefs',
        'submit',
        'submissions',
        'notifications',
        'avatar',
        'leaderboard',
        'referrals',
        'support',
        'polls',
        'businessNote',
        'avatarPhoto',
        'phoneVerification',
        'savedBriefsSync',
        'closeRemindersSync',
        'uploads',
        'etags',
        'config',
        'briefAudience',
        'helpAuthorNames',
        'supportChannels',
        'pollQuestions',
        'genderRequired',
        'supportDocuments',
      ]);
    });

    test('a failed check keeps what the last answer decided', () async {
      await launch().read(backendProvider.notifier).check();

      health.answer = () => Future.error(const ApiUnreachable());
      now = now.add(const Duration(days: 1));
      final c = launch();
      expect(c.read(backendProvider), _all);
      await c.read(backendProvider.notifier).check();
      await c.read(backendProvider.notifier).lock();
      expect(c.read(backendProvider), _all);
      expect(
        c.read(backendProvider.notifier).checkedAt,
        now.subtract(const Duration(days: 1)),
      );
    });

    test('a kept decision is weighed again before it is used', () async {
      await prefs.setStringList(LiveBackendNotifier.decidedKey, [
        'withdrawals',
        'wallet',
        'briefs',
        'retired',
      ]);
      health.answer = () => Future.error(const ApiUnreachable());
      final c = launch();
      expect(c.read(backendProvider), const Backend({LiveFeature.briefs}));
    });

    test('the lock fixes the mode; answers after it set up the next '
        'launch', () async {
      final c = launch();
      final backend = c.read(backendProvider.notifier);
      await backend.check();
      await backend.lock();
      expect(c.read(backendProvider), _all);

      health.answer = () async => _report(_health(ready: false));
      await backend.check();
      expect(c.read(backendProvider), _all);
      expect(prefs.getStringList(LiveBackendNotifier.decidedKey), isEmpty);

      final next = launch();
      expect(next.read(backendProvider), Backend.preview);
    });

    test('a check that answers only after the lock leaves the launch on '
        'what was kept', () async {
      final answer = Completer<HealthReport>();
      health.answer = () => answer.future;
      final c = launch();
      final backend = c.read(backendProvider.notifier);
      final listened = <Backend>[];
      c.listen(backendProvider, (_, next) => listened.add(next));
      unawaited(backend.check());
      expect(backend.checking, isTrue);
      await backend.settled(const Duration(milliseconds: 10));
      await backend.lock();

      answer.complete(_report(_health()));
      await pumpEventQueue();
      expect(backend.checking, isFalse);
      expect(c.read(backendProvider), Backend.preview);
      expect(listened, isEmpty);
      expect(prefs.getStringList(LiveBackendNotifier.launchedKey), isEmpty);
      expect(launch().read(backendProvider), _all);
    });

    test('a second lock changes nothing', () async {
      final c = launch();
      final backend = c.read(backendProvider.notifier);
      await backend.check();
      await backend.lock();
      health.answer = () async => _report(_health(ready: false));
      await backend.check();
      await backend.lock();
      expect(c.read(backendProvider), _all);
      expect(prefs.getStringList(LiveBackendNotifier.launchedKey), _all.names);
    });

    test('a resume asks again only once 15 minutes have passed', () async {
      final c = launch();
      final backend = c.read(backendProvider.notifier);
      await backend.check();
      await backend.lock();
      now = now.add(const Duration(minutes: 14, seconds: 59));
      backend.resumed();
      expect(health.calls, 1);
      now = now.add(const Duration(seconds: 1));
      backend.resumed();
      await pumpEventQueue();
      expect(health.calls, 2);
      expect(backend.checkedAt, now);
    });

    group('preview records', () {
      /// One launch after another, health answering each with [modes].
      Future<void> launches(List<Backend> modes) async {
        for (final mode in modes) {
          health.answer = () async => HealthReport(
            ready: !mode.isPreview,
            contract: 1,
            features: mode.live,
          );
          final backend = launch().read(backendProvider.notifier);
          await backend.check();
          await backend.lock();
        }
      }

      test('are cleared once, on the first launch to run anything '
          'live', () async {
        await launches([Backend.preview, Backend.preview]);
        expect(forgot, isEmpty);
        await launches([
          _all,
          _all,
          const Backend({LiveFeature.briefs}),
        ]);
        expect(forgot, ['preview']);
      });

      test('are cleared after an update from a build that kept no '
          'mode', () async {
        await launches([
          const Backend({LiveFeature.notifications}),
        ]);
        expect(forgot, ['preview']);
      });

      test('are not cleared again by a live launch after a preview one, so '
          'what was saved live stays', () async {
        await launches([_all, Backend.preview, _all, Backend.preview, _all]);
        expect(forgot, ['preview']);
        expect(prefs.getBool(LiveBackendNotifier.previewClearedKey), isTrue);
      });

      test(
        'are not cleared again after an update from a build that kept no '
        'record of the clear, even when its first launch is preview',
        () async {
          await prefs.setStringList(
            LiveBackendNotifier.launchedKey,
            _all.names,
          );
          await launches([Backend.preview, _all]);
          expect(forgot, isEmpty);
        },
      );

      test('stay when a live launch goes back to preview', () async {
        await launches([_all]);
        forgot.clear();
        await launches([Backend.preview]);
        expect(forgot, isEmpty);
        expect(prefs.getStringList(LiveBackendNotifier.launchedKey), isEmpty);
      });

      test('a clear that fails is tried again next launch', () async {
        var fail = true;
        final c = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            clockProvider.overrideWithValue(() => now),
            healthServiceProvider.overrideWithValue(health),
            backendProvider.overrideWith(
              () => LiveBackendNotifier(
                forgetPreview: (ref) async {
                  forgot.add('preview');
                  if (fail) throw Exception('disk full');
                },
              ),
            ),
          ],
        );
        addTearDown(c.dispose);
        await c.read(backendProvider.notifier).check();
        await c.read(backendProvider.notifier).lock();
        expect(c.read(backendProvider), _all);
        expect(prefs.getStringList(LiveBackendNotifier.launchedKey), isNull);
        fail = false;

        final next = launch();
        await next.read(backendProvider.notifier).check();
        await next.read(backendProvider.notifier).lock();
        expect(forgot, ['preview', 'preview']);
        expect(
          prefs.getStringList(LiveBackendNotifier.launchedKey),
          _all.names,
        );
      });
    });
  });

  group('leaving preview', () {
    const plugin = MethodChannel('dexterous.com/flutter/local_notifications');
    final kept = <String, Object>{
      'session.signedIn': true,
      'session.onboardingDone': true,
      'session.firstTipSeen': true,
      'session.name': 'Adaeze Okafor',
      'session.firstName': 'Adaeze',
      'onboarding.draft': jsonEncode({'state': 'Lagos'}),
      'avatar.look': '{}',
      'notifications.asked': true,
      'splash.lit': true,
      'outcomes.celebrated': ['s1'],
    };

    testWidgets('clears exactly the stores that hold preview records, and '
        'the reminders scheduled for them', (tester) async {
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      final messenger = tester.binding.defaultBinaryMessenger;
      final reminder = stableId('${closeReminderPrefix}c5');
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(plugin, (call) async {
        calls.add(call);
        if (call.method == 'pendingNotificationRequests') {
          return [
            {
              'id': reminder,
              'payload': '{"key":"${closeReminderPrefix}c5","route":"/home"}',
            },
            {'id': 7, 'payload': '{"key":"payout:w3","route":"/home"}'},
          ];
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(plugin, null));

      final data = DemoData();
      SharedPreferences.setMockInitialValues({
        ...kept,
        SavedBriefsNotifier.key: jsonEncode([
          for (final b in data.briefs.take(2)) b.toJson(),
        ]),
        CloseRemindersNotifier.key: ['c5'],
        AccountDetailsNotifier.key: jsonEncode(
          const AccountDetails(phone: '+234 801 234 5678'),
        ),
        'submit.draft.c5': '{"title":"Sunday"}',
        'submit.draft.c4': '{}',
      });
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          repositoryProvider.overrideWithValue(_LiveRepository()),
          healthServiceProvider.overrideWithValue(
            _Health(() async => _report(_health())),
          ),
          backendProvider.overrideWith(
            () => LiveBackendNotifier(forgetPreview: forgetPreviewRecords),
          ),
          surfacesProvider.overrideWithValue(
            Surfaces(
              router: GoRouter(
                routes: [
                  GoRoute(path: '/', builder: (_, _) => const SizedBox()),
                ],
              ),
              signedIn: () => true,
              tabRoots: const {'/'},
            ),
          ),
        ],
      );
      addTearDown(c.dispose);

      expect(await c.read(savedBriefsProvider.future), hasLength(2));
      expect(await c.read(closeRemindersProvider.future), {'c5'});

      final backend = c.read(backendProvider.notifier);
      await tester.runAsync(() async {
        await backend.check();
        final locking = backend.lock();
        expect(prefs.getString(SavedBriefsNotifier.key), isNull);
        expect(prefs.getStringList(CloseRemindersNotifier.key), isNull);
        expect(prefs.getString(AccountDetailsNotifier.key), isNull);
        expect(prefs.getKeys().where((k) => k.startsWith('submit.')), isEmpty);
        await locking;
      });

      expect(prefs.getKeys(), {
        ...kept.keys,
        LiveBackendNotifier.decidedKey,
        LiveBackendNotifier.checkedAtKey,
        LiveBackendNotifier.launchedKey,
        LiveBackendNotifier.previewClearedKey,
      });
      for (final MapEntry(:key, :value) in kept.entries) {
        expect(prefs.get(key), value, reason: key);
      }
      expect(await c.read(savedBriefsProvider.future), isEmpty);
      expect(await c.read(closeRemindersProvider.future), isEmpty);
      final cancelled = calls.where((call) => call.method == 'cancel');
      expect(cancelled.map((call) => (call.arguments as Map)['id']), [
        reminder,
      ]);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });
}
