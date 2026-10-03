import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/field.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final size in IqFieldSize.values) {
    for (final kind in IqFieldKind.values) {
      for (final state in IqFieldState.values) {
        final tall =
            state == IqFieldState.error ||
            (state == IqFieldState.valid && kind == IqFieldKind.text);
        final height =
            (size == IqFieldSize.large ? 70.0 : 62.0) + (tall ? 24 : 0);
        final name = 'field_${kind.name}_${state.name}_${size.name}';
        testWidgets(name, (tester) async {
          await expectComponentGolden(
            tester,
            name,
            SizedBox(
              width: 358,
              child: IqField(
                kind: kind,
                state: state,
                size: size,
                controller: state == IqFieldState.empty
                    ? null
                    : TextEditingController(text: '0123456789'),
              ),
            ),
            size: Size(358, height),
          );
        });
      }
    }
  }

  testWidgets('text field takes input and turns Active on focus', (
    tester,
  ) async {
    final typed = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: IqField(onChanged: typed.add)),
      ),
    );
    await tester.tap(find.byType(IqField));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
      isTrue,
    );
    await tester.enterText(find.byType(TextField), '0123');
    expect(typed.last, '0123');
  });

  testWidgets('picker taps reach onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IqField(kind: IqFieldKind.picker, onTap: () => taps++),
        ),
      ),
    );
    await tester.tap(find.byType(IqField));
    expect(taps, 1);
  });
}
