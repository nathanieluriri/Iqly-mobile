import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/leaderboard_row.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final state in IqLeaderboardRowState.values) {
    testWidgets('state ${state.name}', (tester) async {
      await expectComponentGolden(
        tester,
        'leaderboard_row_${state.name}',
        SizedBox(width: 358, child: IqLeaderboardRow(state: state)),
        size: const Size(358, 56),
      );
    });
  }

  testWidgets('entry and amount hide', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: IqLeaderboardRow(showEntry: false, showAmount: false),
      ),
    );
    expect(find.text('Bundles reset on Sunday'), findsNothing);
    expect(find.text('₦25,000'), findsNothing);
    expect(find.text('Chinedu A.'), findsOneWidget);
  });
}
