import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/features/discover/brief_detail_screen.dart';
import 'package:iqly_mobile/features/discover/discover_state.dart';
import 'package:iqly_mobile/features/discover/filters_sheet.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/discover/saved_briefs_screen.dart';
import 'package:iqly_mobile/features/polls/polls_screen.dart';
import 'package:iqly_mobile/features/submit/submit_screen.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/bookmark.dart';
import 'package:iqly_mobile/ui/brief_card.dart';
import 'package:iqly_mobile/ui/button.dart';
import 'package:iqly_mobile/ui/switch.dart';
import 'package:iqly_mobile/ui/ticket_card.dart';

import '../golden/screens/app_harness.dart';
import '../golden/screens/discover_harness.dart';

Finder _card(String title) =>
    find.byWidgetPredicate((w) => w is IqBriefCard && w.title == title);

List<String> _cards(WidgetTester tester) => [
  for (final card in tester.widgetList<IqBriefCard>(
    find.byWidgetPredicate(
      (w) => w is IqBriefCard && w.kind == IqBriefCardKind.feature,
      skipOffstage: false,
    ),
  ))
    card.title,
];

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _openFilters(WidgetTester tester) async {
  await _tap(tester, find.text('Filter').first);
  expect(find.byType(FiltersSheet), findsOneWidget);
}

void main() {
  testWidgets('Discover: sections, save, Saved, detail, reminder, submit', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final container = await pumpApp(
      tester,
      Routes.home,
      overrides: discoverOverrides(),
    );
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Quick polls'), findsOneWidget);
    expect(find.text('Which flavour should we launch first?'), findsOneWidget);
    expect(find.text('Rate 3 recipes in the Orchid Foods app'), findsOneWidget);
    expect(find.text('Closes in 5h 40m'), findsOneWidget);
    expect(find.text('Briefs'), findsOneWidget);
    await _scrollTo(tester, find.text('More briefs'));
    expect(_cards(tester).take(4), [
      'A tagline for a solar kiosk network',
      'Redesign the first five minutes of our savings app',
      'Naming a new sparkling water brand for Gen Z.',
      'Rename our youth current account',
    ]);

    const orchid = 'Naming a new sparkling water brand for Gen Z.';
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 5000));
    await tester.pumpAndSettle();
    await _scrollTo(tester, _card(orchid));
    await _tap(
      tester,
      find.descendant(of: _card(orchid), matching: find.byType(IqBookmark)),
    );
    expect(container.read(savedBriefsProvider).value!.map((b) => b.id), [
      'c1',
      'c5',
      'c4',
    ]);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, 5000));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Saved'));
    expect(find.byType(SavedBriefsScreen), findsOneWidget);
    expect(find.byType(IqTicketCard), findsNWidgets(3));

    await _tap(tester, find.text('A tagline for a solar kiosk network'));
    expect(find.byType(BriefDetailScreen), findsOneWidget);
    expect(find.text('Closes in 6h'), findsOneWidget);
    expect(find.text('₦150k'), findsOneWidget);
    expect(find.text('2 min'), findsOneWidget);

    await _tap(tester, find.text('Remind me', skipOffstage: false));
    expect(container.read(closeRemindersProvider).value, isEmpty);
    expect(
      tester.widget<IqSwitch>(find.byType(IqSwitch)).state,
      IqSwitchState.off,
    );

    await _tap(tester, find.text('Start your submission'));
    expect(find.byType(SubmitScreen), findsOneWidget);
    await _tap(tester, find.bySemanticsLabel(RegExp('Back')));
    await _tap(tester, find.text('Discard draft'));
    await _tap(tester, find.bySemanticsLabel(RegExp('Back')));
    expect(find.byType(SavedBriefsScreen), findsOneWidget);

    await _tap(tester, find.text('For you'));
    expect(find.byType(HomeScreen), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('Discover: filters, All, load more, end of list, tabs', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final container = await pumpApp(
      tester,
      Routes.home,
      overrides: discoverOverrides(),
    );

    await _openFilters(tester);
    expect(find.text('Show 11 briefs'), findsOneWidget);
    await _tap(tester, find.text('My interests first'));
    await _tap(tester, find.text('Biggest reward'));
    await _tap(tester, find.text('Show 11 briefs'));
    expect(find.byType(FiltersSheet), findsNothing);
    expect(
      container.read(discoverFiltersProvider).sort,
      FeedSort.biggestReward,
    );
    expect(_cards(tester).take(3), [
      'A tagline for a solar kiosk network',
      'Redesign the first five minutes of our savings app',
      'A grocery delivery service that beats Bolt Food.',
    ]);

    await _tap(tester, find.text('For you'));
    expect(container.read(discoverFiltersProvider).forYou, isTrue);
    await _tap(tester, find.text('All'));
    expect(container.read(discoverFiltersProvider).sort, FeedSort.mostUrgent);
    await _scrollTo(tester, find.text('That’s all 11 live briefs'));
    expect(find.text('More briefs'), findsNothing);

    await _tap(tester, find.text('Wallet'));
    expect(find.byType(HomeScreen), findsNothing);
    await _tap(tester, find.text('Discover').last);
    expect(find.text('That’s all 11 live briefs'), findsOneWidget);

    await _tap(tester, find.bySemanticsLabel(RegExp('Notifications')));
    expect(find.text('Notifications'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('Discover: filters that match nothing say so and clear', (
    tester,
  ) async {
    final container = await pumpApp(
      tester,
      Routes.home,
      overrides: discoverOverrides(),
    );

    await _openFilters(tester);
    await _tap(tester, find.text('Standard and Advanced'));
    await _tap(tester, find.text('Advanced').last);
    await _tap(tester, find.text('All categories'));
    await _tap(tester, find.text('Technology').last);
    final show = tester.widget<IqButton>(
      find.widgetWithText(IqButton, 'No briefs match'),
    );
    expect(show.disabled, isTrue);
    await _tap(tester, find.text('Clear filters'));
    expect(find.byType(FiltersSheet), findsNothing);

    container
        .read(discoverFiltersProvider.notifier)
        .apply(
          const DiscoverFilters(
            tier: Tier.advanced,
            category: Category.technology,
          ),
        );
    await tester.pumpAndSettle();
    expect(find.text('No briefs match these filters'), findsOneWidget);
    expect(find.text('No open briefs right now'), findsNothing);
    await _tap(tester, find.text('Clear filters'));
    expect(find.text('No briefs match these filters'), findsNothing);
    expect(find.text('A tagline for a solar kiosk network'), findsOneWidget);
  });

  testWidgets('Discover: no briefs offers All', (tester) async {
    final container = await pumpApp(
      tester,
      Routes.home,
      repository: ScriptedRepository([BriefsCall.empty]),
      overrides: discoverOverrides(),
    );
    expect(find.text('No open briefs right now'), findsOneWidget);
    expect(find.text('New briefs land here.'), findsOneWidget);
    await _tap(tester, find.text('See all briefs'));
    expect(container.read(discoverFiltersProvider).forYou, isFalse);
  });

  testWidgets('Discover: failed load, Try again', (tester) async {
    await pumpApp(
      tester,
      Routes.home,
      repository: ScriptedRepository([BriefsCall.fail, BriefsCall.data]),
      overrides: discoverOverrides(),
    );
    expect(find.text('Couldn’t load briefs'), findsOneWidget);
    expect(
      find.text('Check your data or Wi-Fi and try again.'),
      findsOneWidget,
    );
    await _tap(tester, find.text('Try again'));
    expect(find.text('A tagline for a solar kiosk network'), findsOneWidget);
  });

  testWidgets('Discover: Quick polls See all and a tile open the polls', (
    tester,
  ) async {
    await pumpApp(tester, Routes.home, overrides: discoverOverrides());
    await _tap(tester, find.text('See all').first);
    expect(find.byType(PollsScreen), findsOneWidget);
    expect(find.text('Open polls'), findsOneWidget);
    await _tap(tester, find.bySemanticsLabel(RegExp('Back')));
    expect(find.byType(HomeScreen), findsOneWidget);

    await _tap(tester, find.text('Which flavour should we launch first?'));
    expect(find.byType(PollsScreen), findsOneWidget);
    expect(
      find.text('1 poll · 2 questions · about 10 seconds'),
      findsOneWidget,
    );
  });

  testWidgets('Discover: Activations opens the list', (tester) async {
    await pumpApp(tester, Routes.home, overrides: discoverOverrides());
    await _tap(tester, find.text('Rate 3 recipes in the Orchid Foods app'));
    expect(find.byType(HomeScreen), findsNothing);
    await _tap(tester, find.bySemanticsLabel(RegExp('Back')).first);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('Brief detail: sent and closed briefs', (tester) async {
    await pumpApp(tester, Routes.brief('c1'), overrides: discoverOverrides());
    expect(find.text('View your submission'), findsOneWidget);
    await _tap(tester, find.text('View your submission'));
    expect(find.byType(BriefDetailScreen), findsNothing);
  });

  testWidgets('onboarding Done cards open brief detail', (tester) async {
    await pumpApp(
      tester,
      Routes.onboardingDone,
      prefs: signedInPrefs(onboardingDone: false),
    );
    await _tap(tester, find.text('A tagline for a solar kiosk network'));
    expect(find.byType(BriefDetailScreen), findsOneWidget);
  });
}
