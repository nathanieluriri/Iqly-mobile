import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/kyc_service.dart';
import 'package:iqly_mobile/features/kyc/kyc_sheet.dart';
import 'package:iqly_mobile/features/wallet/withdraw_sheet.dart';
import 'package:iqly_mobile/router.dart';

import '../data/live/live_data_fixtures.dart' show FakeApi;
import '../support/live_launch.dart';

const screenshotStatus = KycStatus(
  required: true,
  verified: false,
  tier: 1,
  requiredTier: 2,
  nextCheck: KycCheckKind.document,
  checks: {KycCheckKind.identity: KycCheckState.passed},
);

class ScreenshotKyc implements KycService {
  @override
  Future<KycStatus> status() async => screenshotStatus;

  @override
  Future<KycStatus> verify(KycCheck check) async => screenshotStatus;

  @override
  Future<KycStatus> upload(KycCheckKind check, KycEvidence file) async =>
      screenshotStatus;
}

Future<void> capture(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('app-surface')),
  );
  final image = await boundary.toImage(pixelRatio: 1);
  expect(image.width, 390);
  expect(image.height, 844);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final directory = Directory('build/kyc-screenshots');
  await directory.create(recursive: true);
  final file = File('${directory.path}/$name.png');
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  expect(await file.exists(), isTrue);
}

void main() {
  testWidgets('writes deterministic 390x844 contributor KYC screenshots', (
    tester,
  ) async {
    await pumpLiveLaunch(
      tester,
      Routes.home,
      api: FakeApi().api(),
      overrides: [kycServiceProvider.overrideWithValue(ScreenshotKyc())],
    );
    await capture(tester, 'discover-kyc');

    await pumpLiveLaunch(
      tester,
      Routes.more,
      api: FakeApi().api(),
      overrides: [kycServiceProvider.overrideWithValue(ScreenshotKyc())],
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Verification'));
    await capture(tester, 'more-kyc');

    await pumpLiveLaunch(
      tester,
      Routes.withdraw,
      api: FakeApi().api(),
      overrides: [kycServiceProvider.overrideWithValue(ScreenshotKyc())],
    );
    await capture(tester, 'withdrawal-kyc');
    expect(find.byType(KycSheet), findsOneWidget);
    expect(find.byType(WithdrawSheet), findsNothing);
  });
}
