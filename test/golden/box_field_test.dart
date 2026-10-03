import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/box_field.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final tone in IqBoxFieldTone.values) {
    for (final state in IqBoxFieldState.values) {
      final name = 'box_field_${tone.name}_${state.name}';
      final error = state == IqBoxFieldState.error;
      testWidgets(name, (tester) async {
        await expectComponentGolden(
          tester,
          name,
          IqBoxField(
            tone: tone,
            state: state,
            help: error
                ? 'That email doesn’t look right. Check for typos.'
                : '',
            controller: error
                ? TextEditingController(text: 'adaeze@example')
                : null,
          ),
          size: Size(358, error ? 81 : 56),
          background: error && tone == IqBoxFieldTone.ink
              ? IqColors.brand
              : IqColors.bg,
        );
      });
    }
  }

  testWidgets('Error keeps the text field, and its focus, in place', (
    tester,
  ) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    Widget box(IqBoxFieldState? state) => MaterialApp(
      home: Scaffold(
        body: IqBoxField(state: state, help: 'Help', focusNode: focus),
      ),
    );
    await tester.pumpWidget(box(null));
    focus.requestFocus();
    await tester.pump();
    final field = tester.state(find.byType(EditableText));
    await tester.pumpWidget(box(IqBoxFieldState.error));
    await tester.pumpAndSettle();
    expect(find.text('Help'), findsOneWidget);
    expect(tester.state(find.byType(EditableText)), same(field));
    expect(focus.hasFocus, isTrue);
  });

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
