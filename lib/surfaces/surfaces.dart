import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quick_actions/quick_actions.dart';

import '../core/deep_links.dart';
import '../core/flags.dart';
import '../data/demo_data.dart';
import '../data/models.dart';
import '../data/notifications_data.dart';
import '../data/polls_data.dart';
import '../theme/theme.dart';
import 'live_activity.dart';
import 'notification_content.dart';
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
  });

  final List<Brief> briefs;
  final List<PollBusiness> polls;
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

/// Starts the OS surfaces from main.dart and routes their taps. Widget tests
/// never construct it, so no plugin is touched under test.
class Surfaces {
  Surfaces({
    required this.router,
    required this.signedIn,
    required Set<String> tabRoots,
    SurfacesBridge? bridge,
    FlutterLocalNotificationsPlugin? notifications,
    QuickActions? quickActions,
  }) : _bridge = bridge ?? SurfacesBridge(),
       _notifications = notifications ?? FlutterLocalNotificationsPlugin(),
       _quickActions = quickActions ?? const QuickActions(),
       _queue = SurfaceLaunchQueue(readyRoots: tabRoots);

  final GoRouter router;
  final bool Function() signedIn;
  final SurfacesBridge _bridge;
  final FlutterLocalNotificationsPlugin _notifications;
  final QuickActions _quickActions;
  final SurfaceLaunchQueue _queue;

  static const _smallIcon = 'ic_stat_iqly';
  static const _pollCategory = 'poll';

  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> start(SurfaceInputs inputs) async {
    if (!supported) return;
    router.routerDelegate.addListener(_onNavigate);
    _bridge.onLink(_openLink);
    await _initNotifications();
    await _quickActions.initialize(_openLink);
    final link = await _bridge.takeLaunchLink();
    if (link != null) _openLink(link);
    await publish(inputs);
  }

  /// Refreshes the widgets and shortcuts; call when the data behind them
  /// changes (a brief closes, a poll is answered, a draft is saved).
  Future<void> publish(SurfaceInputs inputs) async {
    if (!supported) return;
    await _quickActions.setShortcutItems([
      for (final s in appShortcuts(
        polls: inputs.polls,
        draftBriefId: inputs.draftBriefId,
        showPolls: Flags.polls,
      ))
        ShortcutItem(type: s.type, localizedTitle: s.label, icon: s.icon),
    ]);
    if (!Flags.homeWidgets) return;
    final timeline = WidgetTimeline.of(
      briefs: inputs.briefs,
      polls: inputs.polls,
      now: inputs.now,
      showPolls: Flags.polls,
    );
    final thumbs = <String, Uint8List>{};
    for (final b in inputs.briefs) {
      final brand = brandOfBrief(b);
      final name = thumbName(brand.slug);
      if (timeline.thumbs.contains(name) && !thumbs.containsKey(name)) {
        thumbs[name] = await renderThumb(brand);
      }
    }
    await _bridge.publishWidgets(timeline, thumbs);
  }

  /// The Wallet lane calls this when a withdrawal is asked for and on every
  /// status change: the Live Activity on iOS, the progress notification on
  /// Android.
  Future<void> payoutChanged(Withdrawal w, SurfaceInputs inputs) async {
    if (!supported) return;
    final state = PayoutActivityState.of(w);
    if (Flags.payoutLiveActivity &&
        defaultTargetPlatform == TargetPlatform.iOS) {
      await (state == null
          ? _bridge.endPayoutActivity(w.id)
          : _bridge.payoutActivity(state));
      return;
    }
    final feedId = inputs.feedIdFor(w.id);
    if (!Flags.pushNotifications) return;
    final note = payoutNotification(w, notificationId: feedId);
    if (note == null) {
      await _notifications.cancel(id: stableId('payout:${w.id}'));
      return;
    }
    await show(note);
  }

  Future<void> show(SurfaceNotification note) async {
    if (!supported || !Flags.pushNotifications) return;
    final thumb = note.thumb;
    final largeIcon = thumb == null
        ? null
        : await renderThumb(
            brandOfSlug(thumb),
            radius: SurfaceThumb.notificationRadius,
          );
    await _notifications.show(
      id: note.id,
      title: note.title,
      body: note.body,
      payload: note.payload,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          note.channel.id,
          note.channel.title,
          channelDescription: note.channel.description,
          icon: _smallIcon,
          color: IqColors.brand,
          groupKey: note.group,
          subText: note.subtext,
          styleInformation: BigTextStyleInformation(note.body),
          largeIcon: largeIcon == null
              ? null
              : ByteArrayAndroidBitmap(largeIcon),
          showProgress: note.progress != null,
          maxProgress: note.progressMax,
          progress: note.progress ?? 0,
          ongoing: note.ongoing,
          onlyAlertOnce: note.kind == SurfaceNotificationKind.payout,
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
        ),
      ),
    );
  }

  /// For the Turn on button of the notifications ask (B0 484:23576).
  Future<bool> requestNotificationPermission() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        false;
  }

  Future<void> _initNotifications() async {
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

  void _openLink(String link) {
    final route = DeepLinks.route(link);
    if (route != null) _open(route);
  }

  void _open(String route) {
    final now = _queue.offer(route, location: _location, signedIn: signedIn());
    if (now != null) unawaited(router.push(now));
  }

  void _onNavigate() {
    final route = _queue.onLocation(_location, signedIn: signedIn());
    if (route != null) unawaited(router.push(route));
  }

  String get _location => router.routerDelegate.currentConfiguration.uri.path;
}

/// Null under test and wherever main.dart did not start the surfaces.
final surfacesProvider = Provider<Surfaces?>((ref) => null);
