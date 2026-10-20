import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/session.dart';
import 'core/transitions.dart';
import 'core/updates.dart';
import 'data/pin_service.dart' show pinServiceProvider;
import 'data/help_service.dart' show supportShownProvider;
import 'data/referrals_service.dart' show referralsShownProvider;
import 'data/repository.dart';
import 'features/avatar/avatar_routes.dart';
import 'features/discover/discover_routes.dart';
import 'features/drafts/drafts_routes.dart';
import 'features/entry/forgot_password_screen.dart';
import 'features/entry/landing_screen.dart';
import 'features/entry/notifications_ask_screen.dart';
import 'features/entry/password_screen.dart';
import 'features/entry/reset_link_sent_screen.dart';
import 'features/entry/sign_in_screen.dart';
import 'features/entry/verify_email_screen.dart';
import 'features/entry/your_name_screen.dart';
import 'features/help/help_routes.dart';
import 'features/more/more_routes.dart';
import 'features/onboarding/onboarding_routes.dart';
import 'features/profile/profile_routes.dart';
import 'features/referrals/referrals_routes.dart';
import 'features/splash/splash_screen.dart';
import 'features/splash/update_screen.dart';
import 'features/submissions/submissions_routes.dart';
import 'features/submit/submit_routes.dart';

abstract final class Routes {
  static const splash = '/splash';

  /// Time to update: all there is while this build is below the minimum.
  static const update = '/update';
  static const landing = '/landing';

  /// An invite link: the landing, holding the friend's code for sign up.
  static const invite = '/invite/:code';
  static const home = '/home';
  static const yourName = '/sign-up/name';
  static const createPassword = '/sign-up/password';
  static const signIn = '/sign-in';
  static const verifyEmail = '/verify-email';
  static const forgotPassword = '/forgot-password';
  static const resetLinkSent = '/forgot-password/sent';
  static const notificationsAsk = '/turn-on-notifications';
  static const onboarding = '/onboarding';
  static const onboardingGender = '/onboarding/gender';
  static const onboardingAboutYou = '/onboarding/about-you';
  static const onboardingWhereYouLive = '/onboarding/where-you-live';
  static const onboardingWhereYouStudied = '/onboarding/where-you-studied';
  static const onboardingYourWork = '/onboarding/your-work';
  static const onboardingAddUniversity = '/onboarding/add-university';
  static const onboardingWhatYouLike = '/onboarding/what-you-like';
  static const onboardingResume = '/onboarding/resume';
  static const onboardingDone = '/onboarding/done';
  static const savedBriefs = '/home/saved';
  static const filters = '/home/filters';
  static const submissions = '/submissions';
  static const submissionDetail = '/submissions/:id';
  static const result = '/submissions/:id/result';
  static const wallet = '/wallet';
  static const withdraw = '/wallet/withdraw';
  static const selectBank = '/wallet/select-bank';
  static const withdrawal = '/wallet/withdrawals/:id';
  static const withdrawalPending = '/wallet/withdrawals/:id/pending';
  static const more = '/more';
  static const profile = '/profile';
  static const notifications = '/notifications';
  static const briefDetail = '/briefs/:id';
  static const submit = '/briefs/:id/submit';
  static const pickBrief = '/pick-a-brief';
  static const drafts = '/drafts';
  static const polls = '/polls';
  static const activations = '/activations';
  static const yourDetails = '/profile/details';
  static const notificationPreferences = '/profile/notifications';
  static const deleteAccount = '/profile/delete-account';
  static const accountClosing = '/account-closing';
  static const restoreAccount = '/restore-account';
  static const phoneCode = '/profile/details/phone/code';
  static const moreSavedBriefs = '/saved-briefs';
  static const tryNotifications = '/try-notifications';
  static const withdrawalPin = '/pin';
  static const withdrawalPinReset = '/pin?reset=1';
  static const referrals = '/referrals';
  static const inviteCode = '/referrals/code';
  static const referralHistory = '/referrals/history';
  static const helpCentre = '/help-centre';
  static const reportIssue = '/help-centre/report';
  static const reportSent = '/help-centre/report/sent';
  static const support = '/support';
  static const newConversation = '/support/new';
  static const avatarEditor = '/avatar';
  static const avatarPhoto = '/avatar/photo';
  static const terms = '/terms';
  static const privacy = '/privacy';

  static String brief(String id) => '/briefs/$id';
  static String submitTo(String id) => '/briefs/$id/submit';
  static const share = '/submissions/:id/result/share';
  static const leaderboard = '/submissions/:id/result/leaderboard';

  /// The general iQL points leaderboard, a sub page.
  static const pointsLeaderboard = '/leaderboard';
  static const activation = '/activations/:id';
  static const activationProof = '/activations/:id/proof';
  static const proofPlayer = '/activations/:id/play';
  static const help = '/help';
}

final routerProvider = Provider<GoRouter>(
  (ref) => buildRouter(
    updateRequired: () => ref.read(updatesProvider.notifier).required,
    hidden: (path) => hiddenRoute(ref.read, path),
  ),
);

/// Whether this launch hides [path]: a live launch has no polls,
/// activations, points board, referrals or support threads while the API
/// does not run them.
bool hiddenRoute(Reader read, String path) {
  bool under(String root) => path == root || path.startsWith('$root/');
  return (!read(pollsShownProvider) && under(Routes.polls)) ||
      (!read(activationsShownProvider) && under(Routes.activations)) ||
      (!read(leaderboardShownProvider) && under(Routes.pointsLeaderboard)) ||
      (!read(referralsShownProvider) && under(Routes.referrals)) ||
      (read(pinServiceProvider) == null && under(Routes.withdrawalPin)) ||
      (!read(supportShownProvider) &&
          (under(Routes.support) ||
              under(Routes.reportIssue) ||
              under(Routes.help)));
}

GoRouter buildRouter({
  String initialLocation = Routes.splash,
  bool Function()? updateRequired,

  /// A path this launch cannot show, such as the preview's polls in a live
  /// launch; it lands on Discover instead.
  bool Function(String path)? hidden,
}) {
  final rootKey = GlobalKey<NavigatorState>();
  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: initialLocation,
    // Never cuts into a screen: an answer that comes late applies at the
    // next screen change. The splash hands over by itself.
    redirect: (context, state) {
      final path = state.uri.path;
      if (path == Routes.update || path == Routes.splash) return null;
      if (updateRequired?.call() == true) return Routes.update;
      return hidden?.call(path) == true ? Routes.home : null;
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        pageBuilder: (context, state) =>
            handoffPage(state, const SplashScreen()),
      ),
      GoRoute(
        path: Routes.update,
        pageBuilder: (context, state) => takeoverPage(
          state,
          UpdateScreen(glide: state.extra == Arrival.lockup),
        ),
      ),
      GoRoute(
        path: Routes.landing,
        pageBuilder: (context, state) =>
            handoffPage(state, const LandingScreen()),
      ),
      GoRoute(
        path: Routes.invite,
        pageBuilder: (context, state) => handoffPage(
          state,
          LandingScreen(invite: state.pathParameters['code']),
        ),
      ),
      appShellRoute(rootKey),
      ...discoverRoutes,
      ..._entryRoutes,
      ...onboardingRoutes,
      ...submissionRoutes,
      ...draftRoutes,
      ...pickBriefRoutes,
      ...moreRoutes,
      ...profileRoutes,
      ...avatarRoutes,
      ...referralsRoutes,
      ...helpRoutes,
    ],
  );
}

/// The sign-up, sign-in and reset steps push; the notifications ask is a
/// push from onboarding Done, or the hand-off from the last step when there
/// is no Done to show.
final _entryRoutes = [
  _push(Routes.yourName, const YourNameScreen()),
  _push(Routes.createPassword, const PasswordScreen()),
  _push(Routes.signIn, const SignInScreen()),
  _push(Routes.verifyEmail, const VerifyEmailScreen()),
  _push(Routes.forgotPassword, const ForgotPasswordScreen()),
  _push(Routes.resetLinkSent, const ResetLinkSentScreen()),
  _push(Routes.notificationsAsk, const NotificationsAskScreen()),
];

GoRoute _push(String path, Widget screen) => GoRoute(
  path: path,
  pageBuilder: (context, state) => pushPage(state, screen),
);
