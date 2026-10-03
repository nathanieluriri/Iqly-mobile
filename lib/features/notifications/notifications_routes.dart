import 'package:go_router/go_router.dart';

import '../../core/transitions.dart';
import '../../router.dart';
import 'notifications_screen.dart';

/// B6 Notifications: pushed from the bell (Figma: Instant).
final notificationsRoutes = <RouteBase>[
  GoRoute(
    path: Routes.notifications,
    pageBuilder: (context, state) =>
        pushPage(state, const NotificationsScreen()),
  ),
];
