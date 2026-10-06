import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
        size: const Size(358, 100),
        padding: 24,
      );
    });
  }

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
  });
}
