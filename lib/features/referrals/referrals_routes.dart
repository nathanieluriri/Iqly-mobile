import 'package:go_router/go_router.dart';

import '../../core/transitions.dart';
import '../../router.dart';
import 'invite_code_screen.dart';
import 'referral_history_screen.dart';
import 'referrals_screen.dart';

/// B20 Referrals: pushed from the invite card on More and the Discover
/// gift; Enter invite code and Referral history push over it.
final referralsRoutes = <RouteBase>[
  GoRoute(
    path: Routes.referrals,
    pageBuilder: (context, state) => pushPage(state, const ReferralsScreen()),
    routes: [
      GoRoute(
        path: 'code',
        pageBuilder: (context, state) =>
            pushPage(state, const InviteCodeScreen()),
      ),
      GoRoute(
        path: 'history',
        pageBuilder: (context, state) =>
            pushPage(state, const ReferralHistoryScreen()),
      ),
    ],
  ),
];
