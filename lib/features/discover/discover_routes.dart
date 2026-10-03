import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/responsive.dart';
import '../../core/transitions.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/dock.dart';
import '../../ui/top_bar.dart';
import '../notifications/notifications_routes.dart';
import '../polls/polls_routes.dart';
import '../profile/profile_routes.dart';
import '../submissions/my_submissions_screen.dart';
import '../submit/submit_routes.dart';
import '../wallet/wallet_routes.dart';
import 'app_shell.dart';
import 'brief_detail_screen.dart';
import 'filters_sheet.dart';
import 'home_screen.dart';
import 'saved_briefs_screen.dart';

/// The four dock tabs as a StatefulShellRoute, so each tab keeps its stack
/// and scroll; the tabs cross with the fade-through and the shell arrives by
/// hand-off.
RouteBase appShellRoute(GlobalKey<NavigatorState> rootKey) =>
    StatefulShellRoute(
      pageBuilder: (context, state, shell) => handoffPage(
        state,
        AppShell(
          active: IqDockActive.values[shell.currentIndex],
          onTab: (tab) => shell.goBranch(
            tab.index,
            initialLocation: tab.index == shell.currentIndex,
          ),
          child: shell,
        ),
      ),
      navigatorContainerBuilder: FadeThroughBranches.builder,
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
                      lensPage(state, const SavedBriefsScreen()),
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
        StatefulShellBranch(routes: [profileTab]),
      ],
    );

/// Pushed over the shell (no dock): brief detail and the screens other rows
/// will fill.
final discoverRoutes = <RouteBase>[
  GoRoute(
    path: Routes.briefDetail,
    pageBuilder: (context, state) =>
        pushPage(state, BriefDetailScreen(id: state.pathParameters['id']!)),
    routes: [...submitRoutes],
  ),
  ...notificationsRoutes,
  ...pollsRoutes,
  _push(Routes.activations, const _PagePlaceholder('Activations')),
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

class _PagePlaceholder extends StatelessWidget {
  const _PagePlaceholder(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: IqColors.bg,
      body: SafeArea(
        child: CenteredContent(
          child: IqTopBar(
            variant: IqTopBarVariant.page,
            title: title,
            onBack: () => leave(context),
          ),
        ),
      ),
    );
  }
}
