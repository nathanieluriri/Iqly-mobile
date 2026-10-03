import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/poll_option.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final state in IqPollOptionState.values) {
    testWidgets(state.name, (tester) async {
      await expectComponentGolden(
        tester,
        'poll_option_${state.name}',
        IqPollOption(state: state),
        size: const Size(326, 52),
      );
    });
  }

  testWidgets('only an open option takes a tap', (tester) async {
    var taps = 0;
    Widget option(IqPollOptionState state) => MaterialApp(
      home: Scaffold(
        body: IqPollOption(state: state, onTap: () => taps++),
      ),
    );
    await tester.pumpWidget(option(IqPollOptionState.standard));
    await tester.tap(find.byType(IqPollOption));
    await tester.pumpWidget(option(IqPollOptionState.result));
    await tester.tap(find.byType(IqPollOption));
    expect(taps, 1);
  });
}
