import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/data/help_service.dart';
import 'package:iqly_mobile/features/help/help_thread_screen.dart';
import 'package:iqly_mobile/features/help/help_widgets.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/balance_hero.dart';
import 'package:iqly_mobile/ui/chat_bubble.dart';
import 'package:iqly_mobile/ui/proof_tile.dart';

import '../golden/screens/app_harness.dart';
import '../golden/screens/polls_notifications_help_harness.dart';
import '../golden/screens/wallet_harness.dart';

void _reduce(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

Widget _app(Widget child, {bool ticking = true}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: TickerMode(enabled: ticking, child: child),
    ),
  ),
);

double _lowestDot(WidgetTester tester) => tester
    .widgetList<Transform>(
      find.descendant(
        of: find.byType(TypingBubble),
        matching: find.byType(Transform),
      ),
    )
    .map((t) => t.transform.getTranslation().y)
    .reduce((a, b) => a < b ? a : b);

/// Support types 100 ms after the thread is watched and replies 300 later.
DemoHelpService _slowSupport() {
  final times = [DateTime(2026, 10, 3, 14, 20), DateTime(2026, 10, 3, 15, 6)];
  var call = 0;
  return DemoHelpService(
    delay: Duration.zero,
    uploadStep: Duration.zero,
    typingAfter: const Duration(milliseconds: 100),
    replyAfter: const Duration(milliseconds: 300),
    clock: () => times[call < times.length ? call++ : times.length - 1],
  );
}

/// Writes the frame's request with motion off (the empty proof tile
/// breathes forever), then sends it with motion as [reduced] says.
Future<void> _sendFromRequest(
  WidgetTester tester, {
  required bool reduced,
}) async {
  await pumpApp(
    tester,
    Routes.help,
    overrides: [
      ...laneOverrides(help: _slowSupport()),
      ...walletOverrides(),
    ],
  );
  await tester.tap(find.byType(IqProofTile));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(EditableText).first, figmaMessage);
  await tester.pumpAndSettle();
  if (!reduced) {
    tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
    await tester.pump();
  }
  await tester.tap(find.text('Send to support'));
  await tester.pump();
  await tester.pump();
}

void main() {
  group('TypingBubble', () {
    testWidgets('the dots bob 4 px on a 600 ms loop', (tester) async {
      await tester.pumpWidget(_app(const TypingBubble()));
      await tester.pump();
      expect(tester.hasRunningAnimations, isTrue);
      final lows = <double>[];
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        lows.add(_lowestDot(tester));
      }
      expect(lows.reduce((a, b) => a < b ? a : b), closeTo(-4, 0.2));
    });

    testWidgets('reduced motion and hidden tickers: still dots', (
      tester,
    ) async {
      _reduce(tester);
      await tester.pumpWidget(_app(const TypingBubble()));
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.hasRunningAnimations, isFalse);
      expect(_lowestDot(tester), 0);
    });

    testWidgets('with its tickers off it does not ask for frames', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const TypingBubble(), ticking: false));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('Later', () {
    testWidgets('keeps the place see-through, then builds on its beat', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const Later(
            delay: IqDurations.chain,
            standIn: Text('stand-in'),
            child: Text('due'),
          ),
        ),
      );
      expect(find.text('due'), findsNothing);
      expect(
        tester
            .widget<Opacity>(
              find.ancestor(
                of: find.text('stand-in'),
                matching: find.byType(Opacity),
              ),
            )
            .opacity,
        0,
      );
      await tester.pump(const Duration(milliseconds: 119));
      expect(find.text('due'), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('due'), findsOneWidget);
    });
  });

  group('Help thread', () {
    testWidgets('sent: the message arrives at +120, support types, replies, '
        'and the balance rolls at +400', (tester) async {
      await _sendFromRequest(tester, reduced: false);
      expect(find.byType(HelpThreadScreen), findsOneWidget);
      expect(find.byType(Later), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Later),
          matching: find.byWidgetPredicate(
            (w) => w is IqChatBubble && w.animate,
          ),
        ),
        findsNothing,
      );
      await tester.pump(const Duration(milliseconds: 130));
      expect(
        find.byWidgetPredicate((w) => w is IqChatBubble && w.animate),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(TypingBubble), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.byType(TypingBubble), findsNothing);
      expect(find.text('UPDATED BALANCE'), findsOneWidget);
      IqBalanceHero hero() =>
          tester.widget<IqBalanceHero>(find.byType(IqBalanceHero));
      expect(hero().amount, '₦12,500');
      expect(hero().earned, '₦62,500.00');

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(hero().amount, '₦14,000');
      expect(hero().earned, '₦64,000.00');
    });

    testWidgets('reduced motion: the new balance at once', (tester) async {
      await _sendFromRequest(tester, reduced: true);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(
        tester.widget<IqBalanceHero>(find.byType(IqBalanceHero)).amount,
        '₦14,000',
      );
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
