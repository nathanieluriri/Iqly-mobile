import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/notifications_service.dart';
import 'package:iqly_mobile/router.dart';

import '../golden.dart';
import 'app_harness.dart';
import 'polls_notifications_help_harness.dart';

Future<void> _golden(
  WidgetTester tester,
  String name, {
  NotificationsService? notifications,
}) async {
  await pumpApp(
    tester,
    Routes.notifications,
    overrides: laneOverrides(notifications: notifications),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
  await expectMatchesGolden(
    find.byType(MaterialApp),
    'goldens/notifications_$name.png',
  );
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('Notifications (39:24)', (tester) async {
    await _golden(tester, 'feed');
  });

  testWidgets('Notifications · empty (39:180)', (tester) async {
    await _golden(tester, 'empty', notifications: EmptyNotificationsService());
  });

  testWidgets('failed to load', (tester) async {
    await _golden(
      tester,
      'failed',
      notifications: FailingNotificationsService(),
    );
  });
}
