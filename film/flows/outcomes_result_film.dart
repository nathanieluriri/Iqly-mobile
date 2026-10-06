import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/outcomes/leaderboard_screen.dart';
import 'package:iqly_mobile/features/outcomes/result_screen.dart';
import 'package:iqly_mobile/features/outcomes/share_sheet.dart';
import 'package:iqly_mobile/features/submissions/my_submissions_screen.dart';

import '../harness.dart';
import '../steps.dart';

/// Sign in, then a win: Submissions, the Winners lens, the winning entry's
/// result, Share your win and its sheet, the leaderboard, and back to the
/// result and on to My submissions.
void main() {
  film('outcomes_result', (d) async {
    await signIn(d);

    await dockTab(d, 'Submissions');
    await d.waitFor(find.text('Winners · 2'));
    await d.settle(on: find.byType(MySubmissionsScreen));
    await d.hold(1);
    await d.tap(find.text('Winners · 2'));
    await d.waitFor(find.text('Sunday is data day'));
    await d.settle(on: find.byType(MySubmissionsScreen));
    await d.hold(1.2);
    await d.tap(find.text('Sunday is data day'));

    await d.arrive(find.byType(WinnerView), hold: 2.5);
    await d.tap(button('Share your win'), label: 'share-your-win');

    await d.arrive(find.byType(ShareSheet), hold: 1.5);
    await closeSheet(d);
    await d.gone(find.byType(ShareSheet));
    await d.settle(on: find.byType(WinnerView));
    await d.hold(0.8);
    final board = find.text('See the leaderboard');
    await d.reveal(board, listIn(find.byType(WinnerView)));
    await d.hold(0.4);
    await d.tap(board, label: 'see-the-leaderboard');

    await d.arrive(find.byType(LeaderboardScreen), hold: 2);
    await d.back();
    await d.arrive(find.byType(WinnerView), hold: 1);
    await d.back();

    await d.arrive(find.byType(MySubmissionsScreen), hold: 2);
  });
}
