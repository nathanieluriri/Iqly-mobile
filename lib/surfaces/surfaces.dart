import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/backend.dart';
import '../core/deadline.dart';
import '../core/deep_links.dart';
import '../core/flags.dart';
import '../core/motion.dart';
import '../core/navigation.dart';
import '../core/session.dart';
import '../data/demo_data.dart';
import '../data/live/live_repository.dart';
import '../data/models.dart';
import '../data/notifications_data.dart';
import '../data/polls_data.dart';
import '../data/repository.dart';
import '../theme/theme.dart';
import 'live_activity.dart';
import 'notification_content.dart';
import 'notification_sounds.dart';
import 'shortcuts.dart';
import 'surface_copy.dart';
import 'surface_format.dart';
import 'surface_launch.dart';
import 'surface_thumbs.dart';
import 'widget_snapshot.dart';

/// The method channel the native side answers (MainActivity.kt,
/// ios/RunnerSurfaces/SurfacesChannel.swift). Every call is a no-op where
/// the native half is missing, as on iOS until the extension is set up.
class SurfacesBridge {
  SurfacesBridge([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel(name);

  static const name = 'net.iqly/surfaces';
  final MethodChannel _channel;

  Future<bool> publishWidgets(
    WidgetTimeline timeline,
    Map<String, Uint8List> thumbs,
  ) => _call('publishWidgets', {
    'timeline': timeline.toJson(),
    'thumbs': thumbs,
  });

  Future<bool> payoutActivity(PayoutActivityState state) =>
      _call('payoutActivity', state.toJson());

  Future<bool> endPayoutActivity(String withdrawalId) =>
      _call('endPayoutActivity', {'withdrawalId': withdrawalId});

  Future<String?> takeLaunchLink() async {
    try {
      return await _channel.invokeMethod<String>('takeLaunchLink');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  void onLink(void Function(String link) handler) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openLink' && call.arguments is String) {
        handler(call.arguments as String);
      }
    });
  }

  Future<bool> _call(String method, Object arguments) async {
    try {
      return await _channel.invokeMethod<bool>(method, arguments) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}

/// Everything the surfaces show, read from the sample data until the API
/// serves it.
class SurfaceInputs {
  const SurfaceInputs({
    required this.briefs,
    required this.polls,
    required this.withdrawals,
    required this.feed,
    required this.now,
    this.draftBriefId,
    this.showPolls = true,
  });

  final List<Brief> briefs;
  final List<PollBusiness> polls;

  /// Polls have no API, so a live launch offers none of the preview's.
  final bool showPolls;
  final List<Withdrawal> withdrawals;
  final List<AppNotification> feed;
  final DateTime now;

  /// The draft "Continue my draft" opens. The Figma draft is Sunline's
  /// (347:16090); the Submit lane's draft store replaces it.
  final String? draftBriefId;

  factory SurfaceInputs.demo(DateTime now) {
    final data = DemoData(now: now);
    return SurfaceInputs(
      briefs: data.briefs,
      polls: demoPolls(now),
      withdrawals: data.withdrawals,
      feed: demoNotifications(
        ledger: data.ledger,
        withdrawals: data.withdrawals,
        now: now,
      ),
      now: now,
      draftBriefId: 'c5',
    );
  }

  /// The feed row that reports [entryId], which the push opens.
  String? feedIdFor(String entryId) =>
      feed.where((n) => n.entryId == entryId).firstOrNull?.id;
}

/// What the surfaces show this launch, for main.dart to start and publish
/// them with in place of [SurfaceInputs.demo]. With briefs live the
/// closing-soon widget reads the live briefs (the phone's last copy when
/// the API does not answer) and, with submit live, Continue my draft opens
/// the newest draft on the phone, or is not offered; a live launch that
/// pauses them shows neither. [onPhone] reads only what the phone holds,
/// without asking the API, so a launch link never waits for the network.
/// A live launch offers no polls.
Future<SurfaceInputs> surfaceInputs(
  Reader read,
  DateTime now, {
  bool onPhone = false,
}) async {
  final preview = SurfaceInputs.demo(now);
  final mode = read(liveModeProvider);
  if (mode.isPreview) return preview;
  final repository = read(repositoryProvider);
  var briefs = const <Brief>[];
  if (mode.isLive(LiveFeature.briefs)) {
    briefs =
        await (onPhone && repository is LiveRepository
                ? repository.keptBriefs()
                : repository.briefs())
            .catchError((Object _) => const <Brief>[]);
  }
  String? draft;
  if (mode.isLive(LiveFeature.submit)) {
    try {
      draft = (await repository.drafts()).firstOrNull?.briefId;
    } on Object {
      draft = null;
    }
  }
  return SurfaceInputs(
    briefs: briefs,
    polls: const [],
    showPolls: false,
    withdrawals: preview.withdrawals,
    feed: preview.feed,
    now: now,
    draftBriefId: draft,
  );
}

/// Starts [surfaces] on what the phone holds, so a launch link opens at
/// once, then publishes what the API answers whenever it comes: at launch,
/// after each change of mode and when another account signs in. What was
/// read for an account no longer signed in once it lands is not published.
Future<void> startSurfaces(
  Surfaces surfaces,
  ProviderContainer container,
) async {
  final now = container.read(clockProvider);
  Future<void> publish() async {
    final scope = container.read(accountScopeProvider);
    final inputs = await surfaceInputs(container.read, now());
    if (scope.open) await surfaces.publish(inputs);
  }

  void publishLive() => unawaited(publish());
  await surfaces.start(
    await surfaceInputs(container.read, now(), onPhone: true),
  );
  if (!container.read(liveModeProvider).isPreview) publishLive();
  container.listen(backendProvider, (_, _) => publishLive());
  container.listen(accountProvider, (_, _) => publishLive());
}

/// Starts the OS surfaces from main.dart and routes their taps. Widget tests
/// never construct it, so no plugin is touched under test.
class Surfaces {
  Surfaces({
    required this.router,
    required this.signedIn,
    required Set<String> tabRoots,
    bool Function(SurfaceChannel channel)? channelOn,
    bool Function()? vibrate,
    SurfacesBridge? bridge,
    FlutterLocalNotificationsPlugin? notifications,
    QuickActions? quickActions,
  }) : _bridge = bridge ?? SurfacesBridge(),
       _notifications = notifications ?? FlutterLocalNotificationsPlugin(),
       _quickActions = quickActions ?? const QuickActions(),
       _channelOn = channelOn ?? ((_) => true),
       _vibrate = vibrate ?? (() => IqHaptics.enabled),
       _queue = SurfaceLaunchQueue(readyRoots: tabRoots);

  final GoRouter router;
  final bool Function() signedIn;
  final SurfacesBridge _bridge;
  final FlutterLocalNotificationsPlugin _notifications;
  final QuickActions _quickActions;
  final bool Function(SurfaceChannel channel) _channelOn;

  /// The Haptics switch: while it is off, notifications go to the quiet
  /// twin of their channel, which never vibrates.
  final bool Function() _vibrate;
  final SurfaceLaunchQueue _queue;

  static const _smallIcon = 'ic_stat_iqly';
  static const _sampleKey = 'sample';
  static const _pollCategory = 'poll';

  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Each step runs even when one before it fails, so a notification fault
  /// cannot take the shortcuts and widgets down with it.
  Future<void> start(SurfaceInputs inputs) async {
    if (!supported) return;
    router.routerDelegate.addListener(_onNavigate);
    _bridge.onLink(_openLink);
    await _guard('notifications', _initNotifications);
    await _guard('shortcuts', () => _quickActions.initialize(_openLink));
    final link = await _bridge.takeLaunchLink();
    if (link != null) _openLink(link);
    await _guard('widgets', () => publish(inputs));
  }

  static Future<void> _guard(String what, Future<void> Function() step) async {
    try {
      await step();
    } on Object catch (error, stack) {
      debugPrint('Surfaces: $what failed: $error');
      debugPrintStack(stackTrace: stack);
    }
  }

  /// Refreshes the widgets and shortcuts; call when the data behind them
  /// changes (a brief closes, a poll is answered, a draft is saved). True
  /// when the phone has widgets to draw them.
  Future<bool> publish(SurfaceInputs inputs) async {
    if (!supported) return false;
    await _quickActions.setShortcutItems([
      for (final s in appShortcuts(
        polls: inputs.polls,
        draftBriefId: inputs.draftBriefId,
        showPolls: Flags.polls && inputs.showPolls,
      ))
        ShortcutItem(type: s.type, localizedTitle: s.label, icon: s.icon),
    ]);
    if (!Flags.homeWidgets) return false;
    final timeline = WidgetTimeline.of(
      briefs: inputs.briefs,
      polls: inputs.polls,
      now: inputs.now,
      showPolls: Flags.polls && inputs.showPolls,
    );
    final thumbs = <String, Uint8List>{};
    for (final b in inputs.briefs) {
      final brand = brandOfBrief(b);
      final name = thumbName(brand.slug);
      if (timeline.thumbs.contains(name) && !thumbs.containsKey(name)) {
        thumbs[name] = await renderThumb(brand);
      }
    }
    return _bridge.publishWidgets(timeline, thumbs);
  }

  /// The Wallet lane calls this when a withdrawal is asked for and on every
  /// status change: the Live Activity on iOS, the progress notification on
  /// Android, and on an iPhone whose build has no Live Activity yet.
  Future<void> payoutChanged(
    Withdrawal w,
    SurfaceInputs inputs, {
    bool anyway = false,
  }) async {
    if (!supported) return;
    final feedId = inputs.feedIdFor(w.id);
    final state = PayoutActivityState.of(w, notificationId: feedId);
    if (Flags.payoutLiveActivity &&
        defaultTargetPlatform == TargetPlatform.iOS) {
      final live = await (state == null
          ? _bridge.endPayoutActivity(w.id)
          : _bridge.payoutActivity(state));
      if (live) return;
    }
    if (!Flags.pushNotifications) return;
    final note = payoutNotification(w, notificationId: feedId);
    if (note == null) {
      await _notifications.cancel(id: stableId('payout:${w.id}'));
      return;
    }
    await show(note, anyway: anyway);
  }

  /// [anyway] posts it even when its topic is off in Notification
  /// preferences, as Try notifications does.
  Future<void> show(SurfaceNotification note, {bool anyway = false}) async {
    if (!supported || !Flags.pushNotifications) return;
    if (!anyway && !_channelOn(note.channel)) return;
    await _notifications.show(
      id: note.id,
      title: note.title,
      body: note.body,
      payload: note.payload,
      notificationDetails: await _details(note),
    );
  }

  /// Schedules Remind me for each of [briefs] and drops the reminders of
  /// briefs no longer in it, but for those of the briefs [keep] names,
  /// which stay as they are. Call with every brief that has Remind me on,
  /// as they stand now, so a moved close moves its reminder.
  Future<void> syncCloseReminders(
    Iterable<Brief> briefs, {
    Set<String> keep = const {},
  }) async {
    if (!supported) return;
    final now = DateTime.now();
    final enabled =
        Flags.pushNotifications && _channelOn(SurfaceChannel.closingSoon);
    final wanted = <int>{
      if (enabled)
        for (final id in keep) stableId('$closeReminderPrefix$id'),
    };
    for (final brief in enabled ? briefs : const <Brief>[]) {
      final note = closeReminderNotification(brief);
      final deadline = brief.deadline;
      if (note == null || deadline == null) continue;
      final at = deadline.subtract(closeReminderLead);
      if (!at.isAfter(now)) continue;
      wanted.add(note.id);
      await _notifications.zonedSchedule(
        id: note.id,
        title: note.title,
        body: note.body,
        payload: note.payload,
        scheduledDate: tz.TZDateTime.from(at, tz.UTC),
        notificationDetails: await _details(note, timeout: closeReminderLead),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
    for (final pending in await _notifications.pendingNotificationRequests()) {
      final reminder =
          pending.payload?.contains('"key":"$closeReminderPrefix') ?? false;
      if (reminder && !wanted.contains(pending.id)) {
        await _notifications.cancel(id: pending.id);
      }
    }
  }

  static const _sampleLingers = Duration(minutes: 1);

  /// Try notifications: a notification that plays only [sound]. Samples
  /// share one slot and leave after a minute, so trying all six does not
  /// bury real notifications on the lock screen.
  Future<void> playSample(IqSound sound) async {
    if (!supported) return;
    final vibrate = _vibrate();
    final channelId = sound.sampleChannelIdFor(vibrate: vibrate);
    final channelName = vibrate
        ? 'Sound sample: ${sound.label}'
        : 'Sound sample: ${sound.label}, no vibration';
    await _android?.createNotificationChannel(
      AndroidNotificationChannel(
        channelId,
        channelName,
        description: sound.description,
        importance: Importance.high,
        sound: RawResourceAndroidNotificationSound(sound.resource),
        enableVibration: vibrate,
      ),
    );
    await _notifications.show(
      id: stableId(_sampleKey),
      title: '${sound.isSiren ? 'Siren' : 'Bing'}: ${sound.label}',
      body: sound.description,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          icon: _smallIcon,
          color: _accent,
          importance: Importance.high,
          priority: Priority.high,
          sound: RawResourceAndroidNotificationSound(sound.resource),
          enableVibration: vibrate,
          timeoutAfter: _sampleLingers.inMilliseconds,
        ),
        iOS: DarwinNotificationDetails(
          sound: sound.iosFile,
          presentAlert: true,
          presentBanner: true,
          presentSound: true,
        ),
      ),
    );
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _notifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// [timeout] is how long a scheduled countdown stays up once posted;
  /// shown at once, it runs to the close.
  Future<NotificationDetails> _details(
    SurfaceNotification note, {
    Duration? timeout,
  }) async {
    final countdownTo = note.countdownTo;
    final thumb = note.thumb;
    final largeIcon = thumb == null
        ? null
        : await renderThumb(
            brandOfSlug(thumb),
            radius: SurfaceThumb.notificationRadius,
          );
    final channel = note.channel;
    final vibrate = _vibrate();
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channel.idFor(vibrate: vibrate),
        channel.titleFor(vibrate: vibrate),
        channelDescription: channel.description,
        importance: _importance(channel),
        sound: RawResourceAndroidNotificationSound(channel.sound.resource),
        enableVibration: vibrate,
        icon: _smallIcon,
        color: _accent,
        groupKey: note.group,
        subText: note.subtext,
        styleInformation: BigTextStyleInformation(note.body),
        largeIcon: largeIcon == null ? null : ByteArrayAndroidBitmap(largeIcon),
        showProgress: note.progress != null,
        maxProgress: note.progressMax,
        progress: note.progress ?? 0,
        ongoing: note.ongoing,
        onlyAlertOnce: note.kind == SurfaceNotificationKind.payout,
        priority: _priority(note.kind),
        category: _category(note.kind),
        visibility: _private(channel)
            ? NotificationVisibility.private
            : NotificationVisibility.public,
        when: countdownTo?.millisecondsSinceEpoch,
        showWhen: note.progress == null,
        usesChronometer: countdownTo != null,
        chronometerCountDown: countdownTo != null,
        timeoutAfter:
            timeout?.inMilliseconds ??
            countdownTo
                ?.difference(DateTime.now())
                .inMilliseconds
                .clamp(0, 1 << 31),
        actions: [
          for (final a in note.actions)
            AndroidNotificationAction(
              a.id,
              a.label,
              showsUserInterface: a.route != null,
            ),
        ],
      ),
      iOS: DarwinNotificationDetails(
        threadIdentifier: note.group,
        categoryIdentifier: note.actions.isEmpty ? null : _pollCategory,
        interruptionLevel: _interruption(note.kind),
        sound: channel.sound.iosFile,
        presentAlert: true,
        presentBanner: true,
        presentList: true,
        presentSound: true,
      ),
    );
  }

  /// Android fills the circle around the small icon with this and lets it
  /// show through the icon's cut-outs. It keeps the stored colour across
  /// theme switches and only adjusts it for contrast: the mark's orange
  /// survives both shades, where brand purple came back lavender on dark.
  static const _accent = IqColors.accent;

  static Importance _importance(SurfaceChannel channel) =>
      channel.urgent ? Importance.high : Importance.defaultImportance;

  Future<void> _createChannels() async {
    final android = _android;
    if (android == null) return;
    for (final id in SurfaceChannel.retired) {
      await android.deleteNotificationChannel(channelId: id);
    }
    for (final channel in SurfaceChannel.values) {
      for (final vibrate in const [true, false]) {
        await android.createNotificationChannel(
          AndroidNotificationChannel(
            channel.idFor(vibrate: vibrate),
            channel.titleFor(vibrate: vibrate),
            description: channel.description,
            importance: _importance(channel),
            sound: RawResourceAndroidNotificationSound(channel.sound.resource),
            enableVibration: vibrate,
            ledColor: IqColors.accent,
            enableLights: true,
          ),
        );
      }
    }
  }

  /// Money and a closing draft break through Focus on iOS (Time Sensitive,
  /// once the capability is in the build); results and polls are active.
  static InterruptionLevel _interruption(SurfaceNotificationKind kind) =>
      switch (kind) {
        SurfaceNotificationKind.payout ||
        SurfaceNotificationKind.deadline => InterruptionLevel.timeSensitive,
        SurfaceNotificationKind.result ||
        SurfaceNotificationKind.poll => InterruptionLevel.active,
      };

  static Priority _priority(SurfaceNotificationKind kind) => switch (kind) {
    SurfaceNotificationKind.payout ||
    SurfaceNotificationKind.result => Priority.high,
    SurfaceNotificationKind.deadline ||
    SurfaceNotificationKind.poll => Priority.defaultPriority,
  };

  static AndroidNotificationCategory _category(
    SurfaceNotificationKind kind,
  ) => switch (kind) {
    SurfaceNotificationKind.payout => AndroidNotificationCategory.progress,
    SurfaceNotificationKind.result => AndroidNotificationCategory.status,
    SurfaceNotificationKind.deadline => AndroidNotificationCategory.reminder,
    SurfaceNotificationKind.poll => AndroidNotificationCategory.recommendation,
  };

  /// Money and results stay hidden on a locked Android phone.
  static bool _private(SurfaceChannel channel) =>
      channel == SurfaceChannel.payouts || channel == SurfaceChannel.results;

  Future<void> _initNotifications() async {
    await _createChannels();
    await _notifications.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings(_smallIcon),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: [
            DarwinNotificationCategory(
              _pollCategory,
              actions: [
                DarwinNotificationAction.plain(
                  'vote',
                  SurfaceCopy.voteNow,
                  options: {DarwinNotificationActionOption.foreground},
                ),
                DarwinNotificationAction.plain(
                  'later',
                  SurfaceCopy.remindMeLater,
                ),
              ],
            ),
          ],
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final route = SurfaceNotification.routeFor(
          response.payload,
          actionId: response.actionId,
        );
        if (route != null) _open(route);
      },
    );
    final launch = await _notifications.getNotificationAppLaunchDetails();
    final response = launch?.notificationResponse;
    if (launch?.didNotificationLaunchApp == true && response != null) {
      final route = SurfaceNotification.routeFor(
        response.payload,
        actionId: response.actionId,
      );
      if (route != null) _open(route);
    }
  }

  /// Opens a route or `iqly://app/...` link a push carried, once the
  /// person is signed in and on a tab.
  void openLink(String link) => _openLink(link);

  void _openLink(String link) {
    final route = DeepLinks.route(link);
    if (route != null) _open(route);
  }

  void _open(String route) {
    final now = _queue.offer(route, location: _location, signedIn: signedIn());
    if (now != null) unawaited(router.open(now));
  }

  void _onNavigate() {
    final route = _queue.onLocation(_location, signedIn: signedIn());
    if (route != null) unawaited(router.open(route));
  }

  /// The page at the bottom of the stack: the tab, under whatever is open
  /// over it.
  String get _location =>
      openPages(router.routerDelegate.currentConfiguration)
          .firstOrNull
          ?.location
          .path ??
      '';
}

/// Null under test and wherever main.dart did not start the surfaces.
final surfacesProvider = Provider<Surfaces?>((ref) => null);
