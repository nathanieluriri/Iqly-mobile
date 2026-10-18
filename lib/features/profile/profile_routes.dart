import 'package:go_router/go_router.dart';

import '../../core/flags.dart';
import '../../core/transitions.dart';
import '../../router.dart';
import '../settings/account_closing_screen.dart';
import '../settings/delete_account_screen.dart';
import '../settings/notification_preferences_screen.dart';
import '../settings/restore_account_screen.dart';
import 'edit_detail_screen.dart';
import 'profile_screen.dart';
import 'your_details_screen.dart';

String editDetailPath(DetailField field) =>
    '${Routes.yourDetails}/${field.slug}';

/// Your profile, Your details and its Edit pages, and the B14 settings: sub
/// pages over the shell (no dock), each a push. Account closing and Restore
/// take over from the session as hand-offs.
final profileRoutes = <RouteBase>[
  GoRoute(
    path: Routes.profile,
    pageBuilder: (context, state) => pushPage(state, const ProfileScreen()),
  ),
  GoRoute(
    path: Routes.yourDetails,
    pageBuilder: (context, state) => pushPage(state, const YourDetailsScreen()),
    routes: [
      GoRoute(
        path: ':field',
        redirect: (context, state) =>
            DetailField.of(state.pathParameters['field']!) == null
            ? Routes.yourDetails
            : null,
        pageBuilder: (context, state) => pushPage(
          state,
          EditDetailScreen(
            field: DetailField.of(state.pathParameters['field']!)!,
          ),
        ),
        routes: [
          GoRoute(
            path: 'code',
            pageBuilder: (context, state) =>
                pushPage(state, switch (state.extra) {
                  PhoneCodeArgs(:final to, :final resendAt) => PhoneCodeScreen(
                    phone: to,
                    resendAt: resendAt,
                  ),
                  final String phone => PhoneCodeScreen(phone: phone),
                  _ => const PhoneCodeScreen(phone: ''),
                }),
          ),
        ],
      ),
    ],
  ),
  if (Flags.notificationPreferences)
    GoRoute(
      path: Routes.notificationPreferences,
      pageBuilder: (context, state) =>
          pushPage(state, const NotificationPreferencesScreen()),
    ),
  if (Flags.deleteAccount) ...[
    GoRoute(
      path: Routes.deleteAccount,
      pageBuilder: (context, state) =>
          pushPage(state, const DeleteAccountScreen()),
    ),
    GoRoute(
      path: Routes.accountClosing,
      pageBuilder: (context, state) => handoffPage(
        state,
        AccountClosingScreen(email: state.extra as String?),
      ),
    ),
    GoRoute(
      path: Routes.restoreAccount,
      pageBuilder: (context, state) => handoffPage(
        state,
        RestoreAccountScreen(closesOn: state.extra as DateTime?),
      ),
    ),
  ],
];
