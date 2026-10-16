import 'dart:convert';

import '../core/deadline.dart';
import '../core/deep_links.dart';
import '../core/money.dart';
import '../data/models.dart';
import '../data/polls_data.dart';
import 'live_activity.dart';
import 'surface_copy.dart';
import 'surface_format.dart';

/// One per switch on Notification preferences (194:9932), so a person who
/// turns a topic off can also mute it in the phone's settings. The Android
/// channels are created natively from the same ids (NotificationChannels.kt).
enum SurfaceChannel {
  closingSoon(
    'closing_soon',
    'Brief closing soon',
    'A day before, and an hour before',
  ),
  results('results', 'Results', 'When the business picks winners'),
  payouts('payouts', 'Withdrawals', 'When money lands or fails'),
  newBriefs('new_briefs', 'New briefs for you', 'At most once a day'),
  polls('polls', 'Polls', 'When a poll opens');

  const SurfaceChannel(this.id, this.title, this.description);

  final String id;
  final String title;
  final String description;
}

enum SurfaceNotificationKind { payout, result, deadline, poll }

class SurfaceAction {
  const SurfaceAction({required this.id, required this.label, this.route});

  final String id;
  final String label;

  /// Null closes the notification without opening the app.
  final String? route;
}

/// A notification as the app words it, before any plugin sees it. Remote
/// push sends the same fields as data, so local and remote look alike.
class SurfaceNotification {
  const SurfaceNotification({
    required this.key,
    required this.kind,
    required this.channel,
    required this.title,
    required this.body,
    required this.route,
    this.subtext,
    this.thumb,
    this.progress,
    this.progressMax = 0,
    this.ongoing = false,
    this.actions = const [],
    this.countdownTo,
  });

  /// Stable per thing reported ("payout:w3"); an update replaces the shown
  /// notification instead of stacking a new one.
  final String key;
  final SurfaceNotificationKind kind;
  final SurfaceChannel channel;
  final String title;
  final String body;
  final String route;
  final String? subtext;

  /// The business (sample art slug) of the Android large icon.
  final String? thumb;
  final int? progress;
  final int progressMax;
  final bool ongoing;
  final List<SurfaceAction> actions;

  /// The close a reminder counts down to: Android shows the time left
  /// ticking, and lets the notification go when it is reached.
  final DateTime? countdownTo;

  int get id => stableId(key);
  String get group => 'net.iqly.${channel.id}';

  String get payload => jsonEncode({
    'route': route,
    'actions': {
      for (final a in actions)
        if (a.route != null) a.id: a.route,
    },
  });

  /// The route a tap or an action opens, from a payload this class wrote.
  static String? routeFor(String? payload, {String? actionId}) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final actions = (map['actions'] as Map?)?.cast<String, dynamic>() ?? {};
      final raw = actionId == null || actionId.isEmpty
          ? map['route']
          : actions[actionId];
      return raw is String ? DeepLinks.route(raw) : null;
    } on FormatException {
      return null;
    }
  }
}

/// FNV-1a, 31 bits: String.hashCode is not promised to be stable across
/// runs, and Android keys notifications by int.
int stableId(String key) {
  var hash = 0x811c9dc5;
  for (final unit in utf8.encode(key)) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

/// Android 350:17527 top and 350:17909: the payout progress. [notificationId]
/// is the feed row it opens (the Notification sub page); a payout the feed
/// has no row for (B6 39:24 lists no request) opens its tracker.
SurfaceNotification? payoutNotification(
  Withdrawal w, {
  required String? notificationId,
}) {
  final state = PayoutActivityState.of(w, notificationId: notificationId);
  if (state == null) return null;
  return SurfaceNotification(
    key: 'payout:${w.id}',
    kind: SurfaceNotificationKind.payout,
    channel: SurfaceChannel.payouts,
    title: state.headline,
    body: state.finished
        ? state.detail
        : SurfaceCopy.payoutDetailAndroid(w.destination ?? ''),
    subtext: SurfaceCopy.payoutSubtext,
    route: notificationId == null
        ? DeepLinks.withdrawal(w.id)
        : DeepLinks.notification(notificationId),
    progress: state.stepNumber,
    progressMax: PayoutActivityState.stepCount,
    ongoing: !state.finished,
  );
}

/// 347:16090 second banner, 350:17527 third: an award landed.
SurfaceNotification resultNotification(
  LedgerEntry award,
  Submission submission,
  Brief brief, {
  required String notificationId,
}) => SurfaceNotification(
  key: 'result:${award.id}',
  kind: SurfaceNotificationKind.result,
  channel: SurfaceChannel.results,
  title: SurfaceCopy.youWon(naira(award.amountKobo)),
  body: SurfaceCopy.wasPicked(submission.title),
  route: DeepLinks.notification(notificationId),
  thumb: brandOfBrief(brief).slug,
);

/// 347:16090 third banner: a draft on a brief that is closing.
SurfaceNotification? draftNotification(
  Brief brief,
  DateTime now, {
  required String notificationId,
}) {
  final left = timeLeft(brief.deadline, now);
  if (left == null || left <= Duration.zero || !brief.isLive) return null;
  return SurfaceNotification(
    key: 'deadline:${brief.id}',
    kind: SurfaceNotificationKind.deadline,
    channel: SurfaceChannel.closingSoon,
    title: SurfaceCopy.draftWaiting(brief.businessName),
    body: SurfaceCopy.draftLeft(leftLong(left)),
    route: DeepLinks.notification(notificationId),
    thumb: brandOfBrief(brief).slug,
    countdownTo: brief.deadline,
  );
}

/// 347:16090 first banner, 350:17527 second (Expanded, with actions).
SurfaceNotification? pollNotification(PollBusiness business) {
  final open = business.polls.where((p) => !p.voted).toList();
  if (open.isEmpty) return null;
  final route = DeepLinks.poll(business.id);
  return SurfaceNotification(
    key: 'poll:${business.id}',
    kind: SurfaceNotificationKind.poll,
    channel: SurfaceChannel.polls,
    title: SurfaceCopy.newPoll(business.name),
    body: '${open.first.question} ${SurfaceCopy.pollTakes}',
    route: route,
    thumb: brandOf(business.name).slug,
    actions: [
      SurfaceAction(id: 'vote', label: SurfaceCopy.voteNow, route: route),
      const SurfaceAction(id: 'later', label: SurfaceCopy.remindMeLater),
    ],
  );
}
