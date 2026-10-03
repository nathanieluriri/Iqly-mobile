import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/discover/brief_detail_screen.dart';
import 'package:iqly_mobile/features/submissions/submission_detail_screen.dart';
import 'package:iqly_mobile/features/submit/submit_screen.dart';
import 'package:iqly_mobile/features/submit/submit_sent.dart';
import 'package:iqly_mobile/features/submit/submit_steps.dart';
import 'package:iqly_mobile/features/submit/submit_widgets.dart';
import 'package:iqly_mobile/ui/field.dart';
import 'package:iqly_mobile/ui/ticket_card.dart';

import '../harness.dart';
import '../steps.dart';

Finder _field(String label) => find.byWidgetPredicate(
  (w) => w is IqField && w.label == label,
  description: 'the $label field',
);

/// A returning contributor signs in, opens Sunline's solar kiosk brief from
/// Closing soon and submits: a title and an answer past 20 characters, the
/// two quick questions and a photo, then the sent moment and View
/// submission.
void main() {
  film('submit_brief', (d) async {
    await signIn(d);

    await d.tap(
      find.byWidgetPredicate(
        (w) =>
            w is IqTicketCard &&
            w.kind == IqTicketCardKind.hero &&
            w.title == 'A tagline for a solar kiosk network',
      ),
      label: 'solar-kiosk-brief',
    );
    await d.arrive(find.byType(BriefDetailScreen), hold: 1.2);
    await d.tap(find.text('Submit your response'));

    await d.arrive(find.byType(AnswerStep), hold: 0.8);
    await d.tap(_field('Title'), label: 'title');
    await d.type('Sun dey, power dey', cps: 14);
    await d.hold(0.3);
    await d.submit();
    await d.hold(0.3);
    await d.type('Charge your phone and buy airtime, off-grid.', cps: 16);
    await d.waitFor(find.text(readyText));
    await d.hold(0.8);
    await d.tap(find.text('Continue'));

    await d.arrive(find.byType(QuestionsStep), hold: 0.8);
    await d.tap(find.text('Both, side by side'));
    await d.hold(0.6);
    await d.tap(_field('Where would you put this line first?'), label: 'where');
    await d.type('On the kiosk roof sign', cps: 14);
    await d.hold(0.3);
    await d.submit();
    await d.hold(0.4);
    await d.tap(find.text('Attachments'));
    await d.waitFor(find.byType(AttachedFileRow));
    await d.hold(0.8);
    await d.tap(find.text('Send response'));

    await d.arrive(find.byType(SentMoment), hold: 1.5);
    await d.tap(find.text('View submission'));

    await d.arrive(find.byType(SubmissionDetailScreen), hold: 1.5);
    expect(find.byType(SubmitScreen), findsNothing);
  });
}
