import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/system_ui.dart';
import 'package:iqly_mobile/features/discover/app_shell.dart';
import 'package:iqly_mobile/features/discover/discover_widgets.dart';
import 'package:iqly_mobile/features/discover/saved_briefs_screen.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/brief_card.dart';
import 'package:iqly_mobile/ui/dock.dart';

import '../golden/golden.dart' show loadAppFonts;
import '../golden/screens/app_harness.dart';
import '../golden/screens/discover_harness.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets(
    'Saved content clears status, navigation, and landscape cutout insets',
    (tester) async {
      const size = Size(844, 390);
      const insets = FakeViewPadding(top: 24, bottom: 48, left: 44, right: 44);
      await pumpApp(
        tester,
        Routes.savedBriefs,
        size: size,
        insets: insets,
        overrides: discoverOverrides(),
      );

      final topBar = tester.getTopLeft(find.byType(DiscoverTopBar));
      expect(topBar.dy, greaterThanOrEqualTo(insets.top));

      final firstCard = tester.getRect(find.byType(IqBriefCard).first);
      expect(firstCard.left, greaterThanOrEqualTo(insets.left));
      expect(firstCard.right, lessThanOrEqualTo(size.width - insets.right));

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('inset')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final bottomInset = tester
          .getSize(
            find.descendant(
              of: find.byKey(const ValueKey('inset')),
              matching: find.byType(SizedBox),
            ),
          )
          .height;
      expect(
        bottomInset,
        greaterThanOrEqualTo(insets.bottom + IqDock.height + IqSpace.s3),
      );

      final dock = tester.getRect(find.byType(IqDock));
      expect(dock.bottom, closeTo(size.height - insets.bottom, 0.01));
      expect(
        AppShell.contentInset(tester.element(find.byType(SavedBriefsScreen))),
        bottomInset,
      );
    },
  );

  testWidgets('dock stays anchored while the keyboard inset changes', (
    tester,
  ) async {
    const insets = FakeViewPadding(top: 54, bottom: 34);
    await pumpApp(
      tester,
      Routes.savedBriefs,
      insets: insets,
      overrides: discoverOverrides(),
    );
    final before = tester.getRect(find.byType(IqDock));

    tester.view.viewInsets = const FakeViewPadding(bottom: 336);
    tester.view.padding = const FakeViewPadding(top: 54);
    await tester.pump();

    final after = tester.getRect(find.byType(IqDock));
    expect(after.bottom, closeTo(before.bottom, 0.01));
    expect(after.bottom, closeTo(844 - insets.bottom, 0.01));
  });

  testWidgets('Saved system bars use paper overlay style', (tester) async {
    await pumpApp(tester, Routes.savedBriefs, overrides: discoverOverrides());

    final style = tester.binding.renderViews.first.debugLayer!
        .find<SystemUiOverlayStyle>(const Offset(195, 20));
    expect(style, IqSystemUi.paper);
  });
}
