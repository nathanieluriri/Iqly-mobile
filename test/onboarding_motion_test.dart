import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/onboarding/onboarding_layout.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/field.dart';

Widget _app(Widget child, {bool reduced = false}) => MaterialApp(
  theme: buildTheme(),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Scaffold(body: Center(child: child)),
  ),
);

double _checkScale(WidgetTester tester) => tester
    .widget<ScaleTransition>(
      find.descendant(
        of: find.byType(AutosaveCheck),
        matching: find.byType(ScaleTransition),
      ),
    )
    .scale
    .value;

Widget _city(String? city) => IqField(
  kind: IqFieldKind.picker,
  size: IqFieldSize.large,
  state: city == null ? IqFieldState.empty : IqFieldState.valid,
  pickerLabel: 'City',
  pickerValue: city ?? '',
  pickerPlaceholder: 'Select city',
);

void main() {
  testWidgets('the autosave check pops in with a small overshoot', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const AutosaveCheck(saved: false)));
    await tester.pumpWidget(_app(const AutosaveCheck(saved: true)));
    await tester.pump(const Duration(milliseconds: 20));
    final early = _checkScale(tester);
    expect(early, greaterThanOrEqualTo(0.6));
    expect(early, lessThan(1));
    var peak = early;
    for (var t = 0; t < 9; t++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (_checkScale(tester) > peak) peak = _checkScale(tester);
    }
    expect(peak, greaterThan(1));
    await tester.pumpAndSettle();
    expect(_checkScale(tester), 1);
  });

  testWidgets('reduced motion: the autosave check appears in place', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const AutosaveCheck(saved: false), reduced: true),
    );
    await tester.pumpWidget(
      _app(const AutosaveCheck(saved: true), reduced: true),
    );
    expect(_checkScale(tester), 1);
  });

  testWidgets('a chosen picker value crossfades in over 200 ms', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_city(null)));
    await tester.pumpWidget(_app(_city('Ikeja')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Select city'), findsOneWidget);
    expect(find.text('Ikeja'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('Select city'), findsNothing);
    expect(find.text('Ikeja'), findsOneWidget);
  });

  testWidgets('reduced motion: the picker value changes in place', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_city(null), reduced: true));
    await tester.pumpWidget(_app(_city('Ikeja'), reduced: true));
    await tester.pump();
    expect(find.text('Select city'), findsNothing);
    expect(find.text('Ikeja'), findsOneWidget);
  });
}
