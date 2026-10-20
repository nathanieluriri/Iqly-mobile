import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/drafts/drafts_screen.dart';
import 'package:iqly_mobile/features/more/more_screen.dart';
import 'package:iqly_mobile/features/outcomes/leaderboard_screen.dart';
import 'package:iqly_mobile/features/outcomes/points_leaderboard_screen.dart';
import 'package:iqly_mobile/features/outcomes/result_screen.dart';
import 'package:iqly_mobile/features/submissions/my_submissions_screen.dart';
import 'package:iqly_mobile/features/submissions/submission_detail_screen.dart';
import 'package:iqly_mobile/features/submit/brief_sheet.dart';
import 'package:iqly_mobile/features/submit/submit_header.dart';
import 'package:iqly_mobile/features/submit/submit_steps.dart';
import 'package:iqly_mobile/features/wallet/wallet_screen.dart';
import 'package:iqly_mobile/ui/confirm_sheet.dart';
import 'package:iqly_mobile/ui/quick_action.dart';

import '../harness.dart';
import '../steps.dart';

Finder _round(String label) =>
    find.byWidgetPredicate((w) => w is RoundIconButton && w.label == label);

/// The 6 Oct corrections in one walk: the bottom bar (Discover tapped while
/// lit does nothing, then each tab), the pass's iQL points into the general
/// leaderboard and the More quick link Leaderboard, a result not picked
/// with its Your submission row and its brief leaderboard, and a draft's
/// View the brief sheet, back to the draft as it was.
void main() {
  film('oct6_updates', prefs: returning, (d) async {
    await onDiscover(d, hold: 1);
    await dockTab(d, 'Discover');
    await d.hold(1);
    await dockTab(d, 'Submissions');
    await d.arrive(find.byType(MySubmissionsScreen), hold: 1);
    await dockTab(d, 'Wallet');
    await d.arrive(find.byType(WalletScreen), hold: 1);
    await dockTab(d, 'More');
    await d.arrive(find.byType(MoreScreen), hold: 1.5);

    await d.tap(find.text('1,240'), label: 'pass-points');
    await d.arrive(find.byType(PointsLeaderboardScreen), hold: 2);
    await d.scroll(listIn(find.byType(PointsLeaderboardScreen)), -240);
    await d.hold(1.5);
    await d.back();
    await d.arrive(find.byType(MoreScreen), hold: 1);
    final leaderboard = find.byWidgetPredicate(
      (w) => w is IqQuickAction && w.label == 'Leaderboard',
    );
    await revealAndTap(
      d,
      leaderboard,
      find.byType(MoreScreen),
      label: 'leaderboard-link',
    );
    await d.arrive(find.byType(PointsLeaderboardScreen), hold: 1.5);
    await d.back();
    await d.arrive(find.byType(MoreScreen), hold: 1);

    await dockTab(d, 'Submissions');
    await d.waitFor(find.text('Not selected · 1'));
    await d.settle(on: find.byType(MySubmissionsScreen));
    await d.hold(0.8);
    await d.tap(find.text('Not selected · 1'));
    await d.waitFor(find.text('One counter for quick jobs'));
    await d.settle(on: find.byType(MySubmissionsScreen));
    await d.hold(1);
    await d.tap(find.text('One counter for quick jobs'), label: 'result');
    await d.arrive(find.byType(NotSelectedView), hold: 2);
    await d.tap(find.text('Your submission'), label: 'your-submission');
    await d.arrive(find.byType(SubmissionDetailScreen), hold: 2);
    await d.back();
    await d.arrive(find.byType(NotSelectedView), hold: 1);
    await revealAndTap(
      d,
      find.text('See what won'),
      find.byType(NotSelectedView),
      label: 'see-what-won',
    );
    await d.arrive(find.byType(LeaderboardScreen), hold: 2);
    await d.scroll(listIn(find.byType(LeaderboardScreen)), -300);
    await d.hold(2);
    await d.back();
    await d.arrive(find.byType(NotSelectedView), hold: 0.6);
    await d.back();
    await d.arrive(find.byType(MySubmissionsScreen), hold: 1);

    await d.tap(find.text('Drafts · 2'), label: 'drafts-entry');
    await d.arrive(find.byType(DraftsScreen), hold: 1.2);
    await d.tap(find.text('Charge up, stay connected'), label: 'sunline-draft');
    await d.arrive(find.byType(IqConfirmSheet), hold: 1);
    await d.tap(button('Continue writing'), label: 'continue-writing');
    await d.arrive(find.byType(AnswerStep), hold: 1.5);
    await d.tap(_round('More'), label: 'more');
    await d.tap(find.text('View the brief'), label: 'view-the-brief');
    await d.arrive(find.byType(BriefSheet), hold: 2.5);
    await d.tap(find.text('Back to writing'), label: 'back-to-writing');
    await d.gone(find.byType(BriefSheet));
    await d.arrive(find.byType(AnswerStep), hold: 1.2);
    await d.tap(_round('More'), label: 'more-again');
    await d.tap(find.text('View the brief'), label: 'view-the-brief-again');
    await d.arrive(find.byType(BriefSheet), hold: 1.2);
    await d.tapAt(const Offset(195, 120), label: 'scrim');
    await d.gone(find.byType(BriefSheet));
    await d.arrive(find.byType(AnswerStep), hold: 2);
  });
}
