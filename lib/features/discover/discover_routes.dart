import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/responsive.dart';
import '../../core/transitions.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/dock.dart';
import '../../ui/top_bar.dart';
import '../submissions/my_submissions_screen.dart';
import 'app_shell.dart';
import 'brief_detail_screen.dart';
import 'filters_sheet.dart';
import 'home_screen.dart';
import 'saved_briefs_screen.dart';

/// The four dock tabs as a StatefulShellRoute, so each tab keeps its stack
/// and scroll; the tabs cross with the fade-through and the shell arrives by
/// hand-off. Wallet and Profile are placeholders until their rows replace
/// the branch builders.
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
        StatefulShellBranch(
          routes: [_push(Routes.wallet, const _TabPlaceholder('Wallet'))],
        ),
        StatefulShellBranch(
          routes: [_push(Routes.profile, const _TabPlaceholder('Profile'))],
        ),
      ],
    );

/// Pushed over the shell (no dock): brief detail and the screens other rows
/// will fill.
final discoverRoutes = <RouteBase>[
  GoRoute(
    path: Routes.briefDetail,
    pageBuilder: (context, state) =>
        pushPage(state, BriefDetailScreen(id: state.pathParameters['id']!)),
    routes: [_push('submit', const _PagePlaceholder('Submit'))],
  ),
  _push(Routes.notifications, const _PagePlaceholder('Notifications')),
  _push(Routes.polls, const _PagePlaceholder('Polls')),
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

class _TabPlaceholder extends StatelessWidget {
  const _TabPlaceholder(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IqColors.bg,
      body: SafeArea(
        child: CenteredContent(
          child: Padding(
            padding: const EdgeInsets.all(IqSpace.s5),
            child: Text(
              title,
              style: IqText.display.copyWith(color: IqColors.brand),
            ),
          ),
        ),
      ),
    );
  }
}

class _PagePlaceholder extends StatelessWidget {
  const _PagePlaceholder(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
