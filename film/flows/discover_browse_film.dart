import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/discover/brief_detail_screen.dart';
import 'package:iqly_mobile/features/discover/filters_sheet.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/discover/saved_briefs_screen.dart';
import 'package:iqly_mobile/features/onboarding/onboarding_sheets.dart';
import 'package:iqly_mobile/ui/bookmark.dart';

import '../harness.dart';
import '../steps.dart';

Finder _text(String pattern) =>
    find.textContaining(RegExp(pattern, caseSensitive: false));

/// Flicks [list] by [dy] until [done], reading each stop.
Future<void> _flickUntil(
  Director d,
  Finder list,
  double dy,
  bool Function() done,
) async {
  for (var i = 0; !done(); i++) {
    if (i == 10) throw TestFailure('${d.name}: flicked 10 times at ${d.time}s');
    await d.scroll(list, dy, seconds: 0.25, fling: true);
    await d.hold(0.9);
  }
}

/// A returning contributor opens the app on Discover (the gift shines once),
/// reads the feed to its end, pulls to refresh (no second shine), tries the
/// All and Saved lenses, sorts by biggest reward in Filters, saves the solar
/// kiosk brief from its detail page and comes back to the feed.
void main() {
  film('discover_browse', prefs: returning, (d) async {
    await onDiscover(d, hold: 2.2);

    final feed = listIn(find.byType(HomeScreen));
    final loadingMore = _text('loading more');
    await _flickUntil(d, feed, -340, () => loadingMore.evaluate().isNotEmpty);
    await d.gone(loadingMore);
    await d.hold(1.2);
    final end = _text('that’s all');
    await _flickUntil(d, feed, -340, () => end.evaluate().isNotEmpty);
    await d.hold(1.2);

    bool atTop() => d.tester.state<ScrollableState>(feed).position.pixels <= 0;
    await _flickUntil(d, feed, 380, atTop);
    await d.hold(0.6);
    await d.scroll(feed, 230, seconds: 0.7, from: const Alignment(0, -0.5));
    await d.waitFor(_text('refreshing'));
    await d.gone(_text('refreshing'));
    await d.hold(1.6);

    await d.tap(find.text('All'));
    await d.settle(on: find.byType(HomeScreen));
    await d.hold(1.8);
    await d.tap(find.text('Saved'));
    await d.arrive(find.byType(SavedBriefsScreen), hold: 1.8);
    await d.tap(find.text('For you'));
    await d.arrive(find.byType(HomeScreen), hold: 1.2);

    final filter = sectionLink('Briefs');
    await d.reveal(filter, feed);
    await d.hold(0.5);
    await d.tap(filter, label: 'filter');
    await d.arrive(find.byType(FiltersSheet), hold: 1);
    await d.tap(find.text('My interests first'), label: 'sort');
    await d.arrive(find.byType(OptionSheet), hold: 0.6);
    await d.tap(find.text('Biggest reward'));
    await d.gone(find.byType(OptionSheet));
    await d.hold(1);
    await d.tap(find.textContaining('Show '), label: 'show-briefs');
    await d.gone(find.byType(FiltersSheet));
    await d.settle(on: find.byType(HomeScreen));
    await d.hold(1.5);

    final kiosk = briefCard('A tagline for a solar kiosk network');
    await d.reveal(kiosk, feed);
    await d.hold(0.6);
    await d.tap(kiosk, label: 'solar-kiosk-brief');
    await d.arrive(find.byType(BriefDetailScreen), hold: 1.8);
    final detail = listIn(find.byType(BriefDetailScreen));
    final extent = d.tester
        .state<ScrollableState>(detail)
        .position
        .maxScrollExtent;
    await d.scroll(detail, -(extent + 48), seconds: 0.6);
    await d.hold(1.2);
    if (extent > 0) await d.scroll(detail, extent + 48, seconds: 0.6);
    await d.hold(0.6);
    await d.tap(
      find.descendant(
        of: find.byType(BriefDetailScreen),
        matching: find.byType(IqBookmark),
      ),
      label: 'bookmark',
    );
    await d.hold(1.2);
    await d.back();

    await d.arrive(find.byType(HomeScreen), hold: 2);
  });
}
