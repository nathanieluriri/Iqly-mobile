import 'package:go_router/go_router.dart';

import '../../core/transitions.dart';
import '../../router.dart';
import 'notification_screen.dart';
import 'notifications_screen.dart';

String notificationPath(String id) => '${Routes.notifications}/$id';

/// B6 Notifications: pushed from the bell and from More; a payout, result
/// or deadline row pushes its Notification sub page.
final notificationsRoutes = <RouteBase>[
  GoRoute(
    path: Routes.notifications,
    pageBuilder: (context, state) =>
        pushPage(state, const NotificationsScreen()),
    routes: [
      GoRoute(
        path: ':id',
        pageBuilder: (context, state) => pushPage(
          state,
          NotificationScreen(id: state.pathParameters['id']!),
        ),
      ),
    ],
  ),
];
