import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/points_data.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/features/outcomes/outcomes_routes.dart';
import 'package:iqly_mobile/features/submissions/submissions_routes.dart';
import 'package:iqly_mobile/router.dart';

import '../golden.dart';
import 'app_harness.dart';

Future<void> _golden(
  WidgetTester tester,
  String name,
  String location, {
  IqlyRepository? repository,
}) async {
  await pumpApp(tester, location, repository: repository);
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

  testWidgets('leaderboard: iQL points (548:25018)', (tester) async {
    await _golden(tester, 'leaderboard_points', Routes.pointsLeaderboard);
  });

  testWidgets('result: a winner whose board is not out', (tester) async {
    await _golden(tester, 'winner_no_board', resultPath('s3'));
  });

  for (final count in [0, 1, 2, 3]) {
    testWidgets('leaderboard: iQL points with $count on the board', (
      tester,
    ) async {
      await _golden(
        tester,
        'leaderboard_points_$count',
        Routes.pointsLeaderboard,
        repository: FewOnTheBoard(count),
      );
    });
  }
}

/// The demo board cut to its first [count] people.
class FewOnTheBoard extends DemoRepository {
  FewOnTheBoard(this.count) : super(DemoData(now: figmaNow));

  final int count;

  @override
  Future<PointsBoard> pointsLeaderboard() async {
    final board = await super.pointsLeaderboard();
    return PointsBoard(
      month: board.month,
      contributors: count,
      entries: board.entries.take(count).toList(),
    );
  }
}
