import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/bookmark.dart';
import 'package:iqly_mobile/ui/brief_card.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  const sizes = {
    IqBriefCardKind.feature: Size(358, 307),
    IqBriefCardKind.carousel: Size(272, 291),
    IqBriefCardKind.row: Size(358, 103),
  };

  for (final kind in IqBriefCardKind.values) {
    testWidgets('${kind.name} kind', (tester) async {
      await expectComponentGolden(
        tester,
        'brief_card_${kind.name}',
        IqBriefCard(kind: kind),
        size: sizes[kind]!,
      );
    });

    testWidgets('${kind.name} kind, closing soon and saved', (tester) async {
      await expectComponentGolden(
        tester,
        'brief_card_${kind.name}_closing',
        IqBriefCard(
          kind: kind,
          closingSoon: true,
          showBookmark: true,
          bookmark: IqBookmarkState.on,
        ),
        size: sizes[kind]!,
      );
    });
  }
}
