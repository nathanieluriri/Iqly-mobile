import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/bookmark.dart';
import 'package:iqly_mobile/ui/brief_card.dart';
import 'package:iqly_mobile/ui/meta.dart';

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

  testWidgets('time chip follows the prize', (tester) async {
    await expectComponentGolden(
      tester,
      'brief_card_carousel_time',
      const IqBriefCard(
        kind: IqBriefCardKind.carousel,
        time: '2 min',
        meta: [
          IqMeta(kind: IqMetaKind.reward, label: '₦150,000'),
          IqMeta(kind: IqMetaKind.urgent, label: '6h left'),
        ],
      ),
      size: const Size(272, 291),
    );
  });

  testWidgets('time is not doubled when meta carries one', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: IqBriefCard(time: '2 min')),
      ),
    );
    expect(find.text('2 min'), findsNothing);
    expect(find.text('5 min'), findsOneWidget);
  });
}
