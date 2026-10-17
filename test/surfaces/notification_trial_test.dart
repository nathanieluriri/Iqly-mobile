import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/surfaces/notification_content.dart';
import 'package:iqly_mobile/surfaces/notification_sounds.dart';
import 'package:iqly_mobile/surfaces/surface_samples.dart';
import 'package:iqly_mobile/surfaces/surfaces.dart';

const _plugin = MethodChannel('dexterous.com/flutter/local_notifications');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 10, 3, 9, 41);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> shown;
  late List<MethodCall> calls;
  var pending = <Map<String, Object?>>[];

  setUp(() {
    shown = [];
    calls = [];
    pending = [];
    messenger.setMockMethodCallHandler(_plugin, (call) async {
      calls.add(call);
      if (call.method == 'show') shown.add(call);
      if (call.method == 'pendingNotificationRequests') return pending;
      return null;
    });
    messenger.setMockMethodCallHandler(
      const MethodChannel(SurfacesBridge.name),
      (call) async => throw MissingPluginException(),
    );
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(_plugin, null);
    messenger.setMockMethodCallHandler(
      const MethodChannel(SurfacesBridge.name),
      null,
    );
  });

  Surfaces surfaces({bool Function(SurfaceChannel)? channelOn}) => Surfaces(
    router: GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const SizedBox())],
    ),
    signedIn: () => true,
    tabRoots: const {'/'},
    channelOn: channelOn,
  );

  Brief closingIn(String id, Duration left) {
    final b = DemoData(now: DateTime.now()).briefs.firstWhere((b) => b.isLive);
    return Brief(
      id: id,
      title: b.title,
      body: b.body,
      tier: b.tier,
      category: b.category,
      rewardPoolKobo: b.rewardPoolKobo,
      status: b.status,
      deadline: DateTime.now().add(left),
      businessName: 'Sunline',
      createdAt: b.createdAt,
    );
  }

  Map<String, Object?> details(MethodCall call) =>
      ((call.arguments as Map)['platformSpecifics'] as Map)
          .cast<String, Object?>();

  group('the B18 and B19 examples on their sample records', () {
    final samples = SurfaceSamples(now);

    test('the payout moves from Requested to Sent to Arrived', () {
      final steps = [
        for (final w in samples.payoutSteps)
          payoutNotification(w, notificationId: null)!,
      ];
      expect(
        [for (final n in steps) n.title],
        [
          '₦10,000.00 on its way',
          '₦10,000.00 on its way',
          '₦10,000.00 paid out',
        ],
      );
      expect(
        steps.first.body,
        'To Access Bank ••6789 · usually within '
        'minutes, up to 24h',
      );
      expect([for (final n in steps) n.progress], [1, 2, 3]);
      expect([for (final n in steps) n.ongoing], [true, true, false]);
      expect({for (final n in steps) n.id}, hasLength(1));
    });

    test('the poll, the win and the draft read as the frames do', () {
      expect(samples.poll.title, 'New poll from Orchid Foods');
      expect(samples.poll.body, endsWith('Takes 10 seconds.'));
      expect(
        [for (final a in samples.poll.actions) a.label],
        ['Vote now', 'Remind me later'],
      );
      expect(samples.won.title, 'You won ₦12,500.00');
      expect(
        samples.won.body,
        '"Sunday is data day" was picked. It is in your wallet.',
      );
      expect(samples.draft.title, 'Your Sunline draft is waiting');
      expect(
        samples.draft.body,
        '6 hours left to send it. Pick up where you stopped.',
      );
      expect(samples.draft.countdownTo, now.add(const Duration(hours: 6)));
    });
  });

  testWidgets('Android: the draft counts down to the close, and money and '
      'results stay private on the lock screen', (tester) async {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    final samples = SurfaceSamples(DateTime.now());
    await tester.runAsync(() async {
      await surfaces().show(samples.draft);
      await surfaces().show(samples.won);
      await surfaces().show(samples.poll);
    });
    final draft = details(shown[0]);
    expect(draft['usesChronometer'], isTrue);
    expect(draft['chronometerCountDown'], isTrue);
    expect(draft['when'], samples.draft.countdownTo!.millisecondsSinceEpoch);
    expect(draft['category'], 'reminder');
    expect(draft['timeoutAfter'], greaterThan(0));
    expect(draft['visibility'], NotificationVisibility.public.index);

    final won = details(shown[1]);
    expect(won['usesChronometer'], isFalse);
    expect(won['visibility'], NotificationVisibility.private.index);
    expect(won['category'], 'status');

    final poll = details(shown[2]);
    expect(poll['category'], 'recommendation');
    expect((poll['actions'] as List).length, 2);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('iOS: money and a closing draft are Time Sensitive, and every '
      'banner shows while iQLY is open', (tester) async {
    IOSFlutterLocalNotificationsPlugin.registerWith();
    final samples = SurfaceSamples(DateTime.now());
    await tester.runAsync(() async {
      await surfaces().show(samples.draft);
      await surfaces().show(samples.won);
    });
    final draft = details(shown[0]);
    expect(draft['interruptionLevel'], InterruptionLevel.timeSensitive.index);
    expect(draft['presentBanner'], isTrue);
    expect(draft['threadIdentifier'], 'net.iqly.closing_soon');
    expect(
      details(shown[1])['interruptionLevel'],
      InterruptionLevel.active.index,
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('an iPhone whose build has no Live Activity gets the payout '
      'as a notification instead', (tester) async {
    IOSFlutterLocalNotificationsPlugin.registerWith();
    final samples = SurfaceSamples(DateTime.now());
    await tester.runAsync(
      () => surfaces().payoutChanged(samples.payoutSteps.first, samples.inputs),
    );
    final call = shown.single.arguments as Map;
    expect(call['title'], '₦10,000.00 on its way');
    expect(
      details(shown.single)['interruptionLevel'],
      InterruptionLevel.timeSensitive.index,
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Remind me lands an hour before the close, counts down to it, '
      'and drops reminders that are off', (tester) async {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    final stale = stableId('${closeReminderPrefix}gone');
    pending = [
      {
        'id': stale,
        'payload': '{"key":"${closeReminderPrefix}gone","route":"/home"}',
      },
      {'id': 7, 'payload': '{"key":"payout:w3","route":"/home"}'},
    ];
    await tester.runAsync(
      () => surfaces().syncCloseReminders([
        closingIn('soon', const Duration(hours: 5)),
        closingIn('too-late', const Duration(minutes: 30)),
      ]),
    );
    final scheduled = calls.where((c) => c.method == 'zonedSchedule').toList();
    expect(scheduled, hasLength(1));
    final args = scheduled.single.arguments as Map;
    expect(args['title'], 'Sunline closes in 1 hour');
    final android = details(scheduled.single);
    expect(android['channelId'], 'closing_soon_v2');
    expect(android['chronometerCountDown'], isTrue);
    expect(android['timeoutAfter'], closeReminderLead.inMilliseconds);
    expect(android['sound'], IqSound.sirenWhistle.resource);
    final at = DateTime.parse(args['scheduledDateTime'] as String);
    expect(at.difference(DateTime.now()).inMinutes, inInclusiveRange(239, 240));
    final cancelled = calls.where((c) => c.method == 'cancel').toList();
    expect(cancelled.map((c) => (c.arguments as Map)['id']), [stale]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a topic turned off in preferences stays quiet', (tester) async {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    final samples = SurfaceSamples(DateTime.now());
    final quiet = surfaces(
      channelOn: (channel) => channel != SurfaceChannel.results,
    );
    await tester.runAsync(() async {
      await quiet.show(samples.won);
      await quiet.show(samples.draft);
      await surfaces(channelOn: (_) => false)
          .syncCloseReminders([closingIn('soon', const Duration(hours: 5))]);
    });
    expect(shown.map((c) => details(c)['channelId']), ['closing_soon_v2']);
    expect(calls.where((c) => c.method == 'zonedSchedule'), isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Try notifications lands every sample, even a topic turned off '
      'in preferences', (tester) async {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    final trial = NotificationTrial(
      surfaces(channelOn: (_) => false),
      clock: DateTime.now,
    );
    await tester.runAsync(() async {
      await trial.poll();
      await trial.payout();
    });
    expect(shown.map((c) => details(c)['channelId']), [
      'polls_v2',
      'payouts_v2',
      'payouts_v2',
      'payouts_v2',
    ]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
