import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/ticket_card.dart';

import '../golden/golden.dart';

Widget _card(String meta, {double textScale = 1}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: Center(
      child: IqTicketCard(meta: meta, kind: IqTicketCardKind.list),
    ),
  ),
);

void main() {
  setUpAll(loadAppFonts);

  testWidgets('a long business name gives way before the tier', (tester) async {
    await tester.pumpWidget(
      _card('Harbour Microfinance Bank of West Africa · Advanced'),
    );
    final tier = tester.renderObject<RenderParagraph>(find.text(' · Advanced'));
    expect(tier.didExceedMaxLines, isFalse);
    final name = tester.renderObject<RenderParagraph>(
      find.text('Harbour Microfinance Bank of West Africa'),
    );
    expect(name.didExceedMaxLines, isTrue);
  });

  testWidgets('very large text ellipsizes the whole line without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      _card('Harbour Microfinance · Advanced', textScale: 3),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Harbour Microfinance · Advanced'), findsOneWidget);
  });
}
