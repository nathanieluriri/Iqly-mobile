import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/search_box.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final state in IqSearchBoxState.values) {
    testWidgets('${state.name} state', (tester) async {
      await expectComponentGolden(
        tester,
        'search_box_${state.name}',
        SizedBox(width: 358, child: IqSearchBox(state: state)),
        size: const Size(358, 48),
      );
    });
  }

  testWidgets('clear empties the field', (tester) async {
    final controller = TextEditingController(text: 'withdraw');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: IqSearchBox(controller: controller)),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Clear search'));
    expect(controller.text, isEmpty);
  });
}
