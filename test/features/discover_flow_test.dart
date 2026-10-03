import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/discover/brief_detail_screen.dart';
import 'package:iqly_mobile/features/discover/discover_state.dart';
import 'package:iqly_mobile/features/discover/filters_sheet.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/discover/saved_briefs_screen.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/bookmark.dart';
import 'package:iqly_mobile/ui/section_title.dart';
import 'package:iqly_mobile/ui/switch.dart';
import 'package:iqly_mobile/ui/ticket_card.dart';

import '../golden/screens/app_harness.dart';

Finder _ticket(String title) => find.byWidgetPredicate(
  (w) =>
      w is IqTicketCard && w.title == title && w.kind == IqTicketCardKind.list,
);

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

void main() {
  testWidgets('Discover: groups, save, Saved, detail, reminder, submit', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final container = await pumpApp(tester, Routes.home);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Marketing & advertising'), findsOneWidget);
    await _scrollTo(tester, find.text('Finance & fintech'));
    await _scrollTo(tester, find.text('More briefs'));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
    await tester.pumpAndSettle();

    const orchid = 'Naming a new sparkling water brand for Gen Z.';
    await _scrollTo(tester, _ticket(orchid));
    await _tap(
      tester,
      find.descendant(of: _ticket(orchid), matching: find.byType(IqBookmark)),
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
    expect(find.text('In 6 hours'), findsOneWidget);
    expect(find.text('12 of 40 left'), findsOneWidget);

    await _tap(tester, find.text('Remind me'));
    expect(container.read(closeRemindersProvider).value, isEmpty);
    expect(
      tester.widget<IqSwitch>(find.byType(IqSwitch)).state,
      IqSwitchState.off,
    );

    await _tap(tester, find.text('Submit your response'));
    expect(find.text('Submit'), findsOneWidget);
    await _tap(tester, find.bySemanticsLabel(RegExp('Back')));
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
    final container = await pumpApp(tester, Routes.home);

    await _scrollTo(tester, find.text('More briefs'));
    final more = find.byWidgetPredicate(
      (w) => w is IqSectionTitle && w.title == 'More briefs',
    );
    await tester.ensureVisible(more);
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getTopRight(more) + const Offset(-24, 16));
    await tester.pumpAndSettle();
    expect(find.byType(FiltersSheet), findsOneWidget);
    expect(find.text('Show 11 briefs'), findsOneWidget);

    await _tap(tester, find.text('My interests first'));
    await _tap(tester, find.text('Biggest reward'));
    await _tap(tester, find.text('Show 11 briefs'));
    expect(find.byType(FiltersSheet), findsNothing);
    expect(
      container.read(discoverFiltersProvider).sort,
      FeedSort.biggestReward,
    );
    expect(find.text('Marketing & advertising'), findsNothing);

    await _scrollTo(tester, find.text('That’s all 11 live briefs'));

    await _tap(tester, find.text('Wallet'));
    expect(find.byType(HomeScreen), findsNothing);
    await _tap(tester, find.text('Discover').last);
    expect(find.text('That’s all 11 live briefs'), findsOneWidget);

    await _tap(tester, find.bySemanticsLabel(RegExp('Notifications')));
    expect(find.text('Notifications'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('Discover: failed load, Try again', (tester) async {
    await pumpApp(
      tester,
      Routes.home,
      repository: ScriptedRepository([BriefsCall.fail, BriefsCall.data]),
    );
    expect(find.text('Nothing to show yet'), findsOneWidget);
    await _tap(tester, find.text('Try again'));
    expect(find.text('Closing soon'), findsOneWidget);
  });

  testWidgets('onboarding Done tickets open brief detail', (tester) async {
    await pumpApp(
      tester,
      Routes.onboardingDone,
      prefs: signedInPrefs(onboardingDone: false),
    );
    await _tap(tester, find.text('A tagline for a solar kiosk network'));
    expect(find.byType(BriefDetailScreen), findsOneWidget);
  });
}
