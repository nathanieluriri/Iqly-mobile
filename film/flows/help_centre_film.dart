import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/help/help_centre_screen.dart';
import 'package:iqly_mobile/features/help/help_thread_screen.dart';
import 'package:iqly_mobile/features/help/report_screen.dart';
import 'package:iqly_mobile/features/help/support_screen.dart';
import 'package:iqly_mobile/features/more/more_screen.dart';
import 'package:iqly_mobile/ui/faq_sheet.dart';

import '../harness.dart';
import '../steps.dart';

/// A returning contributor whose withdrawal failed looks for help from More:
/// Help centre, a search for "withdraw", the answer's sheet, Chat with us
/// into the one support inbox, a new conversation and support's reply, then
/// back to the Help centre to report an issue with a screenshot.
void main() {
  film('help_centre', prefs: returning, (d) async {
    await onDiscover(d, hold: 1);
    await dockTab(d, 'More');
    await d.waitFor(find.text('Help centre'));
    await d.settle(on: find.byType(MoreScreen));
    await d.hold(1.2);
    await revealAndTap(
      d,
      find.text('Help centre'),
      find.byType(MoreScreen),
      label: 'help-centre',
    );

    await d.arrive(find.byType(HelpCentreScreen), hold: 1.5);
    await d.tap(find.byType(EditableText), label: 'search');
    await d.type('withdraw', cps: 10);
    await d.waitFor(find.text('2 results for "withdraw"'));
    await d.hold(1.5);
    await d.tap(find.text('Why did my withdrawal fail?'));
    await d.arrive(find.byType(IqFaqSheet), hold: 2.5);
    await d.tap(find.text('Still stuck? Chat with us'), label: 'chat-with-us');

    await d.arrive(find.byType(SupportScreen), hold: 1.8);
    await d.tap(button('Start a new conversation'), label: 'new-conversation');
    await d.arrive(find.byType(NewConversationScreen), hold: 0.6);
    await d.tap(find.byType(EditableText), label: 'message');
    await d.type('My bank changed. Can I move the payout?', cps: 16);
    await d.hold(0.8);
    await d.tap(button('Send'), label: 'send');
    await d.arrive(find.byType(HelpThreadScreen), hold: 1);
    await d.hold(6);
    await d.back();
    await d.arrive(find.byType(SupportScreen), hold: 1.2);
    await d.back();

    await d.arrive(find.byType(HelpCentreScreen), hold: 1);
    final report = find.text('Report an issue');
    await revealAndTap(d, report, find.byType(HelpCentreScreen));
    await d.arrive(find.byType(ReportIssueScreen), hold: 0.8);
    await d.tap(find.byType(EditableText), label: 'what-happened');
    await d.type('Withdrawal pending since Monday.', cps: 16);
    await d.hold(0.6);
    await d.tap(find.text('Add a screenshot'), label: 'add-screenshot');
    await d.waitFor(find.text('screenshot.png'));
    await d.hold(1.2);
    await d.tap(button('Send report'), label: 'send-report');
    await d.arrive(find.byType(ReportSentScreen), hold: 2.2);
    await d.tap(button('Back to Help'), label: 'back-to-help');

    await d.arrive(find.byType(HelpCentreScreen), hold: 2);
  });
}
