import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/device.dart';
import 'package:iqly_mobile/data/media_service.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/data/notifications_service.dart';
import 'package:iqly_mobile/data/profile_service.dart';
import 'package:iqly_mobile/data/repository.dart';

import '../golden.dart';
import 'app_harness.dart';
import 'polls_notifications_help_harness.dart';
import 'profile_harness.dart';

/// The demo wallet withdrawn down to ₦0.00 (484:23450): a completed
/// ₦15,000.00 withdrawal takes the available balance.
class EmptyWalletRepository extends ScriptedRepository {
  @override
  Future<List<LedgerEntry>> ledger() async => [
    LedgerEntry(
      id: 'l7',
      type: LedgerType.withdrawal,
      amountKobo: -1500000,
      createdAt: figmaNow.subtract(const Duration(hours: 1)),
    ),
    ...data.ledger,
  ];
}

/// The real router at [location] with the More lanes' services answering at
/// once on the Figma clock: profile, help, notifications and the phone.
Future<ProviderContainer> pumpMore(
  WidgetTester tester,
  String location, {
  IqlyRepository? repository,
  Map<String, Object>? prefs,
  List<Override> overrides = const [],
  ProfileService? profile,
  NotificationsService? notifications,
  DeviceService? device,
  bool settle = true,
  bool reducedMotion = true,
}) async {
  final container = await pumpApp(
    tester,
    location,
    repository: repository,
    prefs: prefs,
    reducedMotion: reducedMotion,
    settle: false,
    overrides: [
      ...laneOverrides(notifications: notifications),
      profileServiceProvider.overrideWithValue(profile ?? TestProfileService()),
      deviceServiceProvider.overrideWithValue(
        device ?? DemoDeviceService(delay: Duration.zero),
      ),
      mediaServiceProvider.overrideWithValue(
        DemoMediaService(delay: Duration.zero),
      ),
      ...overrides,
    ],
  );
  if (settle) {
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }
  return container;
}

/// The screen as it stands, against `goldens/more_<name>.png`.
Future<void> moreGolden(WidgetTester tester, String name) async {
  await precacheImages(tester);
  await tester.pumpAndSettle();
  await expectMatchesGolden(find.byType(MaterialApp), 'goldens/more_$name.png');
}

/// The frames are iOS (the More footer names it).
final ios = TargetPlatformVariant.only(TargetPlatform.iOS);
