import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/responsive.dart';
import '../../core/transitions.dart';
import '../../data/models.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/dock.dart';
import '../../ui/top_bar.dart';
import '../profile/profile_routes.dart';
import '../submissions/my_submissions_screen.dart';
import '../wallet/wallet_routes.dart';
import 'app_shell.dart';
import 'brief_detail_screen.dart';
import 'filters_sheet.dart';
import 'home_screen.dart';
import 'saved_briefs_screen.dart';

/// The four dock tabs as a StatefulShellRoute, so each tab keeps its stack
/// and scroll; the tabs cross with the fade-through and the shell arrives by
/// hand-off. Tapping the lit tab pops it to its root, or, at its root,
/// scrolls its list to the top (spec 3.6).
RouteBase appShellRoute(GlobalKey<NavigatorState> rootKey) =>
    StatefulShellRoute(
      pageBuilder: (context, state, shell) => handoffPage(
        state,
        AppShell(
          active: IqDockActive.values[shell.currentIndex],
          atRoot: state.uri.path == _tabRoots[shell.currentIndex],
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
        StatefulShellBranch(routes: [profileTab]),
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
    routes: [_push('submit', const _PagePlaceholder('Submit'))],
  ),
  _push(Routes.notifications, const _PagePlaceholder('Notifications')),
  _push(Routes.polls, const _PagePlaceholder('Polls')),
  _push(Routes.activations, const _PagePlaceholder('Activations')),
];

const _tabRoots = [
  Routes.home,
  Routes.submissions,
  Routes.wallet,
  Routes.profile,
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
