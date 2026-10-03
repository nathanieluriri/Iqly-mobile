import 'package:go_router/go_router.dart';

import '../../core/transitions.dart';
import '../../router.dart';
import 'help_request_screen.dart';
import 'help_thread_screen.dart';

/// How a thread was opened: [sent] from the request it answers, so the
/// message plays its arrival.
enum HelpThreadEntry { sent }

String helpThreadPath(String ticketId) => '${Routes.help}/$ticketId';

/// B10 Help: the request pushes from the proof-submitted screen (an
/// optional `?about=` names the subject) and Send to support puts the
/// thread in its place. Figma wires both Instant.
final helpRoutes = <RouteBase>[
  GoRoute(
    path: Routes.help,
    pageBuilder: (context, state) => pushPage(
      state,
      HelpRequestScreen(subject: state.uri.queryParameters['about']),
    ),
    routes: [
      GoRoute(
        path: ':id',
        pageBuilder: (context, state) => pushPage(
          state,
          HelpThreadScreen(
            id: state.pathParameters['id']!,
            entry: switch (state.extra) {
              final HelpThreadEntry entry => entry,
              _ => null,
            },
          ),
        ),
      ),
    ],
  ),
];
