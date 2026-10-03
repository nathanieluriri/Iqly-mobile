import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/ui/highlight.dart';
import 'package:iqly_mobile/ui/skeleton.dart';

const _ms = Duration(milliseconds: 1);

double _eo(double t) => IqCurves.easeOut.transform(t);
double _ei(double t) => IqCurves.easeIn.transform(t);

void _reduce(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

/// The product of every fade above [finder].
double _opacity(WidgetTester tester, Finder finder) => tester
    .widgetList<FadeTransition>(
      find.ancestor(of: finder, matching: find.byType(FadeTransition)),
    )
    .fold(1.0, (o, w) => o * w.opacity.value);

void main() {
  group('LoadingGate', () {
    const skeleton = Text('skeleton');
    const content = Text('content');
    final opened = <Duration>[];

    Future<void> gate(WidgetTester tester, {required bool loading}) =>
        tester.pumpWidget(
          MaterialApp(
            home: LoadingGate(
              loading: loading,
              skeleton: skeleton,
              onOpen: opened.add,
              child: content,
            ),
          ),
        );

    setUp(opened.clear);

    testWidgets('paper until 300, the skeleton until at least 900', (
      tester,
    ) async {
      await gate(tester, loading: true);
      expect(find.text('skeleton'), findsNothing);
      expect(find.text('content'), findsNothing);
      await tester.pump(_ms * 299);
      expect(find.text('skeleton'), findsNothing);
      await tester.pump(_ms);
      await tester.pump();
      expect(find.text('skeleton'), findsOneWidget);

      // The data lands at 400, but the skeleton holds for its 600.
      await tester.pump(_ms * 100);
      await gate(tester, loading: false);
      await tester.pump(_ms * 499);
      expect(find.text('content'), findsNothing);
      expect(find.text('skeleton'), findsOneWidget);
      expect(opened, isEmpty);

      // The hand-over: the skeleton fades from 900 and the content comes
      // in at +60.
      await tester.pump(_ms);
      await tester.pump();
      expect(find.text('content'), findsNothing);
      await tester.pump(_ms * 59);
      expect(find.text('content'), findsNothing);
      await tester.pump(_ms);
      await tester.pump();
      expect(find.text('content'), findsOneWidget);
      expect(opened, [Duration.zero]);
      await tester.pump(_ms * 15);
      expect(
        _opacity(tester, find.text('skeleton')),
        closeTo(1 - _ei(0.5), 0.01),
      );
      await tester.pump(_ms * 80);
      expect(find.text('skeleton'), findsNothing);
      expect(find.text('content'), findsOneWidget);
    });

    testWidgets('the builder sees the hand-over at once and waits 60', (
      tester,
    ) async {
      final phases = <GatePhase>[];
      Future<void> build({required bool loading}) => tester.pumpWidget(
        MaterialApp(
          home: LoadingGate.builder(
            loading: loading,
            onOpen: opened.add,
            builder: (context, phase, _) {
              phases.add(phase);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await build(loading: true);
      await tester.pump(_ms * 400);
      await build(loading: false);
      await tester.pump(_ms * 500);
      await tester.pump();
      expect(phases.last, GatePhase.handover);
      expect(opened, [IqDurations.lag]);
      await tester.pump(_ms * 151);
      await tester.pump();
      expect(phases.last, GatePhase.content);
    });

    testWidgets('skeletonNow shows the skeleton without the wait', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoadingGate(
            loading: true,
            skeletonNow: true,
            skeleton: skeleton,
            child: content,
          ),
        ),
      );
      expect(find.text('skeleton'), findsOneWidget);
      expect(find.text('content'), findsNothing);
    });

    testWidgets('data inside 300 goes straight to the content', (tester) async {
      await gate(tester, loading: true);
      await tester.pump(_ms * 200);
      await gate(tester, loading: false);
      expect(find.text('content'), findsOneWidget);
      expect(find.text('skeleton'), findsNothing);
      expect(opened, [Duration.zero]);
      await tester.pump(_ms * 400);
      expect(find.text('skeleton'), findsNothing);
    });

    testWidgets('loading again starts over from paper', (tester) async {
      await gate(tester, loading: false);
      expect(find.text('content'), findsOneWidget);
      await gate(tester, loading: true);
      expect(find.text('content'), findsNothing);
      await tester.pump(_ms * 300);
      await tester.pump();
      expect(find.text('skeleton'), findsOneWidget);
    });

    testWidgets('reduced motion: the same waits, a 150 ms crossfade', (
      tester,
    ) async {
      _reduce(tester);
      await gate(tester, loading: true);
      await tester.pump(_ms * 299);
      expect(find.text('skeleton'), findsNothing);
      await tester.pump(_ms);
      await tester.pump();
      expect(find.text('skeleton'), findsOneWidget);
      await gate(tester, loading: false);
      await tester.pump(_ms * 599);
      expect(find.text('content'), findsNothing);
      await tester.pump(_ms);
      await tester.pump();
      expect(opened, [Duration.zero]);
      await tester.pump(_ms * 151);
      await tester.pump();
      expect(find.text('skeleton'), findsNothing);
    });
  });

  group('skeleton beat', () {
    double bar(WidgetTester tester, int index) => tester
        .widget<FadeTransition>(
          find
              .descendant(
                of: find.byType(IqSkeleton).at(index),
                matching: find.byType(FadeTransition),
              )
              .first,
        )
        .opacity
        .value;

    testWidgets('every skeleton on a screen pulses in phase, late ones too', (
      tester,
    ) async {
      Widget screen(int count) => MaterialApp(
        home: PulseScope(
          child: Column(
            children: [
              for (var i = 0; i < count; i++)
                const IqSkeleton(kind: IqSkeletonKind.line, width: 100),
            ],
          ),
        ),
      );
      await tester.pumpWidget(screen(1));
      await tester.pump(_ms * 300);
      await tester.pumpWidget(screen(2));
      await tester.pump(_ms * 100);
      expect(bar(tester, 0), bar(tester, 1));
      expect(bar(tester, 0), isNot(0.5));

      await tester.pumpWidget(screen(0));
      await tester.pump(_ms * 100);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('reduced motion: bars stand at full', (tester) async {
      _reduce(tester);
      await tester.pumpWidget(
        const MaterialApp(home: PulseScope(child: IqSkeleton())),
      );
      expect(bar(tester, 0), 1);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('Arrivals', () {
    double rise(WidgetTester tester, int i) =>
        tester.getTopLeft(find.byKey(ValueKey(i))).dy - i * 10;

    double fade(WidgetTester tester, int i) =>
        _opacity(tester, find.byKey(ValueKey(i)));

    Widget list(ArrivalsController controller, {int count = 8}) => MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: Arrivals(
          controller: controller,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < count; i++)
                ArriveItem(
                  child: SizedBox(key: ValueKey(i), width: 100, height: 10),
                ),
            ],
          ),
        ),
      ),
    );

    testWidgets('a wave arrives 40 ms apart; the seventh stands still', (
      tester,
    ) async {
      final arrivals = ArrivalsController()..play();
      await tester.pumpWidget(list(arrivals));
      expect(rise(tester, 0), closeTo(12, 0.01));
      expect(fade(tester, 0), 0);
      expect(rise(tester, 6), 0);
      expect(fade(tester, 6), 1);
      await tester.pump(_ms * 170);
      expect(fade(tester, 0), closeTo(_eo(170 / 260), 0.01));
      expect(fade(tester, 2), closeTo(_eo(90 / 260), 0.01));
      expect(rise(tester, 5), closeTo(12, 0.01));
      await tester.pumpAndSettle();
      for (var i = 0; i < 8; i++) {
        expect(rise(tester, i), 0);
        expect(fade(tester, i), 1);
      }
    });

    testWidgets('after: the wave waits behind a fading skeleton', (
      tester,
    ) async {
      final arrivals = ArrivalsController()..play(after: IqDurations.lag);
      await tester.pumpWidget(list(arrivals, count: 2));
      await tester.pump(_ms * 60);
      expect(fade(tester, 0), 0);
      await tester.pump(_ms * 130);
      expect(fade(tester, 0), closeTo(_eo(130 / 260), 0.01));
    });

    testWidgets('items built with no wave open stand in place', (tester) async {
      final arrivals = ArrivalsController();
      await tester.pumpWidget(list(arrivals));
      expect(rise(tester, 0), 0);
      expect(fade(tester, 0), 1);
      expect(tester.hasRunningAnimations, isFalse);

      // A wave opened later only takes items built while it is open.
      arrivals.play();
      await tester.pumpWidget(list(arrivals, count: 9));
      expect(fade(tester, 0), 1);
      expect(fade(tester, 8), 0);
    });

    testWidgets('a Highlight in an arriving row wipes 120 ms after it', (
      tester,
    ) async {
      final arrivals = ArrivalsController()..play();
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: Arrivals(
              controller: arrivals,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ArriveItem(child: SizedBox(height: 10)),
                  ArriveItem(child: IqHighlight()),
                ],
              ),
            ),
          ),
        ),
      );
      double reveal() =>
          tester
              .widget<ClipRect>(
                find
                    .descendant(
                      of: find.byType(IqHighlight),
                      matching: find.byType(ClipRect),
                    )
                    .first,
              )
              .clipper!
              .getClip(const Size(100, 10))
              .width /
          100;
      // The second row starts at 40; its marker at 40 + 120.
      await tester.pump(_ms * 159);
      expect(reveal(), 0);
      await tester.pump(_ms * 121);
      expect(reveal(), closeTo(_eo(120 / 240), 0.01));
      await tester.pumpAndSettle();
      expect(reveal(), 1);
    });

    testWidgets('an item kept alive in a list never arrives twice', (
      tester,
    ) async {
      final arrivals = ArrivalsController()..play();
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Arrivals(
            controller: arrivals,
            child: ListView(
              controller: scroll,
              children: [
                for (var i = 0; i < 40; i++)
                  ArriveItem(child: SizedBox(key: ValueKey(i), height: 100)),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      scroll.jumpTo(3000);
      await tester.pump();
      scroll.jumpTo(0);
      await tester.pump();
      expect(fade(tester, 0), 1);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('reduced motion: a wave fades in together, 150 ms', (
      tester,
    ) async {
      _reduce(tester);
      final arrivals = ArrivalsController()..play(after: IqDurations.lag);
      await tester.pumpWidget(list(arrivals));
      await tester.pump(_ms * 75);
      expect(fade(tester, 0), closeTo(_eo(0.5), 0.01));
      expect(fade(tester, 5), closeTo(_eo(0.5), 0.01));
      expect(rise(tester, 5), 0);
      await tester.pump(_ms * 75);
      expect(fade(tester, 5), 1);
    });
  });

  group('Arrive.illustration', () {
    testWidgets('fades in as it rises 16 over 320 ms', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: Arrive.illustration(
              child: SizedBox(key: ValueKey('box'), height: 10),
            ),
          ),
        ),
      );
      double dy() => tester.getTopLeft(find.byKey(const ValueKey('box'))).dy;
      expect(dy(), closeTo(16, 0.01));
      await tester.pump(_ms * 160);
      expect(dy(), closeTo(16 * (1 - _eo(0.5)), 0.01));
      expect(
        _opacity(tester, find.byKey(const ValueKey('box'))),
        closeTo(_eo(0.5), 0.01),
      );
      await tester.pump(_ms * 160);
      expect(dy(), 0);
    });

    testWidgets('reduced motion: fades in place, 150', (tester) async {
      _reduce(tester);
      await tester.pumpWidget(
        const MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: Arrive.illustration(
              child: SizedBox(key: ValueKey('box'), height: 10),
            ),
          ),
        ),
      );
      await tester.pump(_ms * 75);
      expect(tester.getTopLeft(find.byKey(const ValueKey('box'))).dy, 0);
      await tester.pump(_ms * 75);
      expect(_opacity(tester, find.byKey(const ValueKey('box'))), 1);
    });
  });
}
