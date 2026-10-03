import 'package:go_router/go_router.dart';

import '../../core/flags.dart';
import '../../core/transitions.dart';
import '../../router.dart';
import 'poll_sheet.dart';
import 'polls_screen.dart';

/// One business's poll sheet over the Polls page.
String pollsOf(String businessId) => '${Routes.polls}/$businessId';

/// B2 Polls, behind Flags.polls: the page pushes (Figma: Instant) and a
/// business's polls rise as a sheet on the .5 brand scrim. A Discover bubble
/// opens the page with `?business=` naming whose sheet to raise.
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
          path: ':id',
          pageBuilder: (context, state) => sheetPage(
            state,
            PollSheet(businessId: state.pathParameters['id']!),
            scrim: IqScrim.sheet,
          ),
        ),
      ],
    ),
];
