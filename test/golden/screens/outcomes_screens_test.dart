import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/outcomes/outcomes_routes.dart';
import 'package:iqly_mobile/features/submissions/submissions_routes.dart';

import '../golden.dart';
import 'app_harness.dart';

Future<void> _golden(WidgetTester tester, String name, String location) async {
  await pumpApp(tester, location);
  await precacheImages(tester);
  await expectMatchesGolden(
    find.byType(MaterialApp),
    'goldens/outcomes_$name.png',
  );
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('result: winner (193:9573)', (tester) async {
    await _golden(tester, 'winner', resultPath('s2'));
  });

  testWidgets('share sheet (193:9621)', (tester) async {
    await _golden(tester, 'share_sheet', sharePath('s2'));
  });

  testWidgets('result: not selected (193:9681)', (tester) async {
    await _golden(tester, 'not_selected', resultPath('s5'));
  });

  testWidgets('leaderboard (193:9779)', (tester) async {
    await _golden(tester, 'leaderboard', leaderboardPath('s2'));
  });

  testWidgets('leaderboard: not selected (225:10747)', (tester) async {
    await _golden(tester, 'leaderboard_not_selected', leaderboardPath('s5'));
  });

  testWidgets('result: a winner whose board is not out', (tester) async {
    await _golden(tester, 'winner_no_board', resultPath('s3'));
  });
}
