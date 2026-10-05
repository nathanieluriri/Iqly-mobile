import 'package:go_router/go_router.dart';

import '../../core/transitions.dart';
import '../../router.dart';
import 'pick_brief_screen.dart';
import 'submit_screen.dart';

/// Under Brief detail (/briefs/:id/submit), pushed. The steps and the sent
/// moment are states of the one page, so the chrome holds still between
/// them. Drafts pushes the same route to resume a draft, so back returns to
/// whichever page opened it.
final submitRoutes = <RouteBase>[
  GoRoute(
    path: 'submit',
    pageBuilder: (context, state) =>
        pushPage(state, SubmitScreen(briefId: state.pathParameters['id']!)),
  ),
];

/// Pick a brief (409:75), a sub page over the tabs.
final pickBriefRoutes = <RouteBase>[
  GoRoute(
    path: Routes.pickBrief,
    pageBuilder: (context, state) => pushPage(state, const PickBriefScreen()),
  ),
];
