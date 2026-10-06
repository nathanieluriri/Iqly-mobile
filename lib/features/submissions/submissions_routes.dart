import 'package:go_router/go_router.dart';

import '../../core/transitions.dart';
import '../../router.dart';
import '../outcomes/outcomes_routes.dart';
import 'submission_detail_screen.dart';

String submissionPath(String id) => '/submissions/$id';
String resultPath(String id) => '/submissions/$id/result';

/// Detail and result open over the tabs (their frames have no dock), so
/// they are top-level routes beside the shell, pushed (spec 3.1; Figma wires
/// them Instant).
final submissionRoutes = <RouteBase>[
  GoRoute(
    path: Routes.submissionDetail,
    pageBuilder: (context, state) => pushPage(
      state,
      SubmissionDetailScreen(id: state.pathParameters['id']!),
    ),
  ),
  ...outcomeRoutes,
];
