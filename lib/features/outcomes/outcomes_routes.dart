import 'package:go_router/go_router.dart';

import '../../core/transitions.dart';
import '../../router.dart';
import 'leaderboard_screen.dart';
import 'points_leaderboard_screen.dart';
import 'result_screen.dart';
import 'share_sheet.dart';

String sharePath(String id) => '/submissions/$id/result/share';
String leaderboardPath(String id) => '/submissions/$id/result/leaderboard';

/// The result is a push from My submissions, the leaderboard a push from
/// either result and the share sheet rises over the Winner on the brand .35
/// scrim (MOTION-SPEC §7.8, §3.3; Figma wires them Instant).
final outcomeRoutes = <RouteBase>[
  GoRoute(
    path: Routes.pointsLeaderboard,
    pageBuilder: (context, state) =>
        pushPage(state, const PointsLeaderboardScreen()),
  ),
  GoRoute(
    path: Routes.result,
    pageBuilder: (context, state) =>
        pushPage(state, ResultScreen(id: state.pathParameters['id']!)),
    routes: [
      GoRoute(
        path: 'share',
        pageBuilder: (context, state) => sheetPage(
          state,
          ShareSheet(id: state.pathParameters['id']!),
          scrim: IqScrim.share,
        ),
      ),
      GoRoute(
        path: 'leaderboard',
        pageBuilder: (context, state) =>
            pushPage(state, LeaderboardScreen(id: state.pathParameters['id']!)),
      ),
    ],
  ),
];
