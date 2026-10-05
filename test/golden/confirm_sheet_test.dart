import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/ui/button.dart';
import 'package:iqly_mobile/ui/confirm_sheet.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('default', (tester) async {
    await expectComponentGolden(
      tester,
      'confirm_sheet',
      const SizedBox(width: 390, child: IqConfirmSheet()),
      size: const Size(390, 279),
    );
  });

  testWidgets('showIqConfirmSheet resolves true on Remove, false on Keep', (
    tester,
  ) async {
    final results = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  results.add(await showIqConfirmSheet(context)),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove recording'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();
    expect(results, [true, false]);
  });

  testWidgets('showIqConfirmSheet takes confirmKind and rises in 300 ms', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showIqConfirmSheet(
                context,
                confirmLabel: 'Allow photos',
                confirmKind: IqButtonKind.primary,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final route = ModalRoute.of(
      tester.element(find.byType(IqConfirmSheet, skipOffstage: false)),
    )!;
    expect(route.transitionDuration, IqDurations.sheetRise);
    expect(route.reverseTransitionDuration, IqDurations.sheetDrop);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<IqButton>(find.widgetWithText(IqButton, 'Allow photos'))
          .kind,
      IqButtonKind.primary,
    );
  });

  testWidgets('a second Remove tap or a scrim tap pops only the sheet', (
    tester,
  ) async {
    for (final second in ['remove', 'scrim']) {
      final results = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(second),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => Scaffold(
                      body: TextButton(
                        onPressed: () async =>
                            results.add(await showIqConfirmSheet(context)),
                        child: const Text('screen'),
                      ),
                    ),
                  ),
                ),
                child: const Text('home'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('home'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('screen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove recording'));
      await tester.pump(const Duration(milliseconds: 50));
      if (second == 'remove') {
        await tester.tap(find.text('Remove recording'), warnIfMissed: false);
      } else {
        await tester.tapAt(const Offset(20, 20));
      }
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(find.text('Remove recording'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('screen'), findsOneWidget, reason: second);
      expect(results, [true], reason: second);
    }
  });
}
