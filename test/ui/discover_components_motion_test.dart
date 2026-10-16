import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/bookmark.dart';
import 'package:iqly_mobile/ui/brand_bubble.dart';
import 'package:iqly_mobile/ui/dock.dart';
import 'package:iqly_mobile/ui/highlight.dart';
import 'package:iqly_mobile/ui/icon.dart';
import 'package:iqly_mobile/ui/list_row.dart';
import 'package:iqly_mobile/ui/pressable.dart';
import 'package:iqly_mobile/ui/pull_indicator.dart';
import 'package:iqly_mobile/ui/section_title.dart';
import 'package:iqly_mobile/ui/ticket_card.dart';
import 'package:iqly_mobile/ui/top_bar.dart';
import 'package:iqly_mobile/ui/urgency.dart';
import 'package:iqly_mobile/ui/vector.dart';

import '../features/entry_harness.dart';

const _ms = Duration(milliseconds: 1);

double _eo(double t) => IqCurves.easeOut.transform(t);
double _eio(double t) => IqCurves.easeInOut.transform(t);

void _reduce(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: buildTheme(),
    home: Scaffold(
      body: Align(alignment: Alignment.topLeft, child: child),
    ),
  ),
);

/// The product of every fade and opacity above [finder].
double _opacity(WidgetTester tester, Finder finder) {
  var opacity = 1.0;
  for (final widget in tester.widgetList(
    find.ancestor(
      of: finder,
      matching: find.byWidgetPredicate(
        (w) => w is FadeTransition || w is Opacity,
      ),
    ),
  )) {
    opacity *= widget is FadeTransition
        ? widget.opacity.value
        : (widget as Opacity).opacity;
  }
  return opacity;
}

/// How much of [clipper]'s child shows along its axis, 0 to 1.
double _shown(WidgetTester tester, Finder of, {bool vertical = false}) {
  final clip = tester.widget<ClipRect>(
    find.descendant(of: of, matching: find.byType(ClipRect)).first,
  );
  const size = Size(100, 100);
  final rect = clip.clipper!.getClip(size);
  return (vertical ? rect.height : rect.width) / 100;
}

/// A bookmark the person flips, its state held by the screen.
class _Saver extends StatefulWidget {
  const _Saver({this.on = false});

  final bool on;

  @override
  State<_Saver> createState() => _SaverState();
}

class _SaverState extends State<_Saver> {
  late bool _on = widget.on;

  @override
  void didUpdateWidget(_Saver old) {
    super.didUpdateWidget(old);
    if (old.on != widget.on) _on = widget.on;
  }

  @override
  Widget build(BuildContext context) => IqBookmark(
    state: _on ? IqBookmarkState.on : IqBookmarkState.off,
    onChanged: (state) => setState(() => _on = state == IqBookmarkState.on),
  );
}

void main() {
  group('Bookmark', () {
    Finder marker() => find.byWidgetPredicate(
      (w) => w is FadeTransition && w.child is AnimatedBuilder,
    );

    testWidgets('a save drops the marker in top to bottom, 240 ms', (
      tester,
    ) async {
      final haptics = recordHaptics(tester);
      await _pump(tester, const _Saver());
      expect(tester.widget<FadeTransition>(marker()).opacity.value, 0);
      await tester.tap(find.byType(IqBookmark));
      await tester.pump();
      await tester.pump(_ms * 120);
      expect(_shown(tester, marker(), vertical: true), closeTo(_eo(0.5), 0.01));
      await tester.pumpAndSettle();
      expect(_shown(tester, marker(), vertical: true), 1);
      expect(haptics, ['HapticFeedbackType.lightImpact']);
    });

    testWidgets('unsaving fades the marker out, 150 ms reading ease-in', (
      tester,
    ) async {
      await _pump(tester, const _Saver(on: true));
      await tester.tap(find.byType(IqBookmark));
      await tester.pump();
      await tester.pump(_ms * 75);
      expect(
        tester.widget<FadeTransition>(marker()).opacity.value,
        closeTo(_eo(0.5), 0.01),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<FadeTransition>(marker()).opacity.value, 0);
    });

    testWidgets('a state that arrives from data shows at once', (tester) async {
      await _pump(tester, const _Saver());
      await _pump(tester, const _Saver(on: true));
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.widget<FadeTransition>(marker()).opacity.value, 1);
      expect(_shown(tester, marker(), vertical: true), 1);
    });

    testWidgets('press scales the icon to .9', (tester) async {
      await _pump(tester, const _Saver());
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(IqBookmark)),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        IqScale.bookmarkPress,
      );
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('reduced motion: the fill shows at once, no press scale', (
      tester,
    ) async {
      _reduce(tester);
      await _pump(tester, const _Saver());
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(IqBookmark)),
      );
      await tester.pump();
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
      await gesture.up();
      await tester.pump();
      expect(_shown(tester, marker(), vertical: true), 1);
      expect(tester.widget<FadeTransition>(marker()).opacity.value, 1);
    });
  });

  group('Highlight', () {
    testWidgets('wipes when first scrolled into view, not before', (
      tester,
    ) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await _pump(
        tester,
        SizedBox(
          height: 400,
          child: SingleChildScrollView(
            controller: scroll,
            child: const Column(
              children: [
                SizedBox(height: 1200),
                IqHighlight(),
                SizedBox(height: 400),
              ],
            ),
          ),
        ),
      );
      await tester.pump(_ms * 500);
      expect(_shown(tester, find.byType(IqHighlight)), 0);
      scroll.jumpTo(1000);
      await tester.pump();
      await tester.pump();
      await tester.pump(_ms * 120);
      expect(_shown(tester, find.byType(IqHighlight)), closeTo(_eo(0.5), 0.01));
    });

    testWidgets('wipe: false shows the marker at once', (tester) async {
      await _pump(tester, const IqHighlight(wipe: false));
      expect(_shown(tester, find.byType(IqHighlight)), 1);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('SectionTitle', () {
    testWidgets('the underline wipes in when first seen, 240 ms', (
      tester,
    ) async {
      await _pump(
        tester,
        const SizedBox(width: 358, child: IqSectionTitle(showUnderline: true)),
      );
      await tester.pump();
      await tester.pump(_ms * 120);
      final clip = tester.widget<ClipRect>(
        find
            .descendant(
              of: find.byType(IqSectionTitle),
              matching: find.byWidgetPredicate(
                (w) => w is ClipRect && w.clipper != null,
              ),
            )
            .first,
      );
      expect(
        clip.clipper!.getClip(const Size(100, 4)).width / 100,
        closeTo(_eo(0.5), 0.01),
      );
    });

    testWidgets('the count rolls when it changes', (tester) async {
      await _pump(
        tester,
        const SizedBox(width: 358, child: IqSectionTitle(showCount: true)),
      );
      await tester.pumpAndSettle();
      await _pump(
        tester,
        const SizedBox(
          width: 358,
          child: IqSectionTitle(showCount: true, count: '4'),
        ),
      );
      await tester.pump(_ms * 80);
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('the link dims to .6 while pressed', (tester) async {
      await _pump(
        tester,
        SizedBox(width: 358, child: IqSectionTitle(onSeeAll: () {})),
      );
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('See all')),
      );
      await tester.pumpAndSettle();
      expect(_opacity(tester, find.text('See all')), IqOpacity.pressed);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_opacity(tester, find.text('See all')), 1);
    });
  });

  group('Urgency', () {
    testWidgets('a tone change crossfades the fill once, 400 ms', (
      tester,
    ) async {
      Color fill() =>
          (tester
                      .widget<Container>(
                        find.descendant(
                          of: find.byType(IqUrgency),
                          matching: find.byType(Container),
                        ),
                      )
                      .decoration!
                  as BoxDecoration)
              .color!;
      await _pump(tester, const IqUrgency(tone: IqUrgencyTone.warm));
      expect(fill(), IqColors.accentSoft);
      await _pump(tester, const IqUrgency(tone: IqUrgencyTone.hot));
      await tester.pump(_ms * 200);
      expect(
        fill(),
        Color.lerp(IqColors.accentSoft, IqColors.accent, _eo(0.5)),
      );
      await tester.pump(_ms * 201);
      expect(fill(), IqColors.accent);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('new words roll their changed characters', (tester) async {
      await _pump(tester, const IqUrgency(text: 'Closes in 7h'));
      await _pump(tester, const IqUrgency(text: 'Closes in 6h'));
      await tester.pump(_ms * 80);
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Closes in 6h'), findsOneWidget);
    });
  });

  group('PullIndicator', () {
    double angle(WidgetTester tester) {
      final rotate = tester.widget<Transform>(
        find
            .descendant(
              of: find.byType(IqPullIndicator),
              matching: find.byType(Transform),
            )
            .first,
      );
      final m = rotate.transform;
      return math.atan2(m.entry(1, 0), m.entry(0, 0));
    }

    testWidgets('armed turns the arrow over, 160 ms ease-in-out', (
      tester,
    ) async {
      await _pump(tester, const IqPullIndicator(pullExtent: 64));
      expect(angle(tester), 0);
      await _pump(tester, const IqPullIndicator(pullExtent: 64, armed: true));
      await tester.pump(_ms * 80);
      expect(angle(tester), closeTo(math.pi * _eio(0.5), 0.01));
      await tester.pumpAndSettle();
      expect(angle(tester).abs(), closeTo(math.pi, 0.01));
    });

    testWidgets('states cross over in place, 120 ms', (tester) async {
      await _pump(tester, const IqPullIndicator(pullExtent: 64));
      await _pump(
        tester,
        const IqPullIndicator(state: IqPullIndicatorState.refreshing),
      );
      await tester.pump(_ms * 60);
      expect(find.text('Pull to refresh'), findsOneWidget);
      expect(find.text('Refreshing'), findsOneWidget);
      expect(
        _opacity(tester, find.text('Refreshing')),
        closeTo(_eo(0.5), 0.01),
      );
      await tester.pump(_ms * 61);
      await tester.pump();
      expect(find.text('Pull to refresh'), findsNothing);
    });

    testWidgets('Done draws its check, 160 ms', (tester) async {
      await _pump(
        tester,
        const IqPullIndicator(state: IqPullIndicatorState.refreshing),
      );
      await _pump(
        tester,
        const IqPullIndicator(state: IqPullIndicatorState.done),
      );
      await tester.pump(_ms * 80);
      expect(_shown(tester, find.byType(Wipe)), closeTo(_eo(0.5), 0.01));
      await tester.pumpAndSettle();
    });

    testWidgets('reduced motion: no turn, a cut between states', (
      tester,
    ) async {
      _reduce(tester);
      await _pump(tester, const IqPullIndicator(pullExtent: 64));
      await _pump(tester, const IqPullIndicator(pullExtent: 64, armed: true));
      await tester.pump(_ms * 80);
      expect(angle(tester), 0);
      await _pump(
        tester,
        const IqPullIndicator(state: IqPullIndicatorState.refreshing),
      );
      await tester.pump();
      expect(find.text('Pull to refresh'), findsNothing);
    });
  });

  group('BrandBubble', () {
    Color ring(WidgetTester tester) => tester
        .widget<IqVector>(
          find.byWidgetPredicate(
            (w) => w is IqVector && w.asset.contains('brand-bubble-loop'),
          ),
        )
        .color;

    testWidgets('Done pops the count out and the check in from +120', (
      tester,
    ) async {
      await _pump(tester, const IqBrandBubble());
      await _pump(tester, const IqBrandBubble(state: IqBrandBubbleState.done));
      await tester.pump(_ms * 100);
      expect(
        ring(tester),
        Color.lerp(IqColors.accent, IqColors.line2, _eo(0.5)),
      );
      expect(_opacity(tester, find.text('2')), lessThan(1));
      final check = find.byWidgetPredicate(
        (w) => w is IqIcon && w.icon == IqIcons.check,
      );
      expect(check, findsNothing);
      await tester.pump(_ms * 140);
      expect(_opacity(tester, check), greaterThan(0));
      await tester.pumpAndSettle();
      expect(find.text('2'), findsNothing);
      expect(_opacity(tester, check), 1);
      expect(ring(tester), IqColors.line2);
    });

    testWidgets('press scales the bubble to .96', (tester) async {
      await _pump(tester, IqBrandBubble(onTap: () {}));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(IqBrandBubble)),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        IqScale.soft,
      );
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('Dock', () {
    double pillLeft(WidgetTester tester) => tester
        .getTopLeft(
          find.descendant(
            of: find.byType(IqDock),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Container &&
                  w.decoration is BoxDecoration &&
                  (w.decoration! as BoxDecoration).color == IqColors.tint,
            ),
          ),
        )
        .dx;

    testWidgets('a switch is instant: the pill jumps (doc rev 57)', (
      tester,
    ) async {
      await _pump(tester, const IqDock());
      final start = pillLeft(tester);
      await _pump(tester, const IqDock(active: IqDockActive.wallet));
      await tester.pump();
      expect(pillLeft(tester), greaterThan(start));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('a tab change ticks once', (tester) async {
      final haptics = recordHaptics(tester);
      var active = IqDockActive.discover;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: Center(
                child: IqDock(
                  active: active,
                  onChanged: (tab) => setState(() => active = tab),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Wallet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wallet'));
      await tester.pumpAndSettle();
      expect(haptics, ['HapticFeedbackType.lightImpact']);
    });
  });

  group('TopBar', () {
    testWidgets('a new greeting crossfades in, 150 ms', (tester) async {
      await _pump(tester, const IqTopBar(greeting: ' ', showGreeting: true));
      await _pump(
        tester,
        const IqTopBar(greeting: '5 sent', showGreeting: true),
      );
      await tester.pump(_ms * 75);
      expect(_opacity(tester, find.text('5 sent')), closeTo(_eo(0.5), 0.01));
      await tester.pumpAndSettle();
      expect(_opacity(tester, find.text('5 sent')), 1);
    });

    testWidgets('the unread count pops in no sooner than 200 ms in', (
      tester,
    ) async {
      await _pump(tester, const IqTopBar(showCount: false));
      await tester.pump(_ms * 50);
      await _pump(tester, const IqTopBar(count: '3'));
      await tester.pump(_ms * 140);
      expect(_opacity(tester, find.text('3')), 0);
      await tester.pump(_ms * 120);
      expect(_opacity(tester, find.text('3')), greaterThan(0));
      await tester.pumpAndSettle();
      expect(_opacity(tester, find.text('3')), 1);

      await _pump(tester, const IqTopBar(count: '3', showCount: false));
      await tester.pump(_ms * 75);
      expect(_opacity(tester, find.text('3')), lessThan(1));
      await tester.pumpAndSettle();
      expect(find.text('3'), findsNothing);
    });

    testWidgets('round buttons fill panel while pressed', (tester) async {
      await _pump(
        tester,
        IqTopBar(variant: IqTopBarVariant.page, onBack: () {}),
      );
      Color fill() =>
          (tester
                      .widget<AnimatedContainer>(
                        find.byType(AnimatedContainer).first,
                      )
                      .decoration!
                  as BoxDecoration)
              .color!;
      expect(fill(), IqColors.card);
      final gesture = await tester.startGesture(
        tester.getCenter(find.bySemanticsLabel('Back')),
      );
      await tester.pumpAndSettle();
      expect(fill(), IqColors.panel);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(fill(), IqColors.card);
    });
  });

  group('cards and rows', () {
    testWidgets('a ticket presses to .98, back in 160', (tester) async {
      await _pump(tester, IqTicketCard(onTap: () {}));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(IqTicketCard)),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        IqScale.cardPress,
      );
      await gesture.up();
      await tester.pump(_ms * 100);
      await tester.pump(_ms * 80);
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    });

    testWidgets('reduced motion: a ticket press does not scale', (
      tester,
    ) async {
      _reduce(tester);
      await _pump(tester, IqTicketCard(onTap: () {}));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(IqTicketCard)),
      );
      await tester.pump();
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a list row fills panel while pressed', (tester) async {
      await _pump(tester, IqListRow(onTap: () {}));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(IqListRow)),
      );
      Color fill() =>
          (tester
                      .widget<AnimatedContainer>(
                        find.descendant(
                          of: find.byType(IqPressable),
                          matching: find.byType(AnimatedContainer),
                        ),
                      )
                      .decoration!
                  as BoxDecoration)
              .color!;
      await tester.pumpAndSettle();
      expect(fill(), IqColors.panel);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(fill(), IqColors.card);
    });
  });
}
