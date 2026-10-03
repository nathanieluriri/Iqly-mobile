import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/button.dart';
import 'package:iqly_mobile/ui/proof_tile.dart';

import 'golden.dart';
import 'press.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final state in IqProofTileState.values) {
    testWidgets('${state.name} state', (tester) async {
      await expectComponentGolden(
        tester,
        'proof_tile_${state.name}',
        stillMotion(SizedBox(width: 358, child: IqProofTile(state: state))),
        size: const Size(358, 249),
      );
    });
  }

  testWidgets('the tile and its button both pick a video', (tester) async {
    var picks = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: stillMotion(
          Center(
            child: SizedBox(
              width: 358,
              child: IqProofTile(onTap: () => picks++),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(IqButton));
    await tester.tap(find.text('Add your screen recording'));
    expect(picks, 2);
  });

  testWidgets('empty breathes, error shakes once then rests', (tester) async {
    Widget tile(IqProofTileState state) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(width: 358, child: IqProofTile(state: state)),
      ),
    );
    await tester.pumpWidget(tile(IqProofTileState.empty));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(tile(IqProofTileState.error));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Choose another'), findsOneWidget);
  });
}
