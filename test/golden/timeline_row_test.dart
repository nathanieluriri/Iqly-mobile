import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/timeline_row.dart';

import 'golden.dart';
import 'press.dart';

void main() {
  setUpAll(loadAppFonts);

  const copy = {
    IqTimelineRowState.done: ('Proof received', 'Today, 2:14 pm'),
    IqTimelineRowState.current: (
      'Checking with Kudi Box',
      'Usually within 24 hours. We will notify you.',
    ),
    IqTimelineRowState.upcoming: (
      'Paid to your wallet',
      'After confirmation · ₦1,500.00',
    ),
  };

  for (final state in IqTimelineRowState.values) {
    testWidgets(state.name, (tester) async {
      final (title, meta) = copy[state]!;
      await expectComponentGolden(
        tester,
        'timeline_row_${state.name}',
        stillMotion(
          SizedBox(
            width: 358,
            child: IqTimelineRow(state: state, title: title, meta: meta),
          ),
        ),
        size: const Size(358, 63),
      );
    });
  }

  testWidgets('failed current', (tester) async {
    await expectComponentGolden(
      tester,
      'timeline_row_failed',
      stillMotion(
        const SizedBox(
          width: 358,
          child: IqTimelineRow(
            state: IqTimelineRowState.current,
            title: 'Proof did not match',
            meta: 'Send a clearer recording.',
            failed: true,
          ),
        ),
      ),
      size: const Size(358, 63),
    );
  });

  testWidgets('an empty meta hides the line: 43 tall', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 358,
              child: IqTimelineRow(title: 'Requested', meta: ''),
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(IqTimelineRow)).height, 43);
    expect(find.text(''), findsNothing);
  });

  testWidgets('a failed Current row does not breathe', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 358,
            child: IqTimelineRow(
              state: IqTimelineRowState.current,
              failed: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('becoming done draws the thread down', (tester) async {
    Widget row(IqTimelineRowState state) => MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 358, child: IqTimelineRow(state: state)),
      ),
    );
    await tester.pumpWidget(row(IqTimelineRowState.current));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(row(IqTimelineRowState.done));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('Proof received'), findsOneWidget);
  });
}
