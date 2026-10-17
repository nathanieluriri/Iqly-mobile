import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/patches.dart';
import 'package:iqly_mobile/features/splash/patch_dialog.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  Future<void> dialog(WidgetTester tester, String name, PatchPhase phase) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    return expectComponentGolden(
      tester,
      name,
      IqPatchDialog(phase: phase),
      size: Size(IqPatchDialog.width, switch (phase) {
        PatchPhase.downloading => 274,
        PatchPhase.ready => 356,
        _ => 312,
      }),
    );
  }

  testWidgets('downloading', (tester) async {
    await dialog(tester, 'patch_dialog_downloading', PatchPhase.downloading);
  });

  testWidgets('ready', (tester) async {
    await dialog(tester, 'patch_dialog_ready', PatchPhase.ready);
  });

  testWidgets('failed', (tester) async {
    await dialog(tester, 'patch_dialog_failed', PatchPhase.failed);
  });

  testWidgets('fill levels', (tester) async {
    await expectComponentGolden(
      tester,
      'fill_mark',
      const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IqFillMark(level: 0),
          SizedBox(width: 20),
          IqFillMark(level: 0.3),
          SizedBox(width: 20),
          IqFillMark(level: 0.55, wave: 0.25),
          SizedBox(width: 20),
          IqFillMark(level: 0.85, wave: 0.5),
          SizedBox(width: 20),
          IqFillMark(level: 1),
        ],
      ),
      size: const Size(560, 96),
    );
  });
}
