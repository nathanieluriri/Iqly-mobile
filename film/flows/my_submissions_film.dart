import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/submissions/my_submissions_screen.dart';
import 'package:iqly_mobile/features/submissions/submission_detail_screen.dart';
import 'package:iqly_mobile/features/submissions/submission_widgets.dart';
import 'package:iqly_mobile/ui/dock.dart';

import '../harness.dart';

const _returning = <String, Object>{
  'session.signedIn': true,
  'session.onboardingDone': true,
  'session.firstTipSeen': true,
};

/// A returning contributor opens the app on Discover, switches to the
/// Submissions tab, looks through the three lenses, opens a submission and
/// swipes back.
void main() {
  film('my_submissions', prefs: _returning, (d) async {
    await d.waitFor(find.byType(HomeScreen));
    await d.waitFor(find.text('Closing soon'));
    await d.settle(on: find.byType(HomeScreen));
    await d.hold(1.5);

    await d.tap(
      find.descendant(
        of: find.byType(IqDock),
        matching: find.text('Submissions'),
      ),
      label: 'submissions-tab',
    );
    await d.waitFor(find.byType(SkeletonSubmissionCard));
    await d.waitFor(find.text('Bring the shop to the hostel'));
    await d.settle(on: find.byType(MySubmissionsScreen));
    await d.hold(1.8);

    for (final lens in [
      'Winners · 2',
      'Not selected · 1',
      'Under review · 2',
    ]) {
      await d.tap(find.text(lens));
      await d.settle(on: find.byType(MySubmissionsScreen));
      await d.hold(1.2);
    }

    await d.tap(find.text('Bring the shop to the hostel'));
    await d.arrive(find.byType(SubmissionDetailScreen), hold: 2);
    await d.swipeBack();

    await d.arrive(find.byType(MySubmissionsScreen), hold: 2);
  });
}
