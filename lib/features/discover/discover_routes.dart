import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/transitions.dart';
import '../../data/models.dart';
import '../../router.dart';
import '../../ui/dock.dart';
import '../activations/activations_routes.dart';
import '../notifications/notifications_routes.dart';
import '../polls/polls_routes.dart';
import '../more/more_routes.dart';
import '../submissions/my_submissions_screen.dart';
import '../submit/submit_routes.dart';
import '../wallet/wallet_routes.dart';
import 'app_shell.dart';
import 'brief_detail_screen.dart';
import 'filters_sheet.dart';
import 'home_screen.dart';
import 'saved_briefs_screen.dart';

/// The four dock tabs as a StatefulShellRoute, so each tab keeps its stack
/// and scroll; a dock switch is a cut and the shell arrives by hand-off.
/// The lit tab is inert (designer doc rev 57).
RouteBase appShellRoute(GlobalKey<NavigatorState> rootKey) =>
    StatefulShellRoute(
      pageBuilder: (context, state, shell) => handoffPage(
        state,
        AppShell(
          active: IqDockActive.values[shell.currentIndex],
          onTab: (tab) => shell.goBranch(tab.index),
          child: shell,
        ),
      ),
      navigatorContainerBuilder: TabBranches.builder,
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.home,
              pageBuilder: (context, state) =>
                  pushPage(state, const HomeScreen()),
              routes: [
                GoRoute(
                  path: 'saved',
                  pageBuilder: (context, state) =>
                      stillPage(state, const SavedBriefsScreen()),
                ),
                GoRoute(
                  path: 'filters',
                  parentNavigatorKey: rootKey,
                  pageBuilder: (context, state) => sheetPage(
                    state,
                    const FiltersSheet(),
                    scrim: IqScrim.sheet,
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [_push(Routes.submissions, const MySubmissionsScreen())],
        ),
        StatefulShellBranch(routes: [walletTabRoute(rootKey)]),
        StatefulShellBranch(routes: [moreTab]),
      ],
    );

/// Pushed over the shell (no dock): brief detail and the screens other rows
/// will fill.
final discoverRoutes = <RouteBase>[
  GoRoute(
    path: Routes.briefDetail,
    pageBuilder: (context, state) => pushPage(
      state,
      BriefDetailScreen(
        id: state.pathParameters['id']!,
        initial: switch (state.extra) {
          final Brief brief => brief,
          _ => null,
        },
      ),
    ),
    routes: [...submitRoutes],
  ),
  ...notificationsRoutes,
  ...pollsRoutes,
  ...activationsRoutes,
];

GoRoute _push(String path, Widget screen) => GoRoute(
  path: path,
  pageBuilder: (context, state) => pushPage(state, screen),
);

/// Back from a pushed screen, or to Discover when it was opened directly.
void leave(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(Routes.home, extra: NavDirection.back);
  }
}
