import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/countdown.dart';

import 'golden.dart';
import 'press.dart';

void main() {
  setUpAll(loadAppFonts);

  const sizes = {
    IqCountdownTone.hot: Size(154, 33),
    IqCountdownTone.warm: Size(152, 31),
    IqCountdownTone.calm: Size(155, 34),
    IqCountdownTone.closed: Size(121, 31),
  };

  for (final tone in IqCountdownTone.values) {
    testWidgets('${tone.name} tone', (tester) async {
      await expectComponentGolden(
        tester,
        'countdown_${tone.name}',
        stillMotion(IqCountdown(tone: tone)),
        size: sizes[tone]!,
      );
    });
  }

  testWidgets('hot pulses, and holds still under reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: IqCountdown()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: IqCountdown()),
        ),
      ),
    );
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('a new time ticks in', (tester) async {
    Widget chip(String time) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: IqCountdown(time: time, tone: IqCountdownTone.calm),
      ),
    );
    await tester.pumpWidget(chip('2 days'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(chip('1 day'));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('2 days'), findsOneWidget);
    expect(find.text('1 day'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('2 days'), findsNothing);
  });

  test('tone follows the ladder', () {
    expect(IqCountdownTone.of(const Duration(hours: 5)), IqCountdownTone.hot);
    expect(IqCountdownTone.of(const Duration(hours: 18)), IqCountdownTone.warm);
    expect(IqCountdownTone.of(const Duration(days: 2)), IqCountdownTone.calm);
    expect(IqCountdownTone.of(Duration.zero), IqCountdownTone.closed);
    expect(
      IqCountdownTone.of(const Duration(days: 2), closed: true),
      IqCountdownTone.closed,
    );
  });
}
