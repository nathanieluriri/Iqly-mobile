import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/responsive.dart';
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
/// and scroll. Wallet and Profile are placeholders until their rows replace
/// the branch builders.
RouteBase appShellRoute(GlobalKey<NavigatorState> rootKey) =>
    StatefulShellRoute.indexedStack(
      pageBuilder: (context, state, shell) => _dissolve(
        context,
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
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.home,
              pageBuilder: (context, state) => NoTransitionPage(
                key: state.pageKey,
                child: const HomeScreen(),
              ),
              routes: [
                GoRoute(
                  path: 'saved',
                  pageBuilder: (context, state) => NoTransitionPage(
                    key: state.pageKey,
                    child: const SavedBriefsScreen(),
                  ),
                ),
                GoRoute(
                  path: 'filters',
                  parentNavigatorKey: rootKey,
                  pageBuilder: (context, state) => filtersSheetPage(state),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [_tab(Routes.submissions, const MySubmissionsScreen())],
        ),
        StatefulShellBranch(
          routes: [_tab(Routes.wallet, const _TabPlaceholder('Wallet'))],
        ),
        StatefulShellBranch(
          routes: [_tab(Routes.profile, const _TabPlaceholder('Profile'))],
        ),
      ],
    );

/// Pushed over the shell (no dock): brief detail and the screens other rows
/// will fill.
final discoverRoutes = <RouteBase>[
  GoRoute(
    path: Routes.briefDetail,
    pageBuilder: (context, state) => NoTransitionPage(
      key: state.pageKey,
      child: BriefDetailScreen(id: state.pathParameters['id']!),
    ),
    routes: [
      GoRoute(
        path: 'submit',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const _PagePlaceholder('Submit'),
        ),
      ),
    ],
  ),
  _page(Routes.notifications, const _PagePlaceholder('Notifications')),
  _page(Routes.polls, const _PagePlaceholder('Polls')),
  _page(Routes.activations, const _PagePlaceholder('Activations')),
];

GoRoute _tab(String path, Widget screen) => GoRoute(
  path: path,
  pageBuilder: (context, state) =>
      NoTransitionPage(key: state.pageKey, child: screen),
);

GoRoute _page(String path, Widget screen) => GoRoute(
  path: path,
  pageBuilder: (context, state) =>
      NoTransitionPage(key: state.pageKey, child: screen),
);

/// The splash and first run hand off to Discover with a 0.4 s dissolve.
Page<void> _dissolve(BuildContext context, GoRouterState state, Widget child) =>
    CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 400),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
    );

/// Back from a pushed screen, or to Discover when it was opened directly.
void leave(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(Routes.home);
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
