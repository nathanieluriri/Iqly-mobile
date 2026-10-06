import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/onboarding/resume_screen.dart';
import 'package:iqly_mobile/features/onboarding/about_you_screen.dart';
import 'package:iqly_mobile/features/onboarding/where_you_live_screen.dart';

import '../harness.dart';

/// Signed in, answered About you, reached Where you live and closed the app:
/// the splash opens Resume, Continue picks up there, back returns to
/// Resume, and Start over begins again at About you. The skip half is skip_for_now.
void main() {
  film(
    'resume_and_skip',
    prefs: {
      'session.signedIn': true,
      'onboarding.draft': jsonEncode({
        'occupation': 'student',
        'lastStep': 'whereYouLive',
      }),
    },
    (d) async {
      await d.arrive(find.byType(ResumeScreen), hold: 2);
      await d.tap(find.text('Continue'));

      await d.arrive(find.byType(WhereYouLiveScreen));
      await d.back();

      await d.arrive(find.byType(ResumeScreen), hold: 1.5);
      await d.tap(find.text('Start over'));

      await d.arrive(find.byType(AboutYouScreen), hold: 2);
    },
  );
}
