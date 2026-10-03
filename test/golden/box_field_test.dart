import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/box_field.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final tone in IqBoxFieldTone.values) {
    for (final state in IqBoxFieldState.values) {
      final name = 'box_field_${tone.name}_${state.name}';
      testWidgets(name, (tester) async {
        await expectComponentGolden(
          tester,
          name,
          IqBoxField(tone: tone, state: state),
          size: const Size(358, 56),
        );
      });
    }
  }

  testWidgets('takes input and turns Active on focus', (tester) async {
    final typed = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: IqBoxField(onChanged: typed.add)),
      ),
    );
    await tester.tap(find.byType(IqBoxField));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
      isTrue,
    );
    await tester.enterText(find.byType(TextField), 'adaeze@');
    expect(typed.last, 'adaeze@');
  });
}
