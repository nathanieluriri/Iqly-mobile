import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/discover/saved_briefs_screen.dart';
import 'package:iqly_mobile/features/submissions/my_submissions_screen.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/dock.dart';

import '../golden/golden.dart' show loadAppFonts;
import '../golden/screens/app_harness.dart';

Future<void> _tab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(IqDock), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

ScrollPosition _position(WidgetTester tester, Type screen) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(screen),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

void main() {
  setUpAll(loadAppFonts);

  testWidgets('the dock moves between the four tabs and each keeps its state', (
    tester,
  ) async {
    await pumpApp(tester, Routes.home);
    expect(find.byType(HomeScreen), findsOneWidget);

    _position(tester, HomeScreen).jumpTo(600);
    await tester.pumpAndSettle();

    await _tab(tester, 'Submissions');
    expect(find.byType(MySubmissionsScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    await tester.tap(find.text('Winners · 2'));
    await tester.pumpAndSettle();

    await _tab(tester, 'Wallet');
    expect(find.text('Wallet'), findsWidgets);
    expect(find.byType(MySubmissionsScreen), findsNothing);

    await _tab(tester, 'More');
    expect(find.text('More'), findsWidgets);

    await _tab(tester, 'Discover');
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(_position(tester, HomeScreen).pixels, 600);

    await _tab(tester, 'Submissions');
    expect(find.text('₦62,500.00 won from 2 briefs'), findsOneWidget);

    await _tab(tester, 'Discover');
    _position(tester, HomeScreen).jumpTo(0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved').first);
    await tester.pumpAndSettle();
    expect(find.byType(SavedBriefsScreen), findsOneWidget);

    await _tab(tester, 'Wallet');
    await _tab(tester, 'Discover');
    expect(find.byType(SavedBriefsScreen), findsOneWidget);

    await _tab(tester, 'Discover');
    expect(find.byType(SavedBriefsScreen), findsOneWidget);
  });
}
