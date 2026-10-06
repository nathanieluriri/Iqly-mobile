import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/outcomes/leaderboard_screen.dart';
import 'package:iqly_mobile/features/outcomes/result_screen.dart';
import 'package:iqly_mobile/features/submissions/my_submissions_screen.dart';
import 'package:iqly_mobile/features/submissions/submission_detail_screen.dart';
import 'package:iqly_mobile/features/submissions/submission_widgets.dart';

import '../harness.dart';
import '../steps.dart';

/// A returning contributor opens the app and goes to Submissions: the
/// skeleton on the tab's first visit, each lens in turn, an entry under
/// review swiped back from, and the Not selected result with what won.
void main() {
  film('my_submissions', prefs: returning, (d) async {
    await onDiscover(d, hold: 1.2);

    await dockTab(d, 'Submissions');
    await d.waitFor(find.byType(SkeletonSubmissionCard));
    await d.waitFor(find.text('Bring the shop to the hostel'));
    await d.settle(on: find.byType(MySubmissionsScreen));
    await d.hold(1.8);

    await d.tap(find.text('Bring the shop to the hostel'));
    await d.arrive(find.byType(SubmissionDetailScreen), hold: 2);
    await d.swipeBack();
    await d.arrive(find.byType(MySubmissionsScreen), hold: 1);

    for (final lens in ['Winners · 2', 'Not selected · 1']) {
      await d.tap(find.text(lens));
      await d.settle(on: find.byType(MySubmissionsScreen));
      await d.hold(1.3);
    }

    await d.tap(find.text('One counter for quick jobs'));
    await d.arrive(find.byType(NotSelectedView), hold: 2);
    final won = find.text('See what won');
    await d.reveal(won, listIn(find.byType(NotSelectedView)));
    await d.hold(0.6);
    await d.tap(won, label: 'see-what-won');
    await d.arrive(find.byType(LeaderboardScreen), hold: 2);
    await d.back();
    await d.arrive(find.byType(NotSelectedView), hold: 1);
    await d.back();

    await d.arrive(find.byType(MySubmissionsScreen), hold: 2);
  });
}
