import 'package:go_router/go_router.dart';

import '../../core/transitions.dart';
import '../../data/models.dart';
import '../../router.dart';
import '../outcomes/outcomes_routes.dart';
import 'submission_detail_screen.dart';
import 'submission_files.dart';

String submissionPath(String id) => '/submissions/$id';
String resultPath(String id) => '/submissions/$id/result';

/// A picture sent with the entry; the file rides as the route's extra and
/// is read by its id without it.
String submissionFilePath(String id, String fileId) =>
    '/submissions/$id/file/${Uri.encodeComponent(fileId)}';

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
        path: 'file/:fileId',
        pageBuilder: (context, state) => pushPage(
          state,
          SubmissionFileScreen(
            submissionId: state.pathParameters['id']!,
            fileId: state.pathParameters['fileId']!,
            file: switch (state.extra) {
              final SubmissionFile file => file,
              _ => null,
            },
          ),
        ),
      ),
      GoRoute(
        path: 'file',
        redirect: (context, state) =>
            submissionPath(state.pathParameters['id']!),
      ),
    ],
  ),
  ...outcomeRoutes,
];
