import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/drafts/drafts_screen.dart';
import 'package:iqly_mobile/features/submissions/my_submissions_screen.dart';
import 'package:iqly_mobile/features/submit/submit_steps.dart';
import 'package:iqly_mobile/ui/button.dart';
import 'package:iqly_mobile/ui/confirm_sheet.dart';

import '../harness.dart';
import '../steps.dart';

Finder _danger() => find.byWidgetPredicate(
  (w) => w is IqButton && w.kind == IqButtonKind.danger,
  description: 'the Discard button',
);

/// A returning contributor tidies their drafts: from My submissions into
/// Drafts, a long press to select, Select all, Cancel; the Sunline draft
/// opened from its actions sheet with Continue writing, then left with
/// Discard draft; the last draft selected and discarded behind its confirm,
/// which leaves Drafts for My submissions.
void main() {
  film('drafts', prefs: returning, (d) async {
    await onDiscover(d, hold: 1);
    await dockTab(d, 'Submissions');
    await d.waitFor(find.text('Drafts · 2'));
    await d.settle(on: find.byType(MySubmissionsScreen));
    await d.hold(1.5);
    await d.tap(find.text('Drafts · 2'), label: 'drafts-entry');

    await d.arrive(find.byType(DraftsScreen), hold: 1.5);
    await d.longPress(find.text('No light? We dey'), label: 'unibooks-draft');
    await d.waitFor(find.text('1 selected'));
    await d.hold(1.2);
    await d.tap(onlySectionLink, label: 'select-all');
    await d.waitFor(find.text('2 selected'));
    await d.hold(1.2);
    await d.tap(button('Cancel'), label: 'cancel');
    await d.waitFor(find.text('2 drafts'));
    await d.hold(1);

    await d.tap(find.text('Charge up, stay connected'), label: 'sunline-draft');
    await d.arrive(find.byType(IqConfirmSheet), hold: 1.5);
    await d.tap(button('Continue writing'), label: 'continue-writing');
    await d.arrive(find.byType(AnswerStep), hold: 1.8);
    await d.back();
    await d.arrive(find.byType(IqConfirmSheet), hold: 1.5);
    await d.tap(find.text('Discard draft'), label: 'discard-draft');
    await d.gone(find.byType(IqConfirmSheet));
    await d.arrive(find.byType(DraftsScreen), hold: 0.5);
    await d.waitFor(find.text('1 draft'));
    await d.hold(1.2);

    await d.longPress(find.text('No light? We dey'), label: 'unibooks-draft');
    await d.waitFor(find.text('1 selected'));
    await d.hold(1);
    await d.tap(_danger(), label: 'discard-selected');
    await d.arrive(find.byType(IqConfirmSheet), hold: 1.5);
    await d.tap(
      find.descendant(
        of: find.byType(IqConfirmSheet),
        matching: find.byWidgetPredicate(
          (w) => w is IqButton && w.kind == IqButtonKind.primary,
        ),
      ),
      label: 'confirm-discard',
    );

    await d.gone(find.byType(DraftsScreen));
    await d.arrive(find.byType(MySubmissionsScreen), hold: 2);
  });
}
