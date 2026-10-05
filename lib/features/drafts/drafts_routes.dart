import 'package:go_router/go_router.dart';

import '../../core/transitions.dart';
import '../../router.dart';
import 'drafts_screen.dart';

/// Drafts is a sub page over the tabs: pushed, Page top bar, no dock.
final draftRoutes = <RouteBase>[
  GoRoute(
    path: Routes.drafts,
    pageBuilder: (context, state) => pushPage(state, const DraftsScreen()),
  ),
];
