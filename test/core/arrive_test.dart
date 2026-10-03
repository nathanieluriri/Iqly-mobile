import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/motion.dart';

const _ms = Duration(milliseconds: 1);
const _box = SizedBox(key: ValueKey('box'), width: 100, height: 20);

double _eo(double t) => IqCurves.easeOut.transform(t);

Widget _app(Widget child, {bool reduced = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduced),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Align(alignment: Alignment.topLeft, child: child),
  ),
);

double _rise(WidgetTester tester) =>
    tester.getTopLeft(find.byKey(const ValueKey('box'))).dy;

double _opacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('box')),
            matching: find.byType(FadeTransition),
          )
          .first,
    )
    .opacity
    .value;

void main() {
  testWidgets('arrive: fades in as it rises 12 over 260 ease-out', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const Arrive(child: _box)));
    expect(_opacity(tester), 0);
    expect(_rise(tester), closeTo(12, 0.01));
    await tester.pump(_ms * 130);
    expect(_opacity(tester), closeTo(_eo(0.5), 0.01));
    expect(_rise(tester), closeTo(12 * (1 - _eo(0.5)), 0.01));
    await tester.pump(_ms * 131);
    expect(_opacity(tester), 1);
    expect(_rise(tester), 0);
  });

  testWidgets('an illustration rises 16 over 320, after its delay', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const Arrive(
          distance: IqTravel.riseHero,
          duration: IqDurations.morph,
          delay: IqDurations.stagger,
          child: _box,
        ),
      ),
    );
    await tester.pump(_ms * 39);
    expect(_opacity(tester), 0);
    expect(_rise(tester), closeTo(16, 0.01));
    await tester.pump(_ms);
    await tester.pump(_ms * 160);
    expect(_rise(tester), closeTo(16 * (1 - _eo(0.5)), 0.01));
    await tester.pump(_ms * 161);
    expect(_rise(tester), 0);
  });

  testWidgets('whenSeen waits until it is on screen', (tester) async {
    Widget tab(bool shown) => _app(
      TickerMode(
        enabled: shown,
        child: const Arrive(whenSeen: true, child: _box),
      ),
    );
    await tester.pumpWidget(tab(false));
    await tester.pump(_ms * 500);
    expect(_opacity(tester), 0);
    await tester.pumpWidget(tab(true));
    await tester.pump();
    await tester.pump(_ms * 130);
    expect(_opacity(tester), inExclusiveRange(0, 1));
    await tester.pump(_ms * 140);
    expect(_opacity(tester), 1);
  });

  testWidgets('reduced motion: fades only, 150', (tester) async {
    await tester.pumpWidget(_app(const Arrive(child: _box), reduced: true));
    expect(_rise(tester), 0);
    await tester.pump(_ms * 75);
    expect(_opacity(tester), closeTo(_eo(0.5), 0.01));
    expect(_rise(tester), 0);
    await tester.pump(_ms * 76);
    expect(_opacity(tester), 1);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
