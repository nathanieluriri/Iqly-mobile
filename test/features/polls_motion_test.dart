import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/features/polls/poll_sheet.dart';
import 'package:iqly_mobile/features/polls/polls_screen.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/brand_bubble.dart';
import 'package:iqly_mobile/ui/icon.dart';
import 'package:iqly_mobile/ui/poll_card.dart';
import 'package:iqly_mobile/ui/poll_option.dart';
import 'package:iqly_mobile/ui/pressable.dart';

import '../golden/screens/app_harness.dart';
import '../golden/screens/polls_notifications_help_harness.dart';

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

Widget _card(IqPollCardState state, {int? selected}) => _app(
  SizedBox(
    width: 358,
    child: IqPollCard(
      state: state,
      selected: selected,
      hint: 'Pick one',
      onVote: (_) {},
    ),
  ),
);

IqPollOption _option(WidgetTester tester, String label) =>
    tester.widget<IqPollOption>(
      find.byWidgetPredicate((w) => w is IqPollOption && w.label == label),
    );

Widget _bubble(IqBrandBubbleState state, String count, {bool ticking = true}) =>
    _app(
      IqBrandBubble(name: 'Orchid Foods', count: count, state: state),
      ticking: ticking,
    );

Finder get _check =>
    find.byWidgetPredicate((w) => w is IqIcon && w.icon == IqIcons.check);

double _opacityAbove(WidgetTester tester, Finder child) => tester
    .widgetList<Opacity>(
      find.ancestor(of: child, matching: find.byType(Opacity)),
    )
    .fold(1, (o, w) => o * w.opacity);

void main() {
  group('Exp/PollCard reveal', () {
    testWidgets('the bars fill from nothing over 600 ms as shares count', (
      tester,
    ) async {
      await tester.pumpWidget(_card(IqPollCardState.open, selected: 0));
      await tester.pumpAndSettle();
      expect(find.text('Pick one'), findsOneWidget);

      await tester.pumpWidget(_card(IqPollCardState.voted));
      expect(_option(tester, 'Zobo and ginger').share, 0);
      expect(find.text('0%'), findsNWidgets(3));
      expect(find.text('You voted · 214 votes'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 300));
      final mid = _option(tester, 'Zobo and ginger').share;
      expect(mid, greaterThan(0.45 * IqCurves.easeOut.transform(0.4)));
      expect(mid, lessThan(0.45));

      await tester.pump(const Duration(milliseconds: 300));
      expect(_option(tester, 'Zobo and ginger').share, 0.45);
      expect(find.text('45%'), findsOneWidget);
      expect(find.text('33%'), findsOneWidget);
      expect(find.text('22%'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('the vote line appears, fading and rising 8 over 220', (
      tester,
    ) async {
      await tester.pumpWidget(_card(IqPollCardState.open, selected: 0));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_card(IqPollCardState.voted));
      final line = find.text('You voted · 214 votes');
      final appear = find.ancestor(of: line, matching: find.byType(Appear));
      expect(appear, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 110));
      final fade = tester.widget<FadeTransition>(
        find.ancestor(of: line, matching: find.byType(FadeTransition)).first,
      );
      expect(fade.opacity.value, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(fade.opacity.value, 1);
    });

    testWidgets('a card that opens voted shows its results still', (
      tester,
    ) async {
      await tester.pumpWidget(_card(IqPollCardState.voted));
      expect(_option(tester, 'Zobo and ginger').share, 0.45);
      expect(
        find.ancestor(
          of: find.text('You voted · 214 votes'),
          matching: find.byType(Appear),
        ),
        findsNothing,
      );
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('reduced motion: the Voted card at once', (tester) async {
      _reduce(tester);
      await tester.pumpWidget(_card(IqPollCardState.open, selected: 0));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_card(IqPollCardState.voted));
      await tester.pump();
      expect(_option(tester, 'Zobo and ginger').share, 0.45);
      expect(find.text('45%'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('Exp/PollOption', () {
    Widget option(IqPollOptionState state) =>
        _app(IqPollOption(state: state, width: 324, onTap: () {}));

    testWidgets('a pick fills ink over 120 ms as the check pops and the label '
        'eases right', (tester) async {
      await tester.pumpWidget(option(IqPollOptionState.standard));
      expect(_check, findsNothing);
      await tester.pumpWidget(option(IqPollOptionState.selected));
      final face = find.byKey(const ValueKey(IqPollOptionState.selected));
      FadeTransition fade() => tester.widget<FadeTransition>(
        find.ancestor(of: face, matching: find.byType(FadeTransition)).first,
      );
      expect(fade().opacity.value, 0);
      await tester.pump(const Duration(milliseconds: 60));
      expect(fade().opacity.value, inExclusiveRange(0, 1));
      final pop = tester.widget<Transform>(
        find.ancestor(of: _check, matching: find.byType(Transform)).first,
      );
      expect(pop.transform.entry(0, 0), inExclusiveRange(0.6, 1));
      final label = find.text('Zobo and ginger');
      expect(label, findsOneWidget);
      final inset =
          tester.getTopLeft(label).dx -
          tester.getTopLeft(find.byType(IqPollOption)).dx;
      expect(inset, inExclusiveRange(18, 46));
      await tester.pump(const Duration(milliseconds: 60));
      expect(fade().opacity.value, 1);
      expect(
        tester.getTopLeft(label).dx -
            tester.getTopLeft(find.byType(IqPollOption)).dx,
        46,
      );
      await tester.pumpAndSettle();
    });

    testWidgets('the result look takes the 300 ms of the reveal', (
      tester,
    ) async {
      await tester.pumpWidget(option(IqPollOptionState.selected));
      await tester.pumpAndSettle();
      await tester.pumpWidget(option(IqPollOptionState.chosen));
      final face = find.byKey(const ValueKey(IqPollOptionState.chosen));
      await tester.pump(const Duration(milliseconds: 150));
      final fade = tester.widget<FadeTransition>(
        find.ancestor(of: face, matching: find.byType(FadeTransition)).first,
      );
      expect(fade.opacity.value, inExclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 150));
      expect(fade.opacity.value, 1);
      await tester.pumpAndSettle();
    });

    testWidgets('reduced motion: a cut', (tester) async {
      _reduce(tester);
      await tester.pumpWidget(option(IqPollOptionState.standard));
      await tester.pumpWidget(option(IqPollOptionState.selected));
      await tester.pump();
      expect(
        find.byKey(const ValueKey(IqPollOptionState.standard)),
        findsNothing,
      );
    });
  });

  group('Exp/BrandBubble', () {
    testWidgets('turning Done: the count pops out, the check in from +120', (
      tester,
    ) async {
      await tester.pumpWidget(_bubble(IqBrandBubbleState.newPolls, '1'));
      expect(find.text('1'), findsOneWidget);
      expect(_check, findsNothing);

      await tester.pumpWidget(_bubble(IqBrandBubbleState.done, '0'));
      await tester.pump(const Duration(milliseconds: 75));
      expect(_opacityAbove(tester, find.text('1')), inExclusiveRange(0, 1));
      expect(_check, findsNothing);

      await tester.pump(const Duration(milliseconds: 125));
      expect(find.text('1'), findsNothing);
      expect(_opacityAbove(tester, _check), inExclusiveRange(0, 1));

      await tester.pumpAndSettle();
      expect(_opacityAbove(tester, _check), 1);
    });

    testWidgets('a change while hidden waits for the bubble to show again', (
      tester,
    ) async {
      await tester.pumpWidget(_bubble(IqBrandBubbleState.newPolls, '2'));
      await tester.pumpWidget(
        _bubble(IqBrandBubbleState.newPolls, '2', ticking: false),
      );
      await tester.pumpWidget(
        _bubble(IqBrandBubbleState.done, '0', ticking: false),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(_opacityAbove(tester, find.text('2')), 1);
      expect(_check, findsNothing);

      await tester.pumpWidget(_bubble(IqBrandBubbleState.done, '0'));
      await tester.pump(const Duration(milliseconds: 75));
      expect(_opacityAbove(tester, find.text('2')), inExclusiveRange(0, 1));
      expect(_check, findsNothing);
      await tester.pump(const Duration(milliseconds: 125));
      expect(_opacityAbove(tester, _check), inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(find.text('2'), findsNothing);
      expect(_opacityAbove(tester, _check), 1);
    });

    testWidgets('a turn that lands as Discover comes back waits for the Polls '
        'page to leave, then plays once (spec 5.28, 7.3)', (tester) async {
      await pumpApp(
        tester,
        Routes.home,
        overrides: laneOverrides(),
        reducedMotion: false,
      );
      Finder labelled(String label) => find.byWidgetPredicate(
        (w) => w is IqPressable && w.semanticLabel == label,
      );
      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await tap(find.text('Orchid Foods'));
      expect(find.byType(PollSheet), findsOneWidget);
      await tap(find.text('Zobo and ginger'));
      await tap(find.text('1 litre bottle'));
      await tap(labelled('Close'));
      expect(find.byType(PollSheet), findsNothing);

      final bubble = find.byWidgetPredicate(
        (w) => w is IqBrandBubble && w.name == 'Orchid Foods',
      );
      Finder inBubble(Finder finder) =>
          find.descendant(of: bubble, matching: finder, skipOffstage: false);
      await tester.tap(labelled('Back'));
      var frames = 0;
      while (find.byType(PollsScreen).evaluate().isNotEmpty) {
        await tester.pump(const Duration(milliseconds: 16));
        frames++;
        expect(frames, lessThan(30));
        if (find.byType(PollsScreen).evaluate().isEmpty) break;
        expect(_opacityAbove(tester, inBubble(find.text('2'))), 1);
        expect(inBubble(_check), findsNothing);
      }
      expect(
        tester.widget<IqBrandBubble>(bubble).state,
        IqBrandBubbleState.done,
      );
      await tester.pump(const Duration(milliseconds: 64));
      expect(_opacityAbove(tester, inBubble(find.text('2'))), lessThan(1));
      expect(inBubble(_check), findsNothing);
      await tester.pump(const Duration(milliseconds: 112));
      expect(_opacityAbove(tester, inBubble(_check)), inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(inBubble(find.text('2')), findsNothing);
      expect(_opacityAbove(tester, inBubble(_check)), 1);
    });

    testWidgets('a new count rolls', (tester) async {
      await tester.pumpWidget(_bubble(IqBrandBubbleState.newPolls, '2'));
      await tester.pumpWidget(_bubble(IqBrandBubbleState.newPolls, '1'));
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsWidgets);
      await tester.pumpAndSettle();
      expect(find.text('2'), findsNothing);
    });

    testWidgets('reduced motion: the Done look at once', (tester) async {
      _reduce(tester);
      await tester.pumpWidget(_bubble(IqBrandBubbleState.newPolls, '1'));
      await tester.pumpWidget(_bubble(IqBrandBubbleState.done, '0'));
      await tester.pump();
      expect(find.text('1'), findsNothing);
      expect(_opacityAbove(tester, _check), 1);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
