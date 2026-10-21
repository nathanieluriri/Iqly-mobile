import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/tablet_nav.dart';

import '../golden.dart';
import 'discover_harness.dart';
import 'tablet_harness.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final frame in [TabletFrameSize.portrait, TabletFrameSize.landscape]) {
    testWidgets('T1 account menu open, ${frame.name}', (tester) async {
      await pumpTablet(
        tester,
        Routes.home,
        frame: frame,
        overrides: discoverOverrides(),
      );
      await tester.tap(find.text('Adaeze Okafor'));
      await tester.pumpAndSettle();
      await expectTabletGolden(tester, 'shell_account_${frame.name}');
    });

    testWidgets('T1 search open, ${frame.name}', (tester) async {
      await pumpTablet(
        tester,
        Routes.home,
        frame: frame,
        overrides: discoverOverrides(),
      );
      await tester.tap(find.text('Search briefs, polls and activations'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'kiosk');
      await tester.pumpAndSettle();
      await expectTabletGolden(tester, 'shell_search_${frame.name}');
    });
  }

  testWidgets('T1 the sidebar collapses to the rail and opens again', (
    tester,
  ) async {
    await pumpTablet(
      tester,
      Routes.home,
      frame: TabletFrameSize.landscape,
      overrides: discoverOverrides(),
    );
    expect(tester.getSize(find.byType(IqTabletNav)).width, 232);
    await tester.tap(find.text('Collapse sidebar'));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(IqTabletNav)).width, 88);
    await expectTabletGolden(tester, 'shell_collapsed_landscape');
  });

  testWidgets('T1 the rail switches tabs', (tester) async {
    await pumpTablet(tester, Routes.home, overrides: discoverOverrides());
    await tester.tap(find.text('Submissions'));
    await tester.pumpAndSettle();
    expect(find.text('My submissions'), findsWidgets);
  });

  testWidgets('a rotation keeps the page and its scroll', (tester) async {
    await pumpTablet(tester, Routes.home, overrides: discoverOverrides());
    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    final before = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;
    tester.view.physicalSize = TabletFrameSize.landscape.size;
    await tester.pumpAndSettle();
    final after = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;
    expect(before, greaterThan(0));
    expect(after, before);
  });
}
