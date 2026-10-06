import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/discover/brief_detail_screen.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/submissions/my_submissions_screen.dart';
import 'package:iqly_mobile/features/submissions/submission_detail_screen.dart';
import 'package:iqly_mobile/features/submit/submit_screen.dart';
import 'package:iqly_mobile/features/submit/submit_sent.dart';
import 'package:iqly_mobile/features/submit/submit_steps.dart';
import 'package:iqly_mobile/features/submit/submit_widgets.dart';
import 'package:iqly_mobile/ui/field.dart';

import '../harness.dart';
import '../steps.dart';

Finder _field(String label) => find.descendant(
  of: find.byWidgetPredicate((w) => w is IqField && w.label == label),
  matching: find.byType(EditableText),
);

/// A returning contributor opens the solar kiosk brief from Discover and
/// starts their submission: the saved draft comes back, they finish the
/// answer, pick a language, say where the line goes, add files from the
/// phone's picker and send. View submission shows it under review, and back
/// lands on My submissions.
void main() {
  film('submit_brief', prefs: returning, (d) async {
    await onDiscover(d, hold: 1.2);

    await d.tap(find.text('All'));
    await d.settle(on: find.byType(HomeScreen));
    await d.hold(1.2);
    final kiosk = briefCard('A tagline for a solar kiosk network');
    await d.reveal(kiosk, listIn(find.byType(HomeScreen)));
    await d.hold(0.5);
    await d.tap(kiosk, label: 'solar-kiosk-brief');
    await d.arrive(find.byType(BriefDetailScreen), hold: 1.2);
    await d.tap(button('Start your submission'), label: 'start-submission');

    await d.arrive(find.byType(AnswerStep), hold: 1.8);
    await d.tap(find.byType(AnswerArea), label: 'answer');
    await d.type(
      '. Sunline keeps your phone charged and your airtime close.',
      cps: 16,
    );
    await d.waitFor(find.text('Ready for the next step'));
    await d.hold(0.8);
    await d.tap(button('Continue'), label: 'continue');

    await d.arrive(find.byType(QuestionsStep), hold: 1);
    await d.tap(find.text('Both, side by side'));
    await d.hold(0.6);
    await d.tap(_field('Where would you put this line first?'), label: 'where');
    await d.type('On the kiosk roof sign', cps: 14);
    await d.hold(0.3);
    await d.submit();
    await d.hold(0.6);
    final attach = find.text('Attachments');
    await d.reveal(attach, listIn(find.byType(QuestionsStep)));
    await d.tap(attach, label: 'attachments');
    await d.waitFor(find.text('Added · 0:42'));
    await d.hold(1.5);
    await d.tap(button('Submit'), label: 'submit');

    await d.arrive(find.byType(SentMoment), hold: 2);
    await d.tap(button('View submission'), label: 'view-submission');

    await d.arrive(find.byType(SubmissionDetailScreen), hold: 2);
    expect(find.byType(SubmitScreen), findsNothing);
    await d.back();

    await d.arrive(find.byType(MySubmissionsScreen), hold: 2);
  });
}
