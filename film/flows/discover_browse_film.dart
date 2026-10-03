import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/discover/brief_detail_screen.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/discover/saved_briefs_screen.dart';
import 'package:iqly_mobile/ui/ticket_card.dart';

import '../harness.dart';

const _returning = <String, Object>{
  'session.signedIn': true,
  'session.onboardingDone': true,
  'session.firstTipSeen': true,
};

Finder _list(Type screen) => find
    .descendant(of: find.byType(screen), matching: find.byType(Scrollable))
    .first;

/// Flicks [list] by [dy] until [done], reading each stop.
Future<void> _flickUntil(
  Director d,
  Finder list,
  double dy,
  bool Function() done,
) async {
  for (var i = 0; !done(); i++) {
    if (i == 8) throw TestFailure('${d.name}: flicked 8 times at ${d.time}s');
    await d.scroll(list, dy, seconds: 0.25, fling: true);
    await d.hold(0.9);
  }
}

/// A returning contributor opens the app on Discover: the feed loads at the
/// prototype's pace, scrolls into the next page, refreshes, switches lens,
/// and opens a brief.
void main() {
  film('discover_browse', prefs: _returning, (d) async {
    await d.waitFor(find.byType(HomeScreen));
    await d.waitFor(find.text('Closing soon'));
    await d.settle(on: find.byType(HomeScreen));
    await d.hold(1.8);

    final feed = _list(HomeScreen);
    final loadingMore = find.text('LOADING MORE');
    await _flickUntil(d, feed, -320, () => loadingMore.evaluate().isNotEmpty);
    await d.gone(loadingMore);
    await d.hold(1.2);
    final end = find.text('That’s all 11 live briefs');
    await _flickUntil(d, feed, -320, () => end.evaluate().isNotEmpty);
    await d.hold(1);

    bool atTop() => d.tester.state<ScrollableState>(feed).position.pixels <= 0;
    await _flickUntil(d, feed, 360, atTop);
    await d.hold(0.6);
    await d.scroll(feed, 230, seconds: 0.7, from: const Alignment(0, -0.5));
    await d.waitFor(find.text('REFRESHING'));
    await d.gone(find.text('REFRESHING'));
    await d.hold(1.6);

    await d.tap(find.text('All'));
    await d.settle(on: find.byType(HomeScreen));
    await d.hold(1.8);
    await d.tap(find.text('Saved'));
    await d.arrive(find.byType(SavedBriefsScreen), hold: 1.8);
    await d.tap(find.text('For you'));
    await d.arrive(find.byType(HomeScreen), hold: 1.5);

    await d.tap(
      find.byWidgetPredicate(
        (w) =>
            w is IqTicketCard &&
            w.kind == IqTicketCardKind.hero &&
            w.title == 'A tagline for a solar kiosk network',
      ),
      label: 'solar-kiosk-brief',
    );
    await d.arrive(find.byType(BriefDetailScreen), hold: 1.8);
    // A brief that fits the screen is read with one small push that bounces
    // back, not a long drag into overscroll.
    final detail = _list(BriefDetailScreen);
    final extent = d.tester
        .state<ScrollableState>(detail)
        .position
        .maxScrollExtent;
    await d.scroll(detail, -(extent + 48), seconds: 0.6);
    await d.hold(1.2);
    if (extent > 0) await d.scroll(detail, extent + 48, seconds: 0.6);
    await d.hold(0.8);
    await d.back();

    await d.arrive(find.byType(HomeScreen), hold: 2);
  });
}
