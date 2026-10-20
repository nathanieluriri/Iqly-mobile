import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/transitions.dart';
import '../../router.dart';
import '../../data/help_data.dart';
import '../../data/help_service.dart' show supportChannelsProvider;
import 'chat_inbox_screen.dart';
import 'chat_thread_screen.dart';
import 'help_attachment_screen.dart';
import 'help_centre_screen.dart';
import 'help_request_screen.dart';
import 'help_thread_screen.dart';
import 'legal_screen.dart';
import 'report_screen.dart';
import 'support_screen.dart';

/// How a thread was opened: [sent] from the request it answers, so the
/// message plays its arrival.
enum HelpThreadEntry { sent }

String helpThreadPath(String ticketId) => '${Routes.help}/$ticketId';

/// Ask for help, [about] the activation with that id.
String helpPath({String? about}) => about == null
    ? Routes.help
    : '${Routes.help}?about=${Uri.encodeQueryComponent(about)}';

/// The chat redesign while health says `supportChannels` (and in the
/// preview), else the screen before it.
class _Channels extends ConsumerWidget {
  const _Channels({required this.on, required this.off});

  final Widget on;
  final Widget off;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(supportChannelsProvider) ? on : off;
}

/// B21 Help centre, the one support inbox, Report an issue and the legal
/// pages, every one a push from More. B10 Help: the request pushes from the
/// proof-submitted screen, `?about=` naming the activation it asks about,
/// and Send to support puts the thread in its place; every thread, from the
/// inbox too, is /help/:id, and a file sent in it /help/:id/file.
final helpRoutes = <RouteBase>[
  GoRoute(
    path: Routes.helpCentre,
    pageBuilder: (context, state) => pushPage(
      state,
      HelpCentreScreen(query: state.uri.queryParameters['q'] ?? ''),
    ),
    routes: [
      GoRoute(
        path: 'report',
        pageBuilder: (context, state) =>
            pushPage(state, const ReportIssueScreen()),
        routes: [
          GoRoute(
            path: 'sent',
            pageBuilder: (context, state) => pushPage(
              state,
              ReportSentScreen(ticket: state.extra as String? ?? ''),
            ),
          ),
        ],
      ),
    ],
  ),
  GoRoute(
    path: Routes.support,
    pageBuilder: (context, state) => pushPage(
      state,
      const _Channels(on: ChatInboxScreen(), off: SupportScreen()),
    ),
    routes: [
      GoRoute(
        path: 'new',
        pageBuilder: (context, state) =>
            pushPage(state, const NewConversationScreen()),
      ),
    ],
  ),
  GoRoute(
    path: Routes.terms,
    pageBuilder: (context, state) => pushPage(state, LegalScreen.terms),
  ),
  GoRoute(
    path: Routes.privacy,
    pageBuilder: (context, state) => pushPage(state, LegalScreen.privacy),
  ),
  GoRoute(
    path: Routes.help,
    pageBuilder: (context, state) {
      final about = state.uri.queryParameters['about'];
      return pushPage(
        state,
        _Channels(
          on: about == null
              ? HelpRequestScreen(about: about)
              : ChatThreadScreen(about: about),
          off: HelpRequestScreen(about: about),
        ),
      );
    },
    routes: [
      GoRoute(
        path: ':id',
        pageBuilder: (context, state) => pushPage(
          state,
          _Channels(
            on: ChatThreadScreen(id: state.pathParameters['id']!),
            off: HelpThreadScreen(
              id: state.pathParameters['id']!,
              entry: switch (state.extra) {
                final HelpThreadEntry entry => entry,
                _ => null,
              },
            ),
          ),
        ),
        routes: [
          GoRoute(
            path: 'file',
            pageBuilder: (context, state) => pushPage(
              state,
              HelpAttachmentScreen(
                file: switch (state.extra) {
                  final HelpAttachment file => file,
                  _ => null,
                },
              ),
            ),
          ),
        ],
      ),
    ],
  ),
];
