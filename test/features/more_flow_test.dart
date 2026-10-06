import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iqly_mobile/data/referrals_service.dart';
import 'package:iqly_mobile/features/entry/landing_screen.dart';
import 'package:iqly_mobile/features/more/more_screen.dart';
import 'package:iqly_mobile/features/profile/profile_routes.dart';
import 'package:iqly_mobile/features/profile/your_details_screen.dart';
import 'package:iqly_mobile/features/settings/account_closing_screen.dart';
import 'package:iqly_mobile/features/wallet/wallet_state.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/button.dart';
import 'package:iqly_mobile/ui/dock.dart';
import 'package:iqly_mobile/ui/top_bar.dart';

import '../golden/golden.dart' show loadAppFonts;
import '../golden/screens/more_harness.dart';
import '../golden/screens/profile_harness.dart';

String _path(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first)).state.uri.path;

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _back(WidgetTester tester) async {
  final bar = find.byType(IqTopBar).last;
  await tester.tap(
    find.descendant(of: bar, matching: find.byType(GestureDetector)).first,
  );
  await tester.pumpAndSettle();
}

IqButton _button(WidgetTester tester, String label) =>
    tester.widget<IqButton>(find.widgetWithText(IqButton, label));

void main() {
  setUpAll(loadAppFonts);

  testWidgets('More is the fourth tab; its pages open over it without the '
      'dock and Back returns to it', (tester) async {
    await pumpMore(tester, Routes.more);
    expect(find.byType(MoreScreen), findsOneWidget);
    expect(
      tester.widget<IqDock>(find.byType(IqDock)).active,
      IqDockActive.more,
    );

    for (final (label, path) in [
      ('Your details', Routes.yourDetails),
      ('Notifications', Routes.notifications),
      ('Help centre', Routes.helpCentre),
      ('Terms and conditions', Routes.terms),
    ]) {
      await _tap(tester, find.text(label).first);
      expect(_path(tester), path);
      expect(find.byType(IqDock), findsNothing);
      await _back(tester);
      expect(_path(tester), Routes.more);
      expect(find.byType(IqDock), findsOneWidget);
    }
  });

  testWidgets('the pass foots to the wallet: earned ₦65,000.00 with the '
      'referral and activation rewards, ₦15,000.00 available', (tester) async {
    final container = await pumpMore(tester, Routes.more);
    final wallet = await container.read(walletProvider.future);
    expect(wallet.totals.totalEarnedKobo, 6500000);
    expect(wallet.totals.withdrawableKobo, 1500000);
    expect(referralEarnedKobo(wallet.ledger), 100000);
    expect(find.text('₦65,000.00'), findsOneWidget);
    expect(find.text('Volt Riders'), findsOneWidget);
    expect(find.text('3 joined'), findsOneWidget);
  });

  testWidgets('Edit · Interests saves at two or more and Your details reads '
      'the new picks', (tester) async {
    final service = TestProfileService();
    await pumpMore(tester, Routes.yourDetails, profile: service);
    await _tap(tester, find.text('Interests'));
    expect(_path(tester), editDetailPath(DetailField.interests));
    await _tap(tester, find.text('Finance & fintech'));
    expect(_button(tester, 'Save').disabled, isTrue);
    await _tap(tester, find.text('Health'));
    expect(_button(tester, 'Save').disabled, isFalse);
    await _tap(tester, find.text('Save'));
    expect(_path(tester), Routes.yourDetails);
    expect(
      find.text('Marketing & advertising · Health & wellness'),
      findsNothing,
    );
    expect(find.text('Marketing & advertising · Health'), findsOneWidget);
    expect(service.saves, 1);
  });

  testWidgets('a new phone number is confirmed with the code before it '
      'saves', (tester) async {
    final service = TestProfileService();
    await pumpMore(tester, Routes.yourDetails, profile: service);
    await _tap(tester, find.text('Phone number'));
    await tester.enterText(find.byType(EditableText), '+234 803 555 4410');
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Save'));
    expect(_path(tester), Routes.phoneCode);
    expect(_button(tester, 'Confirm').disabled, isTrue);
    await tester.enterText(find.byType(EditableText), '482152');
    await tester.pumpAndSettle();
    expect(find.text('482 152'), findsOneWidget);
    await _tap(tester, find.text('Confirm'));
    expect(_path(tester), Routes.yourDetails);
    expect(find.text('+234 803 555 4410'), findsOneWidget);
    expect(service.details.phone, '+234 803 555 4410');
  });

  testWidgets('a refused save keeps the page and says so', (tester) async {
    final service = TestProfileService()..fail = true;
    await pumpMore(
      tester,
      editDetailPath(DetailField.occupation),
      profile: service,
    );
    await _tap(tester, find.text('Employed'));
    await _tap(tester, find.text('Save'));
    expect(_path(tester), editDetailPath(DetailField.occupation));
    expect(find.text('Not saved. Check your connection.'), findsOneWidget);
  });

  testWidgets('Sign out asks first; Stay signed in keeps the session, Sign '
      'out lands on the landing', (tester) async {
    await pumpMore(tester, Routes.profile);
    await _tap(tester, find.text('Sign out'));
    expect(find.text('Sign out?'), findsOneWidget);
    await _tap(tester, find.text('Stay signed in'));
    expect(_path(tester), Routes.profile);
    await _tap(tester, find.text('Sign out'));
    await tester.tap(find.widgetWithText(IqButton, 'Sign out'));
    await tester.pumpAndSettle();
    expect(find.byType(LandingScreen), findsOneWidget);
  });

  testWidgets('Delete stays locked until the wallet is at ₦0.00', (
    tester,
  ) async {
    await pumpMore(tester, Routes.deleteAccount);
    await tester.enterText(find.byType(EditableText), 'delete');
    await tester.pumpAndSettle();
    expect(_button(tester, 'Delete my account').disabled, isTrue);
  });

  testWidgets('at ₦0.00 typed DELETE closes the account', (tester) async {
    final service = TestProfileService();
    await pumpMore(
      tester,
      Routes.deleteAccount,
      repository: EmptyWalletRepository(),
      profile: service,
    );
    await tester.enterText(find.byType(EditableText), 'delete');
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Delete my account'));
    expect(find.byType(AccountClosingScreen), findsOneWidget);
    expect(service.deletions, 1);
  });

  testWidgets('a payout notification opens its sub page, whose button opens '
      'the withdrawal; Back returns to the sub page', (tester) async {
    await pumpMore(tester, Routes.notifications);
    await _tap(tester, find.text('₦40,000.00 paid out', findRichText: true));
    expect(_path(tester), '${Routes.notifications}/n5');
    await _tap(tester, find.text('Open wallet'));
    expect(_path(tester), '/wallet/withdrawals/w2');
    await _back(tester);
    expect(_path(tester), '${Routes.notifications}/n5');
  });

  testWidgets('the result notification leads to the result, the deadline to '
      'the brief', (tester) async {
    await pumpMore(tester, Routes.notifications);
    await _tap(tester, find.text('You won ₦12,500.00', findRichText: true));
    await _tap(tester, find.text('See the result'));
    expect(_path(tester), '/submissions/s2/result');
    await _back(tester);
    await _back(tester);
    await _tap(
      tester,
      find.text('Kudi Box closes tomorrow', findRichText: true),
    );
    await _tap(tester, find.text('See the brief'));
    expect(_path(tester), Routes.brief('c4'));
  });

  testWidgets('an invite code: wrong, then right, then Done back to '
      'Referrals', (tester) async {
    await pumpMore(tester, Routes.referrals);
    expect(find.text('Enter an invite code'), findsNothing);
    GoRouter.of(tester.element(find.byType(Navigator).first))
        .push(Routes.inviteCode);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'nope');
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Apply code'));
    expect(
      find.text('That code doesn’t exist. Check it with your friend.'),
      findsOneWidget,
    );
    expect(_button(tester, 'Apply code').disabled, isTrue);
    await tester.enterText(find.byType(EditableText), 'tunde07');
    await tester.pumpAndSettle();
    expect(find.text('Chidi A. invited you'), findsOneWidget);
    await _tap(tester, find.text('Apply code'));
    expect(
      find.text('You’re in. You both get ₦500 when you win your first brief.'),
      findsOneWidget,
    );
    await _tap(tester, find.text('Done'));
    expect(_path(tester), Routes.referrals);
  });

  testWidgets('Help: a search filters the questions, an answer leads to the '
      'one support inbox', (tester) async {
    await pumpMore(tester, Routes.helpCentre);
    await tester.enterText(find.byType(EditableText), 'withdraw');
    await tester.pumpAndSettle();
    expect(find.text('2 results for "withdraw"'), findsOneWidget);
    await _tap(tester, find.text('Why did my withdrawal fail?'));
    await _tap(tester, find.text('Still stuck? Chat with us'));
    expect(_path(tester), Routes.support);
    expect(find.text('Withdrawal to Access Bank'), findsOneWidget);
    expect(find.text('Kudi Box · step 2 proof'), findsOneWidget);
    await _tap(tester, find.text('Start a new conversation'));
    await tester.enterText(find.byType(EditableText), 'My bank changed.');
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Send'));
    expect(find.text('Chat with iQLY support'), findsOneWidget);
    await _back(tester);
    expect(_path(tester), Routes.support);
    expect(find.text('Chat with iQLY support'), findsOneWidget);
  });

  testWidgets('Help: coming back from what the search led to leaves the '
      'keyboard down', (tester) async {
    bool searching() => tester
        .widget<EditableText>(find.byType(EditableText))
        .focusNode
        .hasFocus;
    await pumpMore(tester, Routes.helpCentre);
    await tester.showKeyboard(find.byType(EditableText));
    await tester.enterText(find.byType(EditableText), 'withdraw');
    await tester.pumpAndSettle();
    expect(searching(), isTrue);
    await _tap(tester, find.text('Why did my withdrawal fail?'));
    await _tap(tester, find.text('Still stuck? Chat with us'));
    expect(_path(tester), Routes.support);
    await _back(tester);
    expect(_path(tester), Routes.helpCentre);
    expect(searching(), isFalse);

    await tester.showKeyboard(find.byType(EditableText));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Report an issue'));
    await _back(tester);
    expect(_path(tester), Routes.helpCentre);
    expect(searching(), isFalse);
  });

  testWidgets('Report sent holds still under the keyboard left over from '
      'the report', (tester) async {
    await pumpMore(tester, Routes.helpCentre);
    await _tap(tester, find.text('Report an issue'));
    tester.view.viewInsets = const FakeViewPadding(bottom: 336);
    await tester.pump();
    GoRouter.of(tester.element(find.byType(Navigator).first))
        .pushReplacement(Routes.reportSent, extra: 'IQ-HELP-2041');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Report sent'), findsOneWidget);
  });

  testWidgets('a report takes a screenshot from the phone and comes back to '
      'Help', (tester) async {
    await pumpMore(tester, Routes.helpCentre);
    await _tap(tester, find.text('Report an issue'));
    await tester.enterText(find.byType(EditableText), 'Pending since Monday.');
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Add a screenshot'));
    expect(find.text('screenshot.png'), findsOneWidget);
    await _tap(tester, find.text('Send report'));
    expect(find.textContaining('Ticket IQ-HELP-2041.'), findsOneWidget);
    await _tap(tester, find.text('Back to Help'));
    expect(_path(tester), Routes.helpCentre);
  });
}
