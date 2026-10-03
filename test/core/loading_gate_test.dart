import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/motion.dart';

const _ms = Duration(milliseconds: 1);

double _ei(double t) => IqCurves.easeIn.transform(t);

Widget _gate({
  required bool loading,
  bool skeletonNow = false,
  bool reduced = false,
}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduced),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: LoadingGate(
      loading: loading,
      skeletonNow: skeletonNow,
      skeleton: const Text('skeleton'),
      child: const Text('content'),
    ),
  ),
);

double _skeletonOpacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find
          .ancestor(
            of: find.text('skeleton'),
            matching: find.byType(FadeTransition),
          )
          .first,
    )
    .opacity
    .value;

void main() {
  testWidgets('nothing for 300 ms, then the skeleton', (tester) async {
    await tester.pumpWidget(_gate(loading: true));
    expect(find.text('skeleton'), findsNothing);
    expect(find.text('content'), findsNothing);
    await tester.pump(_ms * 299);
    expect(find.text('skeleton'), findsNothing);
    await tester.pump(_ms);
    expect(find.text('skeleton'), findsOneWidget);
    await tester.pumpWidget(_gate(loading: false));
  });

  testWidgets('data inside 300 ms brings the content at once', (tester) async {
    await tester.pumpWidget(_gate(loading: true));
    await tester.pump(_ms * 200);
    await tester.pumpWidget(_gate(loading: false));
    expect(find.text('content'), findsOneWidget);
    expect(find.text('skeleton'), findsNothing);
    await tester.pump(_ms * 400);
    expect(find.text('skeleton'), findsNothing);
  });

  testWidgets('a shown skeleton stays 600 ms, then fades out in 150 ease-in '
      'as the content comes in 60 ms later', (tester) async {
    await tester.pumpWidget(_gate(loading: true));
    await tester.pump(_ms * 300);
    await tester.pump(_ms * 100);
    await tester.pumpWidget(_gate(loading: false));
    await tester.pump(_ms * 498);
    expect(find.text('skeleton'), findsOneWidget);
    expect(find.text('content'), findsNothing);
    // 899 ms in, the skeleton has been up for 599.
    await tester.pump(_ms);
    expect(find.text('content'), findsNothing);
    await tester.pump(_ms);
    expect(_skeletonOpacity(tester), 1);

    await tester.pump(_ms * 59);
    expect(find.text('content'), findsNothing);
    await tester.pump(_ms);
    expect(find.text('content'), findsOneWidget);
    await tester.pump(_ms * 15);
    expect(_skeletonOpacity(tester), closeTo(1 - _ei(0.5), 0.01));
    await tester.pump(_ms * 76);
    expect(find.text('skeleton'), findsNothing);
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('the content keeps its state as the skeleton leaves', (
    tester,
  ) async {
    await tester.pumpWidget(_gate(loading: true, skeletonNow: true));
    await tester.pump(_ms * 600);
    await tester.pumpWidget(_gate(loading: false, skeletonNow: true));
    await tester.pump();
    await tester.pump(_ms * 60);
    final content = tester.element(find.text('content'));
    await tester.pump(_ms * 100);
    expect(find.text('skeleton'), findsNothing);
    expect(tester.element(find.text('content')), same(content));
  });

  testWidgets('skeletonNow shows the skeleton without the wait', (
    tester,
  ) async {
    await tester.pumpWidget(_gate(loading: true));
    await tester.pump(_ms * 100);
    await tester.pumpWidget(_gate(loading: true, skeletonNow: true));
    expect(find.text('skeleton'), findsOneWidget);
    await tester.pumpWidget(_gate(loading: false, skeletonNow: true));
    await tester.pump(_ms * 599);
    expect(find.text('content'), findsNothing);
    await tester.pump(_ms);
    await tester.pump(_ms * 60);
    expect(find.text('content'), findsOneWidget);
    await tester.pump(_ms * 100);
    expect(find.text('skeleton'), findsNothing);
  });

  testWidgets('reduced motion: the skeleton and the content cross in 150', (
    tester,
  ) async {
    await tester.pumpWidget(_gate(loading: true, reduced: true));
    await tester.pump(_ms * 300);
    await tester.pump(_ms * 600);
    await tester.pumpWidget(_gate(loading: false, reduced: true));
    expect(find.text('content'), findsOneWidget);
    expect(find.text('skeleton'), findsOneWidget);
    await tester.pump();
    await tester.pump(_ms * 75);
    expect(_skeletonOpacity(tester), closeTo(1 - _ei(0.5), 0.01));
    await tester.pump(_ms * 76);
    expect(find.text('skeleton'), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
