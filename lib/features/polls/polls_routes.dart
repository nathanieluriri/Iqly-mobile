import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../core/flags.dart';
import '../../core/responsive.dart';
import '../../core/transitions.dart';
import '../shell/tablet_sheet.dart';
import '../../router.dart';
import 'poll_sheet.dart';
import 'polls_screen.dart';

/// One business's poll sheet over the Quick polls page.
String pollsOf(String businessId, {String? pollId, bool history = false}) =>
    _pollPath('${Routes.polls}/$businessId', pollId, history);

/// The same polls as a full page, where the sheet goes when dragged up.
String pollPageOf(String businessId, {String? pollId, bool history = false}) =>
    _pollPath('${Routes.polls}/$businessId/full', pollId, history);

/// One business's poll sheet over Discover, so closing it stays on Discover.
String discoverPollOf(
  String businessId, {
  String? pollId,
  bool history = false,
}) => _pollPath('${Routes.home}/poll/$businessId', pollId, history);

/// The Discover sheet dragged up: the same polls as a page over Discover.
String discoverPollPageOf(
  String businessId, {
  String? pollId,
  bool history = false,
}) => _pollPath('${Routes.home}/poll/$businessId/full', pollId, history);

String _pollPath(String path, String? pollId, bool history) {
  final query = Uri(
    queryParameters: {'poll': ?pollId, if (history) 'history': '1'},
  ).query;
  return query.isEmpty ? path : '$path?$query';
}

/// The Quick polls page as a Discover tile opens it: with [businessId] its
/// sheet rises over the page. A poll's id opens its business's sheet too.
String quickPollsFor(String businessId) => Uri(
  path: Routes.polls,
  queryParameters: {'business': businessId},
).toString();

Page<void> _pollSheetPage(
  BuildContext context,
  GoRouterState state,
  String Function(String id, {String? pollId, bool history}) fullOf,
) {
  final id = state.pathParameters['id']!;
  final pollId = state.uri.queryParameters['poll'];
  final history = state.uri.queryParameters['history'] == '1';
  final sheet = PollSheet(businessId: id, pollId: pollId, history: history);
  return Layout.isTablet(context)
      ? TabletDialogPage(
          key: state.pageKey,
          name: state.name ?? state.path,
          child: sheet,
        )
      : sheetPage(
          state,
          sheet,
          scrim: IqScrim.sheet,
          expand: (context) => context.pushReplacement(
            fullOf(id, pollId: pollId, history: history),
            extra: Arrival.sheet,
          ),
        );
}

/// A Discover tile's poll, on the root navigator so the sheet covers the dock
/// and closing it pops back to Discover.
GoRoute discoverPollRoute(GlobalKey<NavigatorState> rootKey) => GoRoute(
  path: 'poll/:id',
  parentNavigatorKey: rootKey,
  pageBuilder: (context, state) =>
      _pollSheetPage(context, state, discoverPollPageOf),
  routes: [
    GoRoute(
      path: 'full',
      parentNavigatorKey: rootKey,
      pageBuilder: (context, state) => pushPage(
        state,
        PollPage(
          businessId: state.pathParameters['id']!,
          pollId: state.uri.queryParameters['poll'],
          history: state.uri.queryParameters['history'] == '1',
        ),
      ),
    ),
  ],
);

/// B2 Quick polls, behind Flags.polls: a sub page (Page top bar, Back, no
/// dock) that pushes; a business's polls rise as a sheet on the sheet scrim,
/// which a drag up opens as a full page.
final pollsRoutes = <RouteBase>[
  if (Flags.polls)
    GoRoute(
      path: Routes.polls,
      pageBuilder: (context, state) => pushPage(
        state,
        PollsScreen(open: state.uri.queryParameters['business']),
      ),
      routes: [
        GoRoute(
          path: ':id/full',
          pageBuilder: (context, state) => pushPage(
            state,
            PollPage(
              businessId: state.pathParameters['id']!,
              pollId: state.uri.queryParameters['poll'],
              history: state.uri.queryParameters['history'] == '1',
            ),
          ),
        ),
        GoRoute(
          path: ':id',
          pageBuilder: (context, state) =>
              _pollSheetPage(context, state, pollPageOf),
        ),
      ],
    ),
];
