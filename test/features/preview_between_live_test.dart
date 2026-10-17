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
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/drafts_data.dart';
import 'package:iqly_mobile/data/local/local_providers.dart';
import 'package:iqly_mobile/data/local/memory_local_store.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/data/token_store.dart';
import 'package:iqly_mobile/features/discover/discover_state.dart';
import 'package:iqly_mobile/features/drafts/drafts_state.dart';
import 'package:iqly_mobile/features/profile/profile_state.dart';
import 'package:iqly_mobile/surfaces/notification_content.dart';
import 'package:iqly_mobile/surfaces/surfaces.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/live/live_data_fixtures.dart' as data;

const _plugin = MethodChannel('dexterous.com/flutter/local_notifications');

/// The phone across launches: the same settings, local store and
/// scheduled notifications, and an API whose health check can say it is
/// not ready.
class _Phone {
  _Phone(this.prefs);

  final SharedPreferences prefs;
  final store = MemoryLocalStore();
  var ready = true;

  /// What GET /challenges/c_1 answers: the brief, or a server fault.
  var briefAnswers = true;

  /// Nothing answers but the health check.
  var offline = false;

  /// The reminders the OS holds, by notification id.
  final scheduled = <int, String>{};

  /// The live brief, closing in three days whatever day the test runs.
  final live = data.challengeJson({
    'deadline': DateTime.now()
        .add(const Duration(days: 3))
        .toUtc()
        .toIso8601String(),
    'extendedDeadline': null,
    'effectiveDeadline': DateTime.now()
        .add(const Duration(days: 3))
        .toUtc()
        .toIso8601String(),
  });

  late final api = ApiClient(
    tokens: MemoryTokenStore('t'),
    baseUrl: 'https://api.test',
    client: MockClient((request) async {
      switch (request.url.path) {
        case '/health':
          return http.Response(
            jsonEncode({
              'success': ready,
              'data': {
                'ok': ready,
                'db': ready,
                'mobile': {
                  'contract': 1,
                  'ready': ready,
                  'features': {
                    for (final f in LiveFeature.values) f.name: true,
                  },
                },
              },
            }),
            ready ? 200 : 503,
          );
        case '/challenges/c_1':
          if (offline) throw http.ClientException('offline');
          return briefAnswers ? data.ok(live) : data.refused(503, 'DOWN');
      }
      return data.refused(404, 'NOT_FOUND');
    }),
  );

  /// One run of the app: health at the splash, the lock at the hand-off,
  /// then the reminders put in step, as main.dart does.
  Future<ProviderContainer> launch() async {
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        apiClientProvider.overrideWithValue(api),
        localStoreProvider.overrideWithValue(store),
        healthServiceProvider.overrideWithValue(LiveHealthService(api)),
        backendProvider.overrideWith(
          () => LiveBackendNotifier(forgetPreview: forgetPreviewRecords),
        ),
        surfacesProvider.overrideWithValue(
          Surfaces(
            router: GoRouter(
              routes: [GoRoute(path: '/', builder: (_, _) => const SizedBox())],
            ),
            signedIn: () => true,
            tabRoots: const {'/'},
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    final backend = c.read(backendProvider.notifier);
    await backend.check();
    await backend.lock();
    await c.read(closeRemindersProvider.notifier).syncSurfaces();
    return c;
  }

  /// The briefs the OS will remind of.
  List<String> get reminding => [
    for (final payload in scheduled.values)
      (jsonDecode(payload) as Map)['key'] as String,
  ];
}

/// A sample brief open long enough for its reminder to be scheduled.
Future<Brief> _openSample(ProviderContainer c) async => [
  for (final b in await c.read(repositoryProvider).briefs())
    if (b.isLive &&
        b.deadline != null &&
        b.deadline!.isAfter(DateTime.now().add(const Duration(hours: 3))))
      b,
].first;

void main() {
  late _Phone phone;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'session.signedIn': true,
      'session.onboardingDone': true,
      'session.userId': 'u_1',
    });
    phone = _Phone(await SharedPreferences.getInstance());
  });

  void osNotifications(WidgetTester tester) {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_plugin, (call) async {
      final args = call.arguments;
      switch (call.method) {
        case 'zonedSchedule':
          final map = args as Map;
          phone.scheduled[map['id'] as int] = map['payload'] as String;
        case 'cancel':
          phone.scheduled.remove((args as Map)['id']);
        case 'pendingNotificationRequests':
          return [
            for (final MapEntry(:key, :value) in phone.scheduled.entries)
              {'id': key, 'payload': value},
          ];
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(_plugin, null));
  }

  testWidgets('a preview launch between live ones leaves what the person '
      'saved live: the brief, its reminder and the reminder the OS holds', (
    tester,
  ) async {
    osNotifications(tester);
    await tester.runAsync(() async {
      var c = await phone.launch();
      expect(c.read(backendProvider).isPreview, isFalse);
      final brief = (await c.read(repositoryProvider).brief('c_1'))!;
      await c.read(savedBriefsProvider.future);
      await c.read(savedBriefsProvider.notifier).setSaved(brief, true);
      await c.read(closeRemindersProvider.future);
      await c.read(closeRemindersProvider.notifier).setReminder('c_1', true);
      expect(phone.reminding, ['${closeReminderPrefix}c_1']);

      phone.ready = false;
      c = await phone.launch();
      expect(c.read(backendProvider).isPreview, isTrue);
      expect(
        [for (final b in await c.read(savedBriefsProvider.future)) b.id],
        ['c_1'],
      );
      expect(phone.reminding, ['${closeReminderPrefix}c_1']);

      phone.ready = true;
      c = await phone.launch();
      expect(c.read(backendProvider).isPreview, isFalse);
      expect(
        [for (final b in await c.read(savedBriefsProvider.future)) b.id],
        ['c_1'],
      );
      expect(await c.read(closeRemindersProvider.future), {'c_1'});
      expect(phone.reminding, ['${closeReminderPrefix}c_1']);
      expect(
        phone.prefs.getBool(LiveBackendNotifier.previewClearedKey),
        isTrue,
      );
    });
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('what a later preview launch makes never shows as the '
      'person\'s, or fires, in a live launch: a sample brief saved, a '
      'reminder on one, a draft on one', (tester) async {
    osNotifications(tester);
    await tester.runAsync(() async {
      var c = await phone.launch();
      final brief = (await c.read(repositoryProvider).brief('c_1'))!;
      await c.read(savedBriefsProvider.future);
      await c.read(savedBriefsProvider.notifier).setSaved(brief, true);
      await c.read(closeRemindersProvider.future);
      await c.read(closeRemindersProvider.notifier).setReminder('c_1', true);

      phone.ready = false;
      c = await phone.launch();
      final sample = await _openSample(c);
      await c.read(savedBriefsProvider.future);
      await c.read(savedBriefsProvider.notifier).setSaved(sample, true);
      await c.read(closeRemindersProvider.future);
      await c
          .read(closeRemindersProvider.notifier)
          .setReminder(sample.id, true);
      await c.read(draftsProvider.future);
      await c
          .read(draftsProvider.notifier)
          .save(
            Draft(
              briefId: sample.id,
              title: 'Sample',
              answer: 'Sample',
              editedAt: DateTime.now(),
            ),
          );
      expect(
        phone.reminding,
        unorderedEquals([
          '${closeReminderPrefix}c_1',
          '$closeReminderPrefix${sample.id}',
        ]),
      );

      phone.ready = true;
      c = await phone.launch();
      expect(
        [for (final b in await c.read(savedBriefsProvider.future)) b.id],
        ['c_1'],
      );
      expect(await c.read(closeRemindersProvider.future), {'c_1'});
      expect(await c.read(draftsProvider.future), isEmpty);
      expect(phone.reminding, ['${closeReminderPrefix}c_1']);
      expect(
        phone.prefs.getString(SavedBriefsNotifier.key),
        isNot(contains(sample.id)),
      );
      expect(phone.prefs.getStringList(CloseRemindersNotifier.key), ['c_1']);
    });
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a live launch that cannot read a reminded brief keeps its '
      'reminder, and still drops what a preview launch set on a sample '
      'brief', (tester) async {
    osNotifications(tester);
    await tester.runAsync(() async {
      var c = await phone.launch();
      await c.read(closeRemindersProvider.future);
      await c.read(closeRemindersProvider.notifier).setReminder('c_1', true);

      phone.ready = false;
      c = await phone.launch();
      final sample = (await _openSample(c)).id;
      await c.read(closeRemindersProvider.future);
      await c.read(closeRemindersProvider.notifier).setReminder(sample, true);
      expect(phone.reminding, contains('$closeReminderPrefix$sample'));

      phone
        ..ready = true
        ..briefAnswers = false;
      c = await phone.launch();
      expect(await c.read(closeRemindersProvider.future), {'c_1'});
      expect(phone.reminding, ['${closeReminderPrefix}c_1']);
    });
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('offline with no copy of a reminded brief, a live launch '
      'keeps its reminder', (tester) async {
    osNotifications(tester);
    await tester.runAsync(() async {
      var c = await phone.launch();
      await c.read(closeRemindersProvider.future);
      await c.read(closeRemindersProvider.notifier).setReminder('c_1', true);
      expect(phone.reminding, ['${closeReminderPrefix}c_1']);

      phone.offline = true;
      c = await phone.launch();
      expect(c.read(backendProvider).isPreview, isFalse);
      expect(await c.read(closeRemindersProvider.future), {'c_1'});
      expect(phone.reminding, ['${closeReminderPrefix}c_1']);
    });
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  test('the sample briefs are told apart from the API\'s by id', () {
    expect([
      for (final b in DemoData().briefs) DemoData.isSampleBrief(b.id),
    ], everyElement(isTrue));
    expect(DemoData.isSampleBrief('c_1'), isFalse);
    expect(
      DemoData.isSampleBrief('088cea56-d5c8-44b1-9581-b7d17e9299b6'),
      isFalse,
    );
  });
}
