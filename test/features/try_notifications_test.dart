import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/device.dart';
import 'package:iqly_mobile/features/more/try_notifications_screen.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/surfaces/surface_samples.dart';

import '../golden/screens/more_harness.dart';

class _Trial implements NotificationTrial {
  final calls = <String>[];
  bool drawn = true;

  @override
  Future<void> payout() async => calls.add('payout');

  @override
  Future<void> poll() async => calls.add('poll');

  @override
  Future<void> won() async => calls.add('won');

  @override
  Future<void> draft() async => calls.add('draft');

  @override
  Future<bool> widgets() async {
    calls.add('widgets');
    return drawn;
  }
}

void main() {
  testWidgets('holding the version line on More opens Try notifications', (
    tester,
  ) async {
    await pumpMore(tester, Routes.more);
    final version = find.textContaining('IQLY FOR');
    await tester.scrollUntilVisible(version, 300);
    await tester.tap(version);
    await tester.pumpAndSettle();
    expect(find.byType(TryNotificationsScreen), findsNothing);
    await tester.longPress(version);
    await tester.pumpAndSettle();
    expect(find.byType(TryNotificationsScreen), findsOneWidget);
  });

  testWidgets('each row posts its notification and says when it lands', (
    tester,
  ) async {
    final trial = _Trial();
    await pumpMore(
      tester,
      Routes.tryNotifications,
      overrides: [notificationTrialProvider.overrideWithValue(trial)],
    );
    for (final label in [
      '₦10,000.00 on its way',
      'New poll from Orchid Foods',
      'You won ₦12,500.00',
      'Your Sunline draft is waiting',
    ]) {
      await tester.tap(find.text(label));
      await tester.pump();
      expect(find.text(TryNotificationsScreen.coming), findsOneWidget);
      await tester.pumpAndSettle();
    }
    expect(trial.calls, ['payout', 'poll', 'won', 'draft']);

    await tester.tap(find.text('Refresh the widgets'));
    await tester.pump();
    expect(find.text(TryNotificationsScreen.refreshed), findsOneWidget);
    await tester.pumpAndSettle();

    trial.drawn = false;
    await tester.tap(find.text('Refresh the widgets'));
    await tester.pump();
    expect(find.text(TryNotificationsScreen.noWidgets), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('with notifications off for iQLY, the permission banner comes '
      'first', (tester) async {
    await pumpMore(
      tester,
      Routes.tryNotifications,
      device: DemoDeviceService(delay: Duration.zero)..notificationsOn = false,
      overrides: [notificationTrialProvider.overrideWithValue(_Trial())],
    );
    expect(
      find.text('Notifications are off for iQLY on this phone.'),
      findsOneWidget,
    );
  });
}
