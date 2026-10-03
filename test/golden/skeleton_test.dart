import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/skeleton.dart';

import 'golden.dart';
import 'press.dart';

void main() {
  setUpAll(loadAppFonts);

  const sizes = {
    IqSkeletonKind.ticket: Size(358, 136),
    IqSkeletonKind.row: Size(358, 64),
    IqSkeletonKind.line: Size(358, 14),
  };

  for (final kind in IqSkeletonKind.values) {
    final name = 'skeleton_${kind.name}';
    testWidgets(name, (tester) async {
      await expectComponentGolden(
        tester,
        name,
        stillMotion(IqSkeleton(kind: kind)),
        size: sizes[kind]!,
      );
    });
  }

  testWidgets('bars pulse while motion is on', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: IqSkeleton())),
    );
    double opacity() => tester
        .widget<FadeTransition>(
          find
              .descendant(
                of: find.byType(IqSkeleton),
                matching: find.byType(FadeTransition),
              )
              .first,
        )
        .opacity
        .value;
    final start = opacity();
    await tester.pump(const Duration(milliseconds: 450));
    expect(opacity(), greaterThan(start));
  });
}
