import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/router.dart';

import '../golden.dart';
import 'app_harness.dart';
import 'submit_harness.dart';

/// Drafts (481:23202) and its sheets and selecting state at 390 x 844, on
/// the two sample drafts.
Future<void> _golden(
  WidgetTester tester,
  String name, {
  Future<void> Function(WidgetTester tester)? act,
}) async {
  await pumpApp(
    tester,
    Routes.drafts,
    repository: DemoRepository(DemoData(now: figmaNow)),
    overrides: instantSubmit(),
  );
  if (act != null) {
    await act(tester);
    await tester.pumpAndSettle();
  }
  await precacheImages(tester);
  await expectMatchesGolden(find.byType(MaterialApp), 'goldens/$name.png');
}

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

Future<void> _selectBoth(WidgetTester tester) async {
  await tester.longPress(find.text('No light? We dey'));
  await tester.pumpAndSettle();
  await _tap(tester, 'Charge up, stay connected');
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('drafts (481:23202)', (tester) async {
    await _golden(tester, 'drafts');
  });

  testWidgets('discard? (499:27019)', (tester) async {
    await _golden(
      tester,
      'drafts_discard_one',
      act: (tester) async {
        await tester.longPress(find.text('No light? We dey'));
        await tester.pumpAndSettle();
        await _tap(tester, 'Discard 1 draft');
      },
    );
  });

  testWidgets('selecting (499:27119)', (tester) async {
    await _golden(tester, 'drafts_selecting', act: _selectBoth);
  });

  testWidgets('discard 2? (499:27256)', (tester) async {
    await _golden(
      tester,
      'drafts_discard_many',
      act: (tester) async {
        await _selectBoth(tester);
        await _tap(tester, 'Discard 2 drafts');
      },
    );
  });
}
