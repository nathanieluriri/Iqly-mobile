import 'package:go_router/go_router.dart';

import '../../core/flags.dart';
import '../../core/responsive.dart';
import '../../core/transitions.dart';
import '../shell/tablet_sheet.dart';
import '../../router.dart';
import 'poll_sheet.dart';
import 'polls_screen.dart';

/// One business's poll sheet over the Quick polls page.
String pollsOf(String businessId) => '${Routes.polls}/$businessId';

/// The same polls as a full page, where the sheet goes when dragged up.
String pollPageOf(String businessId) => '${Routes.polls}/$businessId/full';

/// The Quick polls page as a Discover tile opens it: with [businessId] its
/// sheet rises over the page. A poll's id opens its business's sheet too.
String quickPollsFor(String businessId) => Uri(
  path: Routes.polls,
  queryParameters: {'business': businessId},
).toString();

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
            PollPage(businessId: state.pathParameters['id']!),
          ),
        ),
        GoRoute(
          path: ':id',
          pageBuilder: (context, state) => Layout.isTablet(context)
              ? TabletDialogPage(
                  key: state.pageKey,
                  name: state.name ?? state.path,
                  child: PollSheet(businessId: state.pathParameters['id']!),
                )
              : sheetPage(
                  state,
                  PollSheet(businessId: state.pathParameters['id']!),
                  scrim: IqScrim.sheet,
                  expand: (context) => context.pushReplacement(
                    pollPageOf(state.pathParameters['id']!),
                    extra: Arrival.sheet,
                  ),
                ),
        ),
      ],
    ),
];
