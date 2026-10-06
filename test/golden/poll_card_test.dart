import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/poll_card.dart';
import 'package:iqly_mobile/ui/poll_option.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final state in IqPollCardState.values) {
    testWidgets(state.name, (tester) async {
      await expectComponentGolden(
        tester,
        'poll_card_${state.name}',
        SizedBox(width: 358, child: IqPollCard(state: state)),
        size: const Size(358, 298),
      );
    });
  }

  testWidgets('an open card reports the vote', (tester) async {
    int? voted;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 358,
            child: IqPollCard(onVote: (i) => voted = i),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(IqPollOption).at(1));
    expect(voted, 1);
  });
}
