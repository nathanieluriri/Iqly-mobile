import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/polls_data.dart';
import 'package:iqly_mobile/surfaces/widget_snapshot.dart';

void main() {
  final now = DateTime(2026, 10, 3, 9, 41);
  final data = DemoData(now: now);
  final polls = demoPolls(now);

  test('Medium: the two briefs closing soonest (347:16187)', () {
    final s = WidgetSnapshot.of(briefs: data.briefs, polls: polls, now: now);
    expect(
      [for (final r in s.closingSoon) r.title],
      [
        'A tagline for a solar kiosk network',
        'Redesign the first five minutes of our savings app',
      ],
    );
    expect(
      [for (final r in s.closingSoon) r.meta],
      ['6h left · ₦150,000 pool', '1 day left · ₦500,000 pool'],
    );
    expect(s.closingSoon.first.thumb, 'thumb_sunline.png');
    expect(s.closingSoon.first.toJson()['link'], 'iqly://app/briefs/c5');
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
}
