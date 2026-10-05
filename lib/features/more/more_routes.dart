import 'package:go_router/go_router.dart';

import '../../core/flags.dart';
import '../../core/transitions.dart';
import '../../router.dart';
import 'more_screen.dart';
import 'saved_briefs_page.dart';

/// More, the fourth dock tab, a branch of the app shell.
final moreTab = GoRoute(
  path: Routes.more,
  pageBuilder: (context, state) => pushPage(state, const MoreScreen()),
);

/// Saved briefs inside More (485:39490): a sub page over the shell, so More
/// stays lit underneath (designer answer 27) and Back returns to it.
final moreRoutes = <RouteBase>[
  if (Flags.savedBriefs)
    GoRoute(
      path: Routes.moreSavedBriefs,
      pageBuilder: (context, state) =>
          pushPage(state, const MoreSavedBriefsPage()),
    ),
];
