import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/data/help_service.dart';
import 'package:iqly_mobile/features/help/help_thread_screen.dart';
import 'package:iqly_mobile/features/help/help_widgets.dart';
import 'package:iqly_mobile/ui/balance_hero.dart';
import 'package:iqly_mobile/ui/chat_bubble.dart';
import 'package:iqly_mobile/ui/field.dart';
import 'package:iqly_mobile/ui/proof_tile.dart';

import '../golden/screens/app_harness.dart';
import '../golden/screens/help_harness.dart';
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
    kudiBoxHelp,
    overrides: [
      ...laneOverrides(help: _slowSupport()),
      ...walletOverrides(),
      ...helpActivations(),
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
    testWidgets('sent: the message arrives at +120; each part support adds '
        'opens its space before it arrives, so nothing below jumps; the '
        'reply takes the dots’ place and the balance rolls at +640', (
      tester,
    ) async {
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

      final field = find.descendant(
        of: find.byType(HelpThreadScreen),
        matching: find.byType(IqField),
      );
      IqBalanceHero hero() =>
          tester.widget<IqBalanceHero>(find.byType(IqBalanceHero));
      Iterable<IqChatBubble> support() => tester
          .widgetList<IqChatBubble>(find.byType(IqChatBubble))
          .where((b) => b.from == IqChatBubbleFrom.support);
      var y = tester.getTopLeft(field).dy;
      var step = 0.0;
      int? typed, landed, arrived, typingGone, rolled;
      for (var at = 146; at <= 1600; at += 16) {
        await tester.pump(const Duration(milliseconds: 16));
        final now = tester.getTopLeft(field).dy;
        step = math.max(step, (now - y).abs());
        y = now;
        if (typed == null && find.byType(TypingBubble).evaluate().isNotEmpty) {
          typed = at;
        }
        if (landed == null && support().isNotEmpty) {
          landed = at;
          expect(find.byType(TypingBubble), findsOneWidget);
          expect(hero().amount, '₦15,000');
          expect(hero().earned, '₦65,000.00');
        }
        if (arrived == null && support().any((b) => b.animate)) arrived = at;
        if (landed != null &&
            typingGone == null &&
            find.byType(TypingBubble).evaluate().isEmpty) {
          typingGone = at;
        }
        if (rolled == null &&
            find.byType(IqBalanceHero).evaluate().isNotEmpty &&
            hero().amount == '₦16,500') {
          rolled = at;
        }
      }
      expect(typed, isNotNull);
      expect(step, lessThan(40), reason: 'the Reply field eases down');
      expect(arrived! - landed!, inInclusiveRange(224, 256));
      expect(typingGone, arrived);
      expect(rolled! - landed, inInclusiveRange(624, 672));
      expect(hero().earned, '₦66,500.00');
      expect(find.text('UPDATED BALANCE'), findsOneWidget);
    });

    testWidgets('reduced motion: the new balance at once', (tester) async {
      await _sendFromRequest(tester, reduced: true);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(
        tester.widget<IqBalanceHero>(find.byType(IqBalanceHero)).amount,
        '₦16,500',
      );
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
