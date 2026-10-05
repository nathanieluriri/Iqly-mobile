import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/field.dart';

Widget _app(Widget child, {bool reduced = false}) => MaterialApp(
  theme: buildTheme(),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Scaffold(body: Center(child: child)),
  ),
);

Widget _city(String? city) => IqField(
  kind: IqFieldKind.picker,
  size: IqFieldSize.large,
  state: city == null ? IqFieldState.empty : IqFieldState.valid,
  pickerLabel: 'City',
  pickerValue: city ?? '',
  pickerPlaceholder: 'Select city',
);

void main() {
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
