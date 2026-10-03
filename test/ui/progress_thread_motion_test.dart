import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/ui/icon.dart';
import 'package:iqly_mobile/ui/progress_thread.dart';

import '../golden/golden.dart';

const _ms = Duration(milliseconds: 1);
const _width = 358.0;
const _half = 181.25 / 358;

double _eo(double t) => IqCurves.easeOut.transform(t);

Widget _thread(
  IqProgressThreadState state, {
  String status = 'Amount next · bank saved',
  String count = '2 OF 2',
  String errorText = 'Fix the account number',
  bool reduced = false,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: _width,
          child: IqProgressThread(
            state: state,
            status: status,
            count: count,
            readyText: 'Ready · bank saved',
            errorText: errorText,
          ),
        ),
      ),
    ),
  ),
);

Finder get _clip => find.descendant(
  of: find.byType(IqProgressThread),
  matching: find.byType(ClipRect),
);

/// How far the rule shows, in px; the whole rule once nothing clips it.
double _shown(WidgetTester tester) {
  if (_clip.evaluate().isEmpty) return _width;
  return tester
      .widget<ClipRect>(_clip)
      .clipper!
      .getClip(const Size(_width, 6))
      .right;
}

double _iconScale(WidgetTester tester, IqIcons icon) => tester
    .widget<ScaleTransition>(
      find
          .ancestor(
            of: find.byWidgetPredicate((w) => w is IqIcon && w.icon == icon),
            matching: find.byType(ScaleTransition),
          )
          .first,
    )
    .scale
    .value;

void main() {
  setUpAll(loadAppFonts);

  testWidgets('Ready on arrival draws its line left to right, 240', (
    tester,
  ) async {
    await tester.pumpWidget(_thread(IqProgressThreadState.ready));
    expect(_shown(tester), 0);
    await tester.pump(_ms * 120);
    expect(_shown(tester), closeTo(_width * _eo(0.5), 0.5));
    await tester.pump(_ms * 121);
    expect(_clip, findsNothing);
  });

  testWidgets('Progress on arrival stands still', (tester) async {
    await tester.pumpWidget(_thread(IqProgressThreadState.progress));
    expect(_clip, findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('to Ready: the line grows from half to full over 240 as its '
      'colour crosses in 160, the icon pops and the words roll', (
    tester,
  ) async {
    await tester.pumpWidget(_thread(IqProgressThreadState.progress));
    await tester.pumpWidget(_thread(IqProgressThreadState.ready));
    expect(_shown(tester), closeTo(_width * _half, 0.5));

    await tester.pump(_ms * 80);
    final fades = tester
        .widgetList<Opacity>(
          find.descendant(of: _clip, matching: find.byType(Opacity)),
        )
        .map((o) => o.opacity)
        .toList();
    expect(fades, [closeTo(1 - _eo(0.5), 0.01), closeTo(_eo(0.5), 0.01)]);
    expect(find.text('Amount next · bank saved'), findsOneWidget);
    expect(find.text('Ready · bank saved'), findsOneWidget);
    expect(
      _iconScale(tester, IqIcons.success),
      closeTo(0.6 + 0.4 * _eo(80 / 220), 0.01),
    );

    await tester.pump(_ms * 40);
    expect(
      _shown(tester),
      closeTo(_width * (_half + (1 - _half) * _eo(0.5)), 0.5),
    );
    await tester.pump(_ms * 121);
    expect(_clip, findsNothing);
    expect(find.text('Amount next · bank saved'), findsNothing);
    expect(_iconScale(tester, IqIcons.success), 1);
    expect(find.text('2 OF 2'), findsNothing);
  });

  testWidgets('back to Progress: the line shortens to half, the icon leaves', (
    tester,
  ) async {
    await tester.pumpWidget(_thread(IqProgressThreadState.ready));
    await tester.pump(_ms * 300);
    await tester.pumpWidget(_thread(IqProgressThreadState.progress));
    await tester.pump(_ms * 120);
    expect(_shown(tester), closeTo(_width * (1 + (_half - 1) * _eo(0.5)), 0.5));
    await tester.pump(_ms * 121);
    expect(find.byType(IqIcon), findsNothing);
    expect(find.text('2 OF 2'), findsOneWidget);
  });

  testWidgets('the count rolls its changed digit', (tester) async {
    await tester.pumpWidget(
      _thread(IqProgressThreadState.progress, count: '1 OF 2'),
    );
    await tester.pumpWidget(
      _thread(IqProgressThreadState.progress, count: '2 OF 2'),
    );
    await tester.pump(_ms * 80);
    expect(find.text('1 OF 2'), findsOneWidget);
    expect(find.text('2 OF 2'), findsOneWidget);
    await tester.pump(_ms * 81);
    await tester.pump();
    expect(find.text('1 OF 2'), findsNothing);
  });

  testWidgets('words too long for the line wrap to a second', (tester) async {
    await tester.pumpWidget(_thread(IqProgressThreadState.error));
    final one = tester.getSize(find.byType(IqProgressThread)).height;
    await tester.pumpWidget(
      _thread(
        IqProgressThreadState.error,
        errorText: 'Not saved. Check your connection, then tap Save changes.',
      ),
    );
    await tester.pump(_ms * 200);
    final two = tester.getSize(find.byType(IqProgressThread)).height;
    expect(two, greaterThan(one + 15));
    expect(
      find.text('Not saved. Check your connection, then tap Save changes.'),
      findsOneWidget,
    );
  });

  testWidgets('reduced motion: every change lands at once', (tester) async {
    await tester.pumpWidget(
      _thread(IqProgressThreadState.ready, reduced: true),
    );
    expect(_clip, findsNothing);
    await tester.pumpWidget(
      _thread(IqProgressThreadState.progress, reduced: true),
    );
    await tester.pump();
    expect(_clip, findsNothing);
    expect(find.byType(IqIcon), findsNothing);
    await tester.pumpWidget(
      _thread(IqProgressThreadState.error, reduced: true),
    );
    await tester.pump();
    expect(_iconScale(tester, IqIcons.error), 1);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
