import '../core/deadline.dart';
import '../core/deep_links.dart';
import '../core/money.dart';
import '../data/models.dart';
import '../data/polls_data.dart';
import 'surface_copy.dart';
import 'surface_format.dart';

class WidgetBriefRow {
  const WidgetBriefRow({
    required this.id,
    required this.title,
    required this.meta,
    required this.thumb,
    required this.route,
    this.closesAt,
    this.live,
  });

  final String id;
  final String title;
  final String meta;

  /// Name of the rasterised cover + logo PNG the native side loads.
  final String thumb;
  final String route;

  /// When the brief closes, for a row that counts down live (1340:28510).
  final DateTime? closesAt;

  /// [meta] with `%s` where the live countdown goes.
  final String? live;

  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'meta': meta,
    'thumb': thumb,
    'link': DeepLinks.uri(route).toString(),
    'closesAt': ?closesAt?.millisecondsSinceEpoch,
    'live': ?live,
  };
}

/// What the two home screen widgets (Exp/Widget Medium and Small, 347:16187,
/// 350:17652) show. The native side draws it as is and never computes.
class WidgetSnapshot {
  const WidgetSnapshot({
    required this.closingSoon,
    required this.pollsOpen,
    required this.pollsLabel,
    required this.pollsLine,
    required this.pollsRoute,
    required this.closingRoute,
    this.pollsClosesAt,
    this.pollsLive,
  });

  final List<WidgetBriefRow> closingSoon;
  final int pollsOpen;
  final String pollsLabel;
  final String? pollsLine;
  final String pollsRoute;
  final String closingRoute;

  /// The live version of [pollsLine], counting down to [pollsClosesAt].
  final DateTime? pollsClosesAt;
  final String? pollsLive;

  /// Rows the Medium widget shows at once; Android turns to the next
  /// [medium] every few seconds, up to [pages] of them (1340:28717).
  static const medium = 2;
  static const pages = 2;

  /// A brief closer than this to its close counts down live.
  static const liveWithin = Duration(hours: 24);

  static WidgetSnapshot of({
    required List<Brief> briefs,
    required List<PollBusiness> polls,
    required DateTime now,
    bool showPolls = true,
  }) {
    final closing = briefs.where((b) {
      final left = timeLeft(b.deadline, now);
      return b.isLive &&
          left != null &&
          left > Duration.zero &&
          left <= DeadlineRules.closingSoon;
    }).toList()..sort((a, b) => a.deadline!.compareTo(b.deadline!));
    bool live(Brief b) => timeLeft(b.deadline, now)! < liveWithin;
    final rows = [
      for (final b in closing.take(medium * pages))
        WidgetBriefRow(
          id: b.id,
          title: b.title,
          meta: SurfaceCopy.briefMeta(
            '${leftShort(timeLeft(b.deadline, now)!)} left',
            rewardPool(b.rewardPoolKobo),
          ),
          thumb: thumbName(brandOfBrief(b).slug),
          route: DeepLinks.brief(b.id),
          closesAt: live(b) ? b.deadline : null,
          live: live(b)
              ? SurfaceCopy.briefMeta(
                  '%s left',
                  _literal(rewardPool(b.rewardPoolKobo)),
                )
              : null,
        ),
    ];
    final open = showPolls
        ? polls.fold<int>(0, (sum, p) => sum + p.unanswered)
        : 0;
    final first = closing.isEmpty ? null : closing.first;
    final firstName = first == null
        ? null
        : first.businessName ?? brandOfBrief(first).label;
    final firstLive = first != null && live(first);
    return WidgetSnapshot(
      closingSoon: rows,
      pollsOpen: open,
      pollsLabel: open == 1
          ? SurfaceCopy.pollsOpenOne
          : SurfaceCopy.pollsOpenMany,
      pollsLine: first == null
          ? null
          : SurfaceCopy.closesIn(
              firstName!,
              leftShort(timeLeft(first.deadline, now)!),
            ),
      pollsRoute: showPolls ? DeepLinks.polls : DeepLinks.home,
      closingRoute: DeepLinks.home,
      pollsClosesAt: firstLive ? first.deadline : null,
      pollsLive: firstLive
          ? SurfaceCopy.closesIn(_literal(firstName!), '%s')
          : null,
    );
  }

  Map<String, Object> toJson() => {
    'closingSoon': {
      'title': SurfaceCopy.closingSoon,
      'link': DeepLinks.uri(closingRoute).toString(),
      'rows': [for (final r in closingSoon) r.toJson()],
    },
    'polls': {
      'count': '$pollsOpen',
      'label': pollsLabel,
      'line': ?pollsLine,
      'link': DeepLinks.uri(pollsRoute).toString(),
      'closesAt': ?pollsClosesAt?.millisecondsSinceEpoch,
      'live': ?pollsLive,
    },
  };

  Set<String> get thumbs => {for (final r in closingSoon) r.thumb};
}

String thumbName(String slug) => 'thumb_$slug.png';

/// [text] inside a live format, where a bare `%` would read as a
/// placeholder.
String _literal(String text) => text.replaceAll('%', '%%');

/// Hourly snapshots from [now], so "6h left" keeps counting down and a
/// closed brief drops off while the app is not running. The native side
/// shows the last entry whose `at` has passed; WidgetKit takes the list as
/// its timeline.
class WidgetTimeline {
  const WidgetTimeline(this.entries);

  final List<(DateTime, WidgetSnapshot)> entries;

  static const hours = 12;

  static WidgetTimeline of({
    required List<Brief> briefs,
    required List<PollBusiness> polls,
    required DateTime now,
    bool showPolls = true,
  }) => WidgetTimeline([
    for (var h = 0; h < hours; h++)
      (
        now.add(Duration(hours: h)),
        WidgetSnapshot.of(
          briefs: briefs,
          polls: polls,
          now: now.add(Duration(hours: h)),
          showPolls: showPolls,
        ),
      ),
  ]);

  Map<String, Object> toJson() => {
    'version': 1,
    'entries': [
      for (final (at, snapshot) in entries)
        {'at': at.millisecondsSinceEpoch, ...snapshot.toJson()},
    ],
  };

  Set<String> get thumbs => {for (final (_, s) in entries) ...s.thumbs};
}
