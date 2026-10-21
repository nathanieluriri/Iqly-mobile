import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/biz_segment.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('a track with one selected', (tester) async {
    await expectComponentGolden(
      tester,
      'biz_segment',
      IqBizSegment.track(
        children: const [
          IqBizSegment(label: 'For you', state: IqBizSegmentState.selected),
          IqBizSegment(label: 'All'),
          IqBizSegment(label: 'Saved'),
        ],
      ),
      size: const Size(200, 44),
    );
  });
}
