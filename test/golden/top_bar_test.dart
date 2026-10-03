import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/icon.dart';
import 'package:iqly_mobile/ui/top_bar.dart';

import 'golden.dart';

Finder icon(IqIcons glyph) =>
    find.byWidgetPredicate((w) => w is IqIcon && w.icon == glyph);

void main() {
  setUpAll(loadAppFonts);

  for (final variant in IqTopBarVariant.values) {
    testWidgets('${variant.name} variant', (tester) async {
      final bar = IqTopBar(variant: variant);
      await expectComponentGolden(
        tester,
        'top_bar_${variant.name}',
        SizedBox(width: 390, child: bar),
        size: Size(390, bar.preferredSize.height),
        padding: 0,
      );
    });
  }

  testWidgets('page with the trailing action', (tester) async {
    await expectComponentGolden(
      tester,
      'top_bar_page_trailing',
      const SizedBox(
        width: 390,
        child: IqTopBar(variant: IqTopBarVariant.page, showTrailing: true),
      ),
      size: const Size(390, 56),
      padding: 0,
    );
  });

  testWidgets('round actions reach their callbacks', (tester) async {
    final taps = <String>[];
    Future<void> pump(IqTopBar bar) =>
        tester.pumpWidget(MaterialApp(home: Scaffold(body: bar)));

    await pump(IqTopBar(onBell: () => taps.add('bell')));
    await tester.tap(icon(IqIcons.bell));
    await pump(
      IqTopBar(
        variant: IqTopBarVariant.page,
        showTrailing: true,
        onBack: () => taps.add('back'),
        onTrailing: () => taps.add('trailing'),
      ),
    );
    await tester.tap(icon(IqIcons.back));
    await tester.tap(icon(IqIcons.filter));
    await pump(
      IqTopBar(
        variant: IqTopBarVariant.sheet,
        onClose: () => taps.add('close'),
      ),
    );
    await tester.tap(icon(IqIcons.close));
    expect(taps, ['bell', 'back', 'trailing', 'close']);
  });
}
