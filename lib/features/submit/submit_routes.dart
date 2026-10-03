import 'package:go_router/go_router.dart';

import '../../core/transitions.dart';
import 'submit_screen.dart';

/// Under Brief detail (/briefs/:id/submit), pushed (MOTION-SPEC §7.4; Figma
/// wires it Instant). The steps and the sent moment are states of the one
/// page, so the chrome holds still between them.
final submitRoutes = <RouteBase>[
  GoRoute(
    path: 'submit',
    pageBuilder: (context, state) =>
        pushPage(state, SubmitScreen(briefId: state.pathParameters['id']!)),
  ),
];
