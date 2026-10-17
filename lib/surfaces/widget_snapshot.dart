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
  });

  final String id;
  final String title;
  final String meta;

  /// Name of the rasterised cover + logo PNG the native side loads.
  final String thumb;
  final String route;

  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'meta': meta,
    'thumb': thumb,
    'link': DeepLinks.uri(route).toString(),
  };
}

/// What the two home screen widgets (Exp/Widget Medium and Small, 347:16187,
/// 350:17652) show. The native side draws it as is and never computes; a
/// section with `empty` draws its illustration and that line in place of
/// the rows or the count.
class WidgetSnapshot {
  const WidgetSnapshot({
    required this.closingSoon,
    required this.pollsOpen,
    required this.pollsLabel,
    required this.pollsLine,
    required this.pollsRoute,
    required this.closingRoute,
  });

  final List<WidgetBriefRow> closingSoon;
  final int pollsOpen;
  final String pollsLabel;
  final String? pollsLine;
  final String pollsRoute;
  final String closingRoute;

  static const medium = 2;

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
    final rows = [
      for (final b in closing.take(medium))
        WidgetBriefRow(
          id: b.id,
          title: b.title,
          meta: SurfaceCopy.briefMeta(
            '${leftShort(timeLeft(b.deadline, now)!)} left',
            rewardPool(b.rewardPoolKobo),
          ),
          thumb: thumbName(brandOfBrief(b).slug),
          route: DeepLinks.brief(b.id),
        ),
    ];
    final open = showPolls
        ? polls.fold<int>(
            0,
            (sum, p) =>
                sum + p.polls.where((q) => !q.voted && !q.closedAt(now)).length,
          )
        : 0;
    final first = closing.isEmpty ? null : closing.first;
    return WidgetSnapshot(
      closingSoon: rows,
      pollsOpen: open,
      pollsLabel: open == 1
          ? SurfaceCopy.pollsOpenOne
          : SurfaceCopy.pollsOpenMany,
      pollsLine: first == null
          ? null
          : SurfaceCopy.closesIn(
              first.businessName ?? brandOfBrief(first).label,
              leftShort(timeLeft(first.deadline, now)!),
            ),
      pollsRoute: showPolls ? DeepLinks.polls : DeepLinks.home,
      closingRoute: DeepLinks.home,
    );
  }

  Map<String, Object> toJson() => {
    'closingSoon': {
      'title': SurfaceCopy.closingSoon,
      'link': DeepLinks.uri(closingRoute).toString(),
      'rows': [for (final r in closingSoon) r.toJson()],
      if (closingSoon.isEmpty) 'empty': SurfaceCopy.nothingClosingSoon,
    },
    'polls': {
      'count': '$pollsOpen',
      'label': pollsLabel,
      'line': ?pollsLine,
      if (pollsOpen == 0) 'empty': SurfaceCopy.noOpenPolls,
      'link': DeepLinks.uri(pollsRoute).toString(),
    },
  };

  Set<String> get thumbs => {for (final r in closingSoon) r.thumb};
}

String thumbName(String slug) => 'thumb_$slug.png';

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
