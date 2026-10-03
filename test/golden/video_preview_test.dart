import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/pressable.dart';
import 'package:iqly_mobile/ui/video_preview.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  const heights = {
    IqVideoPreviewState.ready: 267.0,
    IqVideoPreviewState.uploading: 273.0,
    IqVideoPreviewState.failed: 285.0,
  };

  for (final state in IqVideoPreviewState.values) {
    testWidgets('${state.name} state', (tester) async {
      await expectComponentGolden(
        tester,
        'video_preview_${state.name}',
        SizedBox(width: 358, child: IqVideoPreview(state: state)),
        size: Size(358, heights[state]!),
      );
    });
  }

  testWidgets('ready state with the duration stamp', (tester) async {
    await expectComponentGolden(
      tester,
      'video_preview_ready_duration',
      const SizedBox(width: 358, child: IqVideoPreview(showDuration: true)),
      size: const Size(358, 267),
    );
  });

  testWidgets('play, remove and retry call back', (tester) async {
    var plays = 0;
    var removes = 0;
    var retries = 0;
    Widget preview(IqVideoPreviewState state) => MaterialApp(
      home: Center(
        child: SizedBox(
          width: 358,
          child: IqVideoPreview(
            state: state,
            onPlay: () => plays++,
            onRemove: () => removes++,
            onRetry: () => retries++,
          ),
        ),
      ),
    );
    await tester.pumpWidget(preview(IqVideoPreviewState.ready));
    await tester.tap(find.bySemanticsLabel('Play'));
    await tester.tap(find.bySemanticsLabel('Remove'));
    await tester.pumpWidget(preview(IqVideoPreviewState.failed));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    final retry = tester.getSize(
      find.ancestor(of: find.text('Retry'), matching: find.byType(IqPressable)),
    );
    expect(retry.width >= 44 && retry.height >= 44, isTrue);
    await tester.tap(find.bySemanticsLabel('Play'));
    expect((plays, removes, retries), (1, 1, 1));
  });

  testWidgets('upload to ready pops the play sticker in', (tester) async {
    Widget preview(IqVideoPreviewState state) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 358,
          child: IqVideoPreview(state: state, showDuration: true),
        ),
      ),
    );
    await tester.pumpWidget(preview(IqVideoPreviewState.uploading));
    expect(find.text('Uploading… 64% of 18 MB'), findsOneWidget);
    await tester.pumpWidget(preview(IqVideoPreviewState.ready));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    expect(find.text('0:42'), findsOneWidget);
  });
}
