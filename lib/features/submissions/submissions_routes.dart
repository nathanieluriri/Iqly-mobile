import 'package:go_router/go_router.dart';

import '../../core/transitions.dart';
import '../../data/models.dart';
import '../../router.dart';
import '../outcomes/outcomes_routes.dart';
import 'submission_detail_screen.dart';
import 'submission_files.dart';

String submissionPath(String id) => '/submissions/$id';
String resultPath(String id) => '/submissions/$id/result';

/// A picture sent with the entry, which rides as the route's extra.
String submissionFilePath(String id) => '/submissions/$id/file';

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
    routes: [
      GoRoute(
        path: 'file',
        pageBuilder: (context, state) => pushPage(
          state,
          SubmissionFileScreen(
            submissionId: state.pathParameters['id']!,
            file: switch (state.extra) {
              final SubmissionFile file => file,
              _ => null,
            },
          ),
        ),
      ),
    ],
  ),
  ...outcomeRoutes,
];
