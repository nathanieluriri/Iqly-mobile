import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/video_preview.dart';

Future<void> _pump(
  WidgetTester tester,
  IqVideoPreviewState state, {
  double progress = 0.75,
}) => tester.pumpWidget(
  MaterialApp(
    theme: buildTheme(),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 358,
          child: IqVideoPreview(state: state, progress: progress),
        ),
      ),
    ),
  ),
);

Finder get _fill => find.byWidgetPredicate(
  (w) => w is ColoredBox && w.color == IqColors.accent,
);

/// How much of the 100 pt thread is filled, or null with no thread.
double? _thread(WidgetTester tester) =>
    _fill.evaluate().isEmpty ? null : tester.getSize(_fill).width;

double _slot(WidgetTester tester) =>
    tester.getSize(find.byType(Collapse)).height;

void main() {
  testWidgets('a finished upload fills its thread to the end, then folds it '
      'away', (tester) async {
    await _pump(tester, IqVideoPreviewState.uploading);
    expect(_thread(tester), 75);

    await _pump(tester, IqVideoPreviewState.ready);
    final fills = <double>[];
    for (var at = 16; at <= 200; at += 16) {
      await tester.pump(const Duration(milliseconds: 16));
      final fill = _thread(tester);
      expect(fill, isNotNull, reason: 'at $at ms');
      fills.add(fill!);
      expect(_slot(tester), 6, reason: 'at $at ms');
    }
    expect(fills.first, inExclusiveRange(75, 100));
    await tester.pump(const Duration(milliseconds: 8));
    expect(_thread(tester), 100);

    await tester.pump(const Duration(milliseconds: 100));
    expect(_slot(tester), inExclusiveRange(0, 6));
    await tester.pumpAndSettle();
    expect(_slot(tester), 0);
    expect(find.text('18 MB · uploaded, ready to send'), findsOneWidget);
  });

  testWidgets('a failed upload drops its thread at once', (tester) async {
    await _pump(tester, IqVideoPreviewState.uploading);
    await _pump(tester, IqVideoPreviewState.failed);
    expect(_thread(tester), isNull);
  });

  testWidgets('reduced motion: the thread goes with the upload', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _pump(tester, IqVideoPreviewState.uploading);
    await _pump(tester, IqVideoPreviewState.ready);
    expect(_thread(tester), isNull);
  });
}
