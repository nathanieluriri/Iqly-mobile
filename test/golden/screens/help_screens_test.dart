import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/help_service.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/proof_tile.dart';

import '../golden.dart';
import 'app_harness.dart';
import 'polls_notifications_help_harness.dart';

Future<void> _write(WidgetTester tester) async {
  await tester.tap(find.byType(IqProofTile));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(EditableText), figmaMessage);
  await tester.pumpAndSettle();
}

Future<void> _golden(
  WidgetTester tester,
  String name, {
  HelpService? help,
  Future<void> Function(WidgetTester tester)? act,
}) async {
  await pumpApp(tester, Routes.help, overrides: laneOverrides(help: help));
  if (act != null) {
    await act(tester);
    await tester.pumpAndSettle();
  }
  await expectMatchesGolden(find.byType(MaterialApp), 'goldens/help_$name.png');
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('Help request (141:5818)', (tester) async {
    await _golden(tester, 'request', act: _write);
  });

  testWidgets('Help request before anything is written', (tester) async {
    await _golden(tester, 'request_empty');
  });

  testWidgets('Help thread · replied (141:5876)', (tester) async {
    await _golden(
      tester,
      'thread_replied',
      act: (tester) async {
        await _write(tester);
        await tester.tap(find.text('Send to support'));
      },
    );
  });

  testWidgets('Help thread while support types', (tester) async {
    await _golden(
      tester,
      'thread_typing',
      help: TypingHelpService(),
      act: (tester) async {
        await _write(tester);
        await tester.tap(find.text('Send to support'));
      },
    );
  });
}
