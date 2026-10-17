import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/polls_data.dart';
import 'package:iqly_mobile/surfaces/widget_snapshot.dart';

void main() {
  final now = DateTime(2026, 10, 3, 9, 41);
  final data = DemoData(now: now);
  final polls = demoPolls(now);

  test('Medium: the two briefs closing soonest first (347:16187), then the '
      'next for the second page', () {
    final s = WidgetSnapshot.of(briefs: data.briefs, polls: polls, now: now);
    expect(
      [for (final r in s.closingSoon) r.title],
      [
        'A tagline for a solar kiosk network',
        'Redesign the first five minutes of our savings app',
        'Packaging ideas for a cassava snack',
      ],
    );
    expect(
      [for (final r in s.closingSoon.take(WidgetSnapshot.medium)) r.meta],
      ['6h left · ₦150,000 pool', '1 day left · ₦500,000 pool'],
    );
    expect(s.closingSoon.first.thumb, 'thumb_sunline.png');
    expect(s.closingSoon.first.toJson()['link'], 'iqly://app/briefs/c5');
  });

  test('a brief within 24 hours counts down live; one further out keeps its '
      'day count (1340:28510)', () {
    final s = WidgetSnapshot.of(briefs: data.briefs, polls: polls, now: now);
    final [sunline, kudi, ...] = s.closingSoon;
    expect(sunline.closesAt, now.add(const Duration(hours: 6)));
    expect(sunline.live, '%s left · ₦150,000 pool');
    expect(
      sunline.toJson()['closesAt'],
      sunline.closesAt!.millisecondsSinceEpoch,
    );
    expect(kudi.closesAt, isNull);
    expect(kudi.toJson().containsKey('live'), isFalse);
    expect(s.pollsLive, 'Sunline closes in %s');
    expect(s.pollsClosesAt, sunline.closesAt);
  });

  test('the Medium widget holds up to four rows, for Android to show two at '
      'a time', () {
    final later = [
      for (final b in data.briefs)
        if (b.isLive && b.deadline != null) b,
    ];
    final s = WidgetSnapshot.of(
      briefs: later,
      polls: polls,
      now: now.subtract(const Duration(days: 30)),
    );
    expect(
      s.closingSoon.length,
      lessThanOrEqualTo(WidgetSnapshot.medium * WidgetSnapshot.pages),
    );
  });

  test('Small: unanswered polls and the soonest close', () {
    final s = WidgetSnapshot.of(briefs: data.briefs, polls: polls, now: now);
    expect(s.pollsOpen, 3);
    expect(s.pollsLabel, 'polls open');
    expect(s.pollsLine, 'Sunline closes in 6h');
    final hidden = WidgetSnapshot.of(
      briefs: data.briefs,
      polls: polls,
      now: now,
      showPolls: false,
    );
    expect(hidden.pollsOpen, 0);
  });

  test('timeline counts down and drops a closed brief', () {
    final t = WidgetTimeline.of(briefs: data.briefs, polls: polls, now: now);
    expect(t.entries, hasLength(WidgetTimeline.hours));
    final (at5, s5) = t.entries[5];
    expect(at5, now.add(const Duration(hours: 5)));
    expect(s5.closingSoon.first.meta, '1h left · ₦150,000 pool');
    final (_, s6) = t.entries[6];
    expect(s6.closingSoon.first.id, 'c4');
    final json = t.toJson();
    expect(json['version'], 1);
    final first = (json['entries']! as List).first as Map;
    expect(first['at'], now.millisecondsSinceEpoch);
    expect((first['polls'] as Map)['count'], '3');
    expect(t.thumbs, containsAll(['thumb_sunline.png', 'thumb_kudi-box.png']));
  });

  test('empty widgets carry their line, so they draw the illustration in '
      'place of a zero (a live launch has no polls)', () {
    final full = WidgetSnapshot.of(
      briefs: data.briefs,
      polls: polls,
      now: now,
    ).toJson();
    expect((full['polls']! as Map).containsKey('empty'), isFalse);
    expect((full['closingSoon']! as Map).containsKey('empty'), isFalse);

    final live = WidgetSnapshot.of(
      briefs: const [],
      polls: const [],
      now: now,
      showPolls: false,
    ).toJson();
    final pollsJson = live['polls']! as Map;
    expect(pollsJson['empty'], 'No open polls right now');
    expect(pollsJson['count'], '0');
    expect((live['closingSoon']! as Map)['empty'], 'Nothing closing soon');
    expect((live['closingSoon']! as Map)['rows'], isEmpty);
  });
}
