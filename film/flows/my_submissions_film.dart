import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/submissions/my_submissions_screen.dart';
import 'package:iqly_mobile/features/submissions/submission_detail_screen.dart';
import 'package:iqly_mobile/ui/dock.dart';

import '../harness.dart';

const _returning = <String, Object>{
  'session.signedIn': true,
  'session.onboardingDone': true,
  'session.firstTipSeen': true,
};

/// A returning contributor opens the app on Discover, switches to the
/// Submissions tab, browses the list, opens a submission and swipes back.
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
    await d.waitFor(find.text('LOADING…'));
    await d.waitFor(find.text('Bring the shop to the hostel'));
    await d.settle(on: find.byType(MySubmissionsScreen));
    await d.hold(1.8);

    final list = find
        .descendant(
          of: find.byType(MySubmissionsScreen),
          matching: find.byType(Scrollable),
        )
        .last;
    // The five demo submissions barely overflow the screen: read to the end
    // with a small bounce rather than drag far into overscroll.
    final reach =
        d.tester.state<ScrollableState>(list).position.maxScrollExtent + 48;
    await d.scroll(list, -reach, seconds: 0.6);
    await d.hold(1.5);
    await d.scroll(list, reach, seconds: 0.6);
    await d.hold(1);

    await d.tap(find.text('Bring the shop to the hostel'));
    await d.arrive(find.byType(SubmissionDetailScreen), hold: 2);
    await d.swipeBack();

    await d.arrive(find.byType(MySubmissionsScreen), hold: 2);
  });
}
