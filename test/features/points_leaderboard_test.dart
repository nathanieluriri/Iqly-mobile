import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/features/help/help_centre_screen.dart';
import 'package:iqly_mobile/data/points_data.dart';
import 'package:iqly_mobile/features/outcomes/leaderboard_states.dart';
import 'package:iqly_mobile/features/outcomes/points_leaderboard_screen.dart';
import 'package:iqly_mobile/features/splash/patch_dialog.dart';
import 'package:iqly_mobile/ui/illustration.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/dock.dart';
import 'package:iqly_mobile/ui/leaderboard_row.dart';
import 'package:iqly_mobile/ui/podium.dart';

import '../golden/screens/app_harness.dart';
import '../golden/screens/outcomes_screens_test.dart' show FewOnTheBoard;

class _Waiting extends DemoRepository {
  _Waiting() : super(DemoData(now: figmaNow));

  final board = Completer<PointsBoard>();

  @override
  Future<PointsBoard> pointsLeaderboard() => board.future;
}

String _path(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first)).state.uri.path;

List<IqLeaderboardRow> _rows(WidgetTester tester) => tester
    .widgetList<IqLeaderboardRow>(
      find.byType(IqLeaderboardRow, skipOffstage: false),
    )
    .toList();

void main() {
  testWidgets('B13 iQL points: all contributors this month, the podium in '
      'points, every other rank with wins and submissions, you in place', (
    tester,
  ) async {
    await pumpApp(tester, Routes.pointsLeaderboard);
    expect(find.byType(PointsLeaderboardScreen), findsOneWidget);
    expect(find.byType(IqDock), findsNothing);
    expect(find.text('iQL points'), findsOneWidget);
    expect(find.text('All contributors · October'), findsOneWidget);
    expect(find.text('You are 7th of 2,130'), findsOneWidget);

    final podium = tester.widget<IqPodium>(find.byType(IqPodium));
    expect(
      [podium.name1, podium.amount1, podium.name2, podium.amount2],
      ['Chinedu A.', '3,420 pts', 'Tunde F.', '2,980 pts'],
    );
    expect([podium.name3, podium.amount3], ['Ngozi E.', '2,410 pts']);

    final rows = _rows(tester);
    expect(
      [for (final r in rows) r.rank],
      [for (var rank = 4; rank <= 10; rank++) '$rank'],
    );
    final you = rows.singleWhere((r) => r.state == IqLeaderboardRowState.you);
    expect(
      (you.rank, you.name, you.entry, you.amount),
      ('7', 'You', '2 wins · 5 submissions', '1,240 pts'),
    );
    expect(rows[2].entry, '1 win · 22 submissions');
    expect(rows.last.entry, '0 wins · 8 submissions');
    expect(rows.every((r) => r.showAmount), isTrue);
  });

  testWidgets('B13 iQL points: the board is the current month\'s', (
    tester,
  ) async {
    final november = DateTime(2026, 11, 4, 9, 41);
    await pumpApp(
      tester,
      Routes.pointsLeaderboard,
      repository: DemoRepository(DemoData(now: november)),
      clock: () => november,
    );
    expect(find.text('All contributors · November'), findsOneWidget);
  });

  testWidgets('B13 iQL points: the viewer row foots to the pass and the '
      'repository', (tester) async {
    final data = DemoData(now: figmaNow);
    final board = await DemoRepository(data).pointsLeaderboard();
    final you = board.you!;
    expect(you.points, await DemoRepository(data).points());
    expect(you.submissions, data.submissions.length);
    expect(board.month, DateTime(2026, 10));
    expect(
      [for (final e in board.entries) e.rank],
      [for (var rank = 1; rank <= board.entries.length; rank++) rank],
    );
    expect([
      for (final e in board.entries) e.points,
    ], [...board.entries.map((e) => e.points)]..sort((a, b) => b - a));
  });

  testWidgets('B13 iQL points: How points work opens the Help centre', (
    tester,
  ) async {
    await pumpApp(tester, Routes.pointsLeaderboard);
    await tester.tap(find.text('How points work'));
    await tester.pumpAndSettle();
    expect(find.byType(HelpCentreScreen), findsOneWidget);
    expect(_path(tester), Routes.helpCentre);
  });

  testWidgets('B13 iQL points: the filling mark while the board loads', (
    tester,
  ) async {
    final repository = _Waiting();
    await pumpApp(
      tester,
      Routes.pointsLeaderboard,
      repository: repository,
      settle: false,
    );
    await tester.pump();
    expect(find.byType(IqFillLoader), findsOneWidget);
    repository.board.complete(await FewOnTheBoard(3).pointsLeaderboard());
    await tester.pumpAndSettle();
    expect(find.byType(IqFillLoader), findsNothing);
    expect(find.byType(LeaderboardFew), findsOneWidget);
  });

  testWidgets('B13 iQL points: an empty board says no one is on it', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Routes.pointsLeaderboard,
      repository: FewOnTheBoard(0),
    );
    expect(find.text('No one is on the leaderboard yet'), findsOneWidget);
    expect(find.byType(IqPodium), findsNothing);
  });

  testWidgets('B13 iQL points: one person stands alone under confetti', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Routes.pointsLeaderboard,
      repository: FewOnTheBoard(1),
    );
    expect(find.byType(FallingConfetti), findsOneWidget);
    expect(find.text('Chinedu A.'), findsOneWidget);
    expect(find.text('3,420 pts'), findsOneWidget);
  });

  for (final count in [2, 3]) {
    testWidgets('B13 iQL points: $count people get the tall podium and no '
        'rows', (tester) async {
      await pumpApp(
        tester,
        Routes.pointsLeaderboard,
        repository: FewOnTheBoard(count),
      );
      expect(find.byType(LeaderboardFew), findsOneWidget);
      expect(find.byType(FallingConfetti), findsNothing);
      expect(find.byType(IqPodium), findsNothing);
      expect(find.byType(IqLeaderboardRow), findsNothing);
    });
  }
}
