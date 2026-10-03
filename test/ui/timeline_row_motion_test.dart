import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/timeline_row.dart';

const _ms = Duration(milliseconds: 1);

double _eo(double t) => IqCurves.easeOut.transform(t);

Widget _row(
  IqTimelineRowState state, {
  String title = 'Awaiting approval',
  bool failed = false,
  bool reduced = false,
  bool ticking = true,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: TickerMode(
      enabled: ticking,
      child: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 358,
            child: IqTimelineRow(state: state, title: title, failed: failed),
          ),
        ),
      ),
    ),
  ),
);

Finder get _ring => find.byWidgetPredicate(
  (w) => w is FadeTransition && w.child is ScaleTransition,
);

double _ringShown(WidgetTester tester) =>
    tester.widget<FadeTransition>(_ring).opacity.value;

double _ringScale(WidgetTester tester) => tester
    .widget<ScaleTransition>(
      find.descendant(of: _ring, matching: find.byType(ScaleTransition)),
    )
    .scale
    .value;

Color _dot(WidgetTester tester) =>
    (tester
                .widget<DecoratedBox>(
                  find
                      .descendant(
                        of: find.byType(AnimatedContainer),
                        matching: find.byType(DecoratedBox),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration)
        .color!;

/// How much of the line the thread's painter draws.
double _thread(WidgetTester tester) =>
    (tester
                    .widget<CustomPaint>(
                      find.descendant(
                        of: find.byType(IqTimelineRow),
                        matching: find.byType(CustomPaint),
                      ),
                    )
                    .painter
                as dynamic)
            .reveal
        as double;

void main() {
  testWidgets('the Current ring breathes 1 to 1.3 and back over 1600', (
    tester,
  ) async {
    await tester.pumpWidget(_row(IqTimelineRowState.current));
    await tester.pump();
    expect(_ringShown(tester), 1);
    expect(_ringScale(tester), 1);
    await tester.pump(_ms * 400);
    expect(_ringScale(tester), closeTo(1.15, 0.01));
    await tester.pump(_ms * 400);
    expect(_ringScale(tester), closeTo(1.3, 0.01));
    await tester.pump(_ms * 800);
    expect(_ringScale(tester), closeTo(1, 0.01));
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('the ring holds still under reduced motion, with tickers off '
      'and on a failed row', (tester) async {
    for (final row in [
      _row(IqTimelineRowState.current, reduced: true),
      _row(IqTimelineRowState.current, ticking: false),
      _row(IqTimelineRowState.current, failed: true),
    ]) {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(row);
      await tester.pump();
      await tester.pump(_ms * 400);
      expect(_ringScale(tester), 1);
      expect(tester.hasRunningAnimations, isFalse);
    }
  });

  testWidgets('becoming Current fades the ring in over 180', (tester) async {
    await tester.pumpWidget(_row(IqTimelineRowState.upcoming));
    expect(_ringShown(tester), 0);
    await tester.pumpWidget(_row(IqTimelineRowState.current));
    await tester.pump(_ms * 90);
    expect(_ringShown(tester), closeTo(_eo(0.5), 0.01));
    await tester.pump(_ms * 91);
    expect(_ringShown(tester), 1);
  });

  testWidgets('becoming Done: the dot inks in 180 as the ring and the words '
      'cross, then the thread draws down in 240', (tester) async {
    await tester.pumpWidget(_row(IqTimelineRowState.current));
    await tester.pump(_ms * 100);
    await tester.pumpWidget(
      _row(IqTimelineRowState.done, title: 'Approved by iQLY'),
    );
    await tester.pump(_ms * 90);
    expect(
      _dot(tester),
      isSameColorAs(Color.lerp(IqColors.accent, IqColors.brand, _eo(0.5))!),
    );
    expect(_ringShown(tester), closeTo(_eo(0.5), 0.01));
    expect(find.text('Awaiting approval'), findsOneWidget);
    expect(find.text('Approved by iQLY'), findsOneWidget);
    expect(_thread(tester), 0);

    await tester.pump(_ms * 90);
    expect(_dot(tester), isSameColorAs(IqColors.brand));
    expect(_thread(tester), closeTo(0, 0.01));
    await tester.pump(_ms * 120);
    expect(_thread(tester), closeTo(_eo(0.5), 0.01));
    await tester.pump(_ms * 121);
    expect(_thread(tester), 1);
    expect(find.text('Awaiting approval'), findsNothing);
    expect(_ringShown(tester), 0);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('reduced motion: Done at once', (tester) async {
    await tester.pumpWidget(_row(IqTimelineRowState.current, reduced: true));
    await tester.pumpWidget(
      _row(IqTimelineRowState.done, title: 'Approved by iQLY', reduced: true),
    );
    await tester.pump();
    expect(_dot(tester), isSameColorAs(IqColors.brand));
    expect(_ringShown(tester), 0);
    expect(_thread(tester), 1);
    expect(find.text('Awaiting approval'), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
