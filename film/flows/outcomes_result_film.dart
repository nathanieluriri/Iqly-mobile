import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/outcomes/leaderboard_screen.dart';
import 'package:iqly_mobile/features/outcomes/result_screen.dart';
import 'package:iqly_mobile/features/outcomes/share_sheet.dart';
import 'package:iqly_mobile/features/submissions/my_submissions_screen.dart';
import 'package:iqly_mobile/ui/dock.dart';

import '../harness.dart';
import '../steps.dart';

/// A returning contributor signs in, opens the Submissions tab and the
/// winning "Sunday is data day": the Winner result, Share your win and its
/// sheet, closed again, then the leaderboard.
void main() {
  film('outcomes_result', (d) async {
    await signIn(d);

    await d.tap(
      find.descendant(
        of: find.byType(IqDock),
        matching: find.text('Submissions'),
      ),
      label: 'submissions-tab',
    );
    await d.waitFor(find.text('Sunday is data day'));
    await d.settle(on: find.byType(MySubmissionsScreen));
    await d.hold(1.2);
    await d.tap(find.text('Sunday is data day'));

    await d.arrive(find.byType(WinnerView), hold: 1.5);
    await d.tap(find.text('Share your win'));

    await d.arrive(find.byType(ShareSheet), hold: 1.2);
    await closeSheet(d);
    await d.gone(find.byType(ShareSheet));
    await d.settle(on: find.byType(WinnerView));
    await d.hold(0.6);
    await d.tap(find.text('See the leaderboard'));

    await d.arrive(find.byType(LeaderboardScreen), hold: 1.5);
  });
}
