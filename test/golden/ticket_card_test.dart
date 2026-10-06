import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/urgency.dart';
import 'package:iqly_mobile/ui/bookmark.dart';
import 'package:iqly_mobile/ui/ticket_card.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final kind in IqTicketCardKind.values) {
    final size = kind == IqTicketCardKind.hero
        ? const Size(300, 188)
        : const Size(358, 136);
    for (final bookmark in [false, true]) {
      final name = 'ticket_card_${kind.name}${bookmark ? '_bookmark' : ''}';
      testWidgets(name, (tester) async {
        await expectComponentGolden(
          tester,
          name,
          IqTicketCard(kind: kind, showBookmark: bookmark),
          size: size,
        );
      });
    }
  }

  testWidgets('bookmark toggles and the card opens', (tester) async {
    IqBookmarkState? saved;
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IqTicketCard(
            kind: IqTicketCardKind.list,
            showBookmark: true,
            onBookmarkChanged: (s) => saved = s,
            onTap: () => opened++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(IqBookmark));
    expect(saved, IqBookmarkState.on);
    await tester.tap(find.text('A tagline for a solar kiosk network'));
    expect(opened, 1);
  });

  testWidgets('a long deadline keeps clear of the rule', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: IqTicketCard(
            kind: IqTicketCardKind.list,
            urgency: 'Closes in 25 days',
          ),
        ),
      ),
    );
    final chip = tester.getRect(find.byType(IqUrgency));
    final rule = tester.getRect(find.text('Top 10% paid'));
    expect(rule.left, greaterThanOrEqualTo(chip.right + 10));
    expect(rule.right, lessThanOrEqualTo(246));
  });
}
