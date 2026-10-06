import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/polls/poll_sheet.dart';
import 'package:iqly_mobile/features/polls/polls_screen.dart';
import 'package:iqly_mobile/ui/poll_tile.dart';

import '../harness.dart';
import '../steps.dart';

const _flavour = 'Which flavour should we launch first?';

Finder _tile(String question) => find.byWidgetPredicate(
  (w) => w is IqPollTile && w.question == question,
  description: 'the "$question" tile',
);

/// A returning contributor opens the app, taps Orchid Foods' poll on
/// Discover, votes on the sheet, drags the sheet up into the full-screen
/// polls, answers the second question to the thank-you, and backs out to
/// Discover with the tile answered.
void main() {
  film('polls', prefs: returning, (d) async {
    await onDiscover(d, hold: 1.5);

    await d.tap(_tile(_flavour), label: 'flavour-poll');
    await d.waitFor(find.byType(PollsScreen));
    await d.arrive(find.byType(PollSheet), hold: 1.2);

    await d.tap(find.text('Zobo and ginger'));
    await d.waitFor(find.text('You voted · 214 votes'));
    await d.hold(1.4);

    await d.scroll(
      find.text('Quick polls').last,
      -320,
      seconds: 0.3,
      fling: true,
    );
    await d.arrive(find.byType(PollPage), hold: 1.2);
    final litre = find.text('1 litre bottle');
    await d.reveal(litre, listIn(find.byType(PollPage)));
    await d.hold(0.5);
    await d.tap(litre);
    await d.waitFor(find.textContaining('2 answers sent'));
    await d.hold(2.5);
    await d.back();

    await d.arrive(find.byType(PollsScreen), hold: 1.5);
    await d.back();

    await d.arrive(find.byType(HomeScreen), hold: 2);
    expect(
      d.tester.widget<IqPollTile>(_tile(_flavour)).state,
      IqPollTileState.answered,
    );
  });
}
