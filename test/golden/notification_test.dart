import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/notification.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final kind in IqNotificationKind.values) {
    testWidgets(kind.name, (tester) async {
      await expectComponentGolden(
        tester,
        'notification_${kind.name}',
        SizedBox(width: 358, child: IqNotification(kind: kind)),
        size: const Size(358, 91),
      );
    });
  }

  testWidgets('read, no divider', (tester) async {
    await expectComponentGolden(
      tester,
      'notification_read',
      const SizedBox(
        width: 358,
        child: IqNotification(unread: false, divider: false),
      ),
      size: const Size(358, 91),
    );
  });

  testWidgets('taps reach onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: IqNotification(onTap: () => taps++)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(IqNotification));
    expect(taps, 1);
  });
}
