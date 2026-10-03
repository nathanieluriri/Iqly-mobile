import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iqly_mobile/data/help_service.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/help/help_request_screen.dart';
import 'package:iqly_mobile/features/help/help_thread_screen.dart';
import 'package:iqly_mobile/features/wallet/wallet_screen.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/balance_hero.dart';
import 'package:iqly_mobile/ui/button.dart';
import 'package:iqly_mobile/ui/confirm_sheet.dart';
import 'package:iqly_mobile/ui/proof_tile.dart';
import 'package:iqly_mobile/ui/ticket_tag.dart';
import 'package:iqly_mobile/ui/video_preview.dart';

import '../golden/screens/app_harness.dart';
import '../golden/screens/help_harness.dart';
import '../golden/screens/polls_notifications_help_harness.dart';
import '../golden/screens/wallet_harness.dart';
import 'entry_harness.dart' show recordHaptics;

const _commit = 'HapticFeedbackType.lightImpact';
const _success = 'HapticFeedbackType.successNotification';
const _error = 'HapticFeedbackType.mediumImpact';

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

IqButton _button(WidgetTester tester, String label) => tester.widget<IqButton>(
  find.byWidgetPredicate((w) => w is IqButton && w.label == label),
);

Future<void> _write(WidgetTester tester) async {
  await _tap(tester, find.byType(IqProofTile));
  await tester.enterText(find.byType(EditableText).first, figmaMessage);
  await tester.pumpAndSettle();
}

Future<void> _openFromHome(WidgetTester tester, {HelpService? help}) async {
  await pumpApp(
    tester,
    Routes.home,
    overrides: [
      ...laneOverrides(help: help),
      ...walletOverrides(),
      ...helpActivations(),
    ],
  );
  GoRouter.of(tester.element(find.byType(HomeScreen))).push(kudiBoxHelp);
  await tester.pumpAndSettle();
  expect(find.byType(HelpRequestScreen), findsOneWidget);
}

void main() {
  testWidgets('B10: ask, support replies, the wallet takes the reward', (
    tester,
  ) async {
    final haptics = recordHaptics(tester);
    final help = instantHelp();
    await _openFromHome(tester, help: help);
    expect(find.text('Support replies within 2 hours.'), findsOneWidget);
    expect(find.text('WHAT HAPPENED?'), findsOneWidget);
    expect(find.text('0/1,000 characters'), findsOneWidget);
    expect(_button(tester, 'Send to support').disabled, isTrue);

    await _tap(tester, find.byType(IqProofTile));
    expect(find.byType(IqProofTile), findsNothing);
    expect(find.text('kudi-box-wallet.mp4'), findsOneWidget);
    expect(find.text('12 MB · uploaded, ready to send'), findsOneWidget);
    expect(_button(tester, 'Send to support').disabled, isTrue);

    await tester.enterText(find.byType(EditableText).first, figmaMessage);
    await tester.pumpAndSettle();
    expect(find.text('85/1,000 characters'), findsOneWidget);
    expect(_button(tester, 'Send to support').disabled, isFalse);

    await _tap(tester, find.text('Send to support'));
    expect(haptics, [_commit, _success]);
    expect(find.byType(HelpRequestScreen), findsNothing);
    expect(find.byType(HelpThreadScreen), findsOneWidget);
    expect(help.requests.single.message, figmaMessage);
    expect(help.requests.single.attachment?.name, 'kudi-box-wallet.mp4');

    expect(find.text('Kudi Box activation'), findsOneWidget);
    expect(find.text('Support replied'), findsOneWidget);
    expect(find.text(figmaMessage), findsOneWidget);
    expect(find.text('SAT, 2:20 PM'), findsOneWidget);
    expect(
      find.text('ATTACHED · KUDI-BOX-WALLET.MP4 · 0:31 · 12 MB'),
      findsOneWidget,
    );
    expect(find.text('iQLY support'), findsOneWidget);
    expect(
      find.text(
        'Thanks, Adaeze. All three steps confirmed. ₦1,500.00 is in your '
        'wallet.',
      ),
      findsOneWidget,
    );
    expect(find.text('SAT, 3:06 PM'), findsOneWidget);
    expect(find.text('UPDATED BALANCE'), findsOneWidget);
    final hero = tester.widget<IqBalanceHero>(find.byType(IqBalanceHero));
    expect(hero.amount, '₦14,000');
    expect(hero.decimals, '.00');
    expect(hero.onHold, '₦10,000.00');
    expect(hero.earned, '₦64,000.00');
    expect(hero.holdLabel, 'On hold · 1 pending');
    expect(hero.showWithdraw, isFalse);

    await _tap(tester, find.text('View wallet'));
    expect(find.byType(WalletScreen), findsOneWidget);
    final wallet = tester.widget<IqBalanceHero>(find.byType(IqBalanceHero));
    expect(wallet.amount, '₦14,000');
    expect(wallet.earned, '₦64,000.00');
    expect(find.text('+₦1,500.00'), findsOneWidget);
  });

  testWidgets('B10: Mark as resolved goes back to the screen that asked', (
    tester,
  ) async {
    final haptics = recordHaptics(tester);
    await _openFromHome(tester);
    await _write(tester);
    await _tap(tester, find.text('Send to support'));
    haptics.clear();

    await tester.tap(find.text('Mark as resolved'));
    await tester.pump();
    await tester.pump();
    expect(
      tester.widget<IqTicketTag>(find.byType(IqTicketTag)).kind,
      IqTicketTagKind.resolved,
    );
    expect(find.byType(HelpThreadScreen), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(haptics, [_commit, _success]);
    expect(find.byType(HelpThreadScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('B10: back from the thread skips the request', (tester) async {
    await _openFromHome(tester);
    await _write(tester);
    await _tap(tester, find.text('Send to support'));
    await _tap(tester, find.bySemanticsLabel('Back'));
    expect(find.byType(HelpThreadScreen), findsNothing);
    expect(find.byType(HelpRequestScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  }, semanticsEnabled: true);

  testWidgets('B10: removing the recording asks first', (tester) async {
    await _openFromHome(tester);
    await _tap(tester, find.byType(IqProofTile));
    expect(find.byType(IqVideoPreview), findsOneWidget);

    await _tap(tester, find.bySemanticsLabel('Remove'));
    expect(find.byType(IqConfirmSheet), findsOneWidget);
    expect(
      find.text('You will need to upload it again to send it.'),
      findsOneWidget,
    );
    await _tap(tester, find.text('Keep it'));
    expect(find.byType(IqVideoPreview), findsOneWidget);

    await _tap(tester, find.bySemanticsLabel('Remove'));
    await _tap(tester, find.text('Remove recording'));
    expect(find.byType(IqVideoPreview), findsNothing);
    expect(find.byType(IqProofTile), findsOneWidget);
  }, semanticsEnabled: true);

  testWidgets('B10: a send that fails stays on the request', (tester) async {
    final haptics = recordHaptics(tester);
    await _openFromHome(tester, help: FailingHelpService());
    await _write(tester);
    await _tap(tester, find.text('Send to support'));
    expect(haptics, [_commit, _error]);
    expect(find.byType(HelpRequestScreen), findsOneWidget);
    expect(find.text('Couldn’t send. Check your connection.'), findsOneWidget);
    expect(_button(tester, 'Send to support').disabled, isFalse);

    await tester.enterText(find.byType(EditableText).first, '$figmaMessage ');
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t send. Check your connection.'), findsNothing);
  });

  testWidgets('B10: a reply from the thread joins it', (tester) async {
    await _openFromHome(tester);
    await _write(tester);
    await _tap(tester, find.text('Send to support'));

    final reply = find.byType(EditableText).last;
    await tester.ensureVisible(reply);
    await tester.enterText(reply, 'Thank you!');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(find.text('Thank you!'), findsOneWidget);
    expect(
      tester.widget<IqTicketTag>(find.byType(IqTicketTag)).kind,
      IqTicketTagKind.open,
    );
  });

  testWidgets('B10: support types, then replies', (tester) async {
    await _openFromHome(tester, help: TypingHelpService());
    await _write(tester);
    await _tap(tester, find.text('Send to support'));
    expect(find.text('Open'), findsOneWidget);
    expect(find.bySemanticsLabel('iQLY support is typing'), findsOneWidget);
    expect(find.byType(IqBalanceHero), findsNothing);
  }, semanticsEnabled: true);
}
