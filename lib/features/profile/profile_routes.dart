import 'package:go_router/go_router.dart';

import '../../core/flags.dart';
import '../../core/transitions.dart';
import '../../router.dart';
import '../settings/account_closing_screen.dart';
import '../settings/delete_account_screen.dart';
import '../settings/notification_preferences_screen.dart';
import 'profile_screen.dart';
import 'your_details_screen.dart';

/// The Profile tab, a branch of the app shell.
final profileTab = GoRoute(
  path: Routes.profile,
  pageBuilder: (context, state) => pushPage(state, const ProfileScreen()),
);

/// Profile's pages open over the tabs (their frames have no dock). Figma
/// wires them Instant; the build pushes them, and Account closing, reached
/// once the account is gone, takes over as a 300 ms flow hand-off.
final profileRoutes = <RouteBase>[
  GoRoute(
    path: Routes.yourDetails,
    pageBuilder: (context, state) => pushPage(state, const YourDetailsScreen()),
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
  ],
];
