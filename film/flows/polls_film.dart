import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/polls/poll_sheet.dart';
import 'package:iqly_mobile/features/polls/polls_screen.dart';
import 'package:iqly_mobile/ui/brand_bubble.dart';

import '../harness.dart';
import '../steps.dart';

Finder _bubble(String name) => find.byWidgetPredicate(
  (w) => w is IqBrandBubble && w.name == name,
  description: 'the $name bubble',
);

/// A returning contributor signs in and answers Orchid Foods' two polls
/// from the Open polls rail: the bubble raises its sheet over Polls, each
/// pick reveals the results, and back on Discover the bubble turns Done.
void main() {
  film('polls', (d) async {
    await signIn(d);

    await d.tap(_bubble('Orchid Foods'), label: 'orchid-foods-bubble');
    await d.waitFor(find.byType(PollsScreen));
    await d.arrive(find.byType(PollSheet), hold: 1.2);

    await d.tap(find.text('Zobo and ginger'));
    await d.waitFor(find.text('1 OF 2 ANSWERED'));
    await d.hold(1.2);
    await d.pickFromSheet('33cl slim can');
    await d.waitFor(find.text('2 OF 2 ANSWERED'));
    await d.hold(1.2);

    await closeSheet(d);
    await d.gone(find.byType(PollSheet));
    await d.settle(on: find.byType(PollsScreen));
    await d.hold(1);
    await d.back();

    await d.arrive(find.byType(HomeScreen), hold: 1.5);
    expect(
      d.tester.widget<IqBrandBubble>(_bubble('Orchid Foods')).state,
      IqBrandBubbleState.done,
    );
  });
}
