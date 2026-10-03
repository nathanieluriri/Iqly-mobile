import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/bookmark.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final tone in IqBookmarkTone.values) {
    for (final state in IqBookmarkState.values) {
      testWidgets('${state.name} ${tone.name}', (tester) async {
        await expectComponentGolden(
          tester,
          'bookmark_${state.name}_${tone.name}',
          IqBookmark(state: state, tone: tone, onChanged: (_) {}),
          size: const Size(44, 44),
          background: tone == IqBookmarkTone.ink ? IqColors.brand : IqColors.bg,
        );
      });
    }
  }

  testWidgets('tap flips the state', (tester) async {
    var state = IqBookmarkState.off;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Center(
            child: IqBookmark(
              state: state,
              onChanged: (next) => setState(() => state = next),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(IqBookmark));
    await tester.pump();
    expect(state, IqBookmarkState.on);
  });
}
