import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/ui/dock.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final active in IqDockActive.values) {
    testWidgets('${active.name} active', (tester) async {
      await expectComponentGolden(
        tester,
        'dock_${active.name}',
        IqDock(active: active),
        size: const Size(390, 72),
      );
    });
  }

  testWidgets('the lit tab is inert: tapping it reports nothing', (
    tester,
  ) async {
    final taps = <IqDockActive>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: IqDock(active: IqDockActive.wallet, onChanged: taps.add),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Wallet'));
    await tester.pump();
    expect(taps, isEmpty);
    await tester.tap(find.text('More'));
    await tester.pump();
    expect(taps, [IqDockActive.more]);
    await tester.pump(IqHaptics.tabFollow);
  });

  testWidgets('the bar is full width with a hairline on top, no radius', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(alignment: Alignment.bottomCenter, child: IqDock()),
        ),
      ),
    );
    final bar = tester.getRect(find.byType(IqDock));
    expect(bar.width, 800);
    expect(bar.height, closeTo(71.4, 0.01));
    final box =
        tester
                .widget<Container>(
                  find
                      .descendant(
                        of: find.byType(IqDock),
                        matching: find.byType(Container),
                      )
                      .first,
                )
                .decoration!
            as BoxDecoration;
    expect(box.borderRadius, isNull);
    expect(box.boxShadow, isNull);
    expect(box.border!.top.width, 1);
  });

  testWidgets('tapping a tab reports it and the pill moves there at once', (
    tester,
  ) async {
    var active = IqDockActive.discover;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: StatefulBuilder(
              builder: (context, setState) => IqDock(
                active: active,
                onChanged: (tab) => setState(() => active = tab),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Wallet'));
    await tester.pump();
    expect(active, IqDockActive.wallet);
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pump(IqHaptics.tabFollow);
  });
}
