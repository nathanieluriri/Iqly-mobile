import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/deadline.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/activations_data.dart';
import 'package:iqly_mobile/data/activations_service.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/device.dart';
import 'package:iqly_mobile/data/media_service.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_harness.dart';

/// The Figma timeline. B8: Kudi Box starts on Thursday, its first step is
/// confirmed at 1:52 pm, the rest at 2:10 pm, paid at 2:11 pm. B9: on
/// Friday afternoon step 2 is a day unconfirmed; proof goes in at 2:14 pm,
/// is confirmed Saturday 3:05 pm and paid at 3:06 pm.
abstract final class Figma {
  static final startedAt = DateTime(2026, 10, 1, 13, 40);
  static final step1At = DateTime(2026, 10, 1, 13, 52);
  static final stepsAt = DateTime(2026, 10, 1, 14, 10);
  static final paidAt = DateTime(2026, 10, 1, 14, 11);
  static final proofAt = DateTime(2026, 10, 2, 14, 14);
  static final checkedAt = DateTime(2026, 10, 3, 15, 5);
  static final proofPaidAt = DateTime(2026, 10, 3, 15, 6);

  /// Thursday, a few minutes after the first confirmation.
  static final thursday = DateTime(2026, 10, 1, 13, 55);

  /// Friday, 24 h 18 min after it.
  static final friday = DateTime(2026, 10, 2, 14, 10);

  /// Saturday, after the proof was paid.
  static final saturday = DateTime(2026, 10, 3, 15, 10);

  static ActivationProgress get started =>
      ActivationProgress(startedAt: startedAt);

  static ActivationProgress get step1 =>
      ActivationProgress(startedAt: startedAt, confirmedAt: [step1At]);

  static ActivationProgress get paid => ActivationProgress(
    startedAt: startedAt,
    confirmedAt: [step1At, stepsAt, stepsAt],
    paidAt: paidAt,
  );

  static ActivationProgress get proofSent => ActivationProgress(
    startedAt: startedAt,
    confirmedAt: [step1At],
    proof: ActivationProof(
      step: 1,
      video: DemoMediaService.sample,
      receivedAt: proofAt,
    ),
  );

  static ActivationProgress get proofPaid => ActivationProgress(
    startedAt: startedAt,
    confirmedAt: [step1At],
    proof: ActivationProof(
      step: 1,
      video: DemoMediaService.sample,
      receivedAt: proofAt,
      checkedAt: checkedAt,
    ),
    paidAt: proofPaidAt,
  );

  /// Orchid Foods started on Thursday morning, nothing confirmed yet.
  static ActivationProgress get orchidStarted =>
      ActivationProgress(startedAt: DateTime(2026, 10, 1, 9, 30));

  /// The proof Kudi Box turned down (B9 · Proof · not accepted).
  static ActivationProgress get proofRefused => ActivationProgress(
    startedAt: startedAt,
    confirmedAt: [step1At],
    proof: ActivationProof(
      step: 1,
      video: DemoMediaService.sample,
      receivedAt: proofAt,
      notAccepted: DemoActivations.endsEarly,
    ),
  );

  /// The three activations at [now], Kudi Box with [kudiBox] progress and
  /// Orchid Foods with [orchidFoods].
  static List<Activation> world(
    DateTime now, {
    ActivationProgress? kudiBox,
    ActivationProgress? orchidFoods,
  }) {
    final demo = DemoActivations(now);
    return [
      orchidFoods == null
          ? demo.orchidFoods
          : demo.orchidFoods.withProgress(orchidFoods),
      kudiBox == null ? demo.kudiBox : demo.kudiBox.withProgress(kudiBox),
      demo.unibooks,
    ];
  }
}

/// The activations service answering at once at [now]; nothing changes on
/// its own unless [step] is set.
DemoActivationsService instantActivations({
  required DateTime now,
  List<Activation>? seed,
  Duration? step,
  int loadFailures = 0,
  int startFailures = 0,
  int uploadFailures = 0,
  int sendFailures = 0,
}) => DemoActivationsService(
  seed: seed ?? Figma.world(now),
  clock: () => now,
  load: Duration.zero,
  delay: Duration.zero,
  step: step,
  uploadTick: Duration.zero,
  loadFailures: loadFailures,
  startFailures: startFailures,
  uploadFailures: uploadFailures,
  sendFailures: sendFailures,
);

/// The list never arrives.
class HangingActivations extends DemoActivationsService {
  HangingActivations({required DateTime now})
    : super(seed: Figma.world(now), clock: () => now, load: Duration.zero);

  final _never = Completer<List<Activation>>();

  @override
  Future<List<Activation>> activations() => _never.future;
}

/// The demo wallet at the Figma 9:41 with [credits] already on the ledger,
/// as the live API returns it once a reward is paid.
class CreditedRepository extends DemoRepository {
  CreditedRepository({this.credits = const []})
    : super(DemoData(now: figmaNow));

  final List<LedgerEntry> credits;

  @override
  Future<List<LedgerEntry>> ledger() async => [
    ...credits,
    ...await super.ledger(),
  ];
}

LedgerEntry kudiBoxCredit(DateTime at) => LedgerEntry(
  id: 'activation-a2',
  type: LedgerType.award,
  amountKobo: 150000,
  createdAt: at,
);

/// The real router at [location] on a 390 x 844 phone with the OS insets,
/// reduced motion unless [reducedMotion] is false, the clock at [now] (or
/// [clock], to move it) and the activations, media and device services
/// answering at once. [settle] false pumps one frame, for screens whose
/// loops never settle.
Future<ProviderContainer> pumpActivations(
  WidgetTester tester,
  String location, {
  required DateTime now,
  DemoActivationsService? service,
  DemoMediaService? media,
  DemoDeviceService? device,
  IqlyRepository? repository,
  DateTime Function()? clock,
  bool reducedMotion = true,
  bool settle = true,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 54, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 54, bottom: 34);
  if (reducedMotion) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(signedInPrefs());
  final shared = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(shared),
      repositoryProvider.overrideWithValue(repository ?? CreditedRepository()),
      clockProvider.overrideWithValue(clock ?? () => now),
      activationsServiceProvider.overrideWithValue(
        service ?? instantActivations(now: now),
      ),
      mediaServiceProvider.overrideWithValue(
        media ??
            DemoMediaService(delay: Duration.zero, access: MediaAccess.allowed),
      ),
      deviceServiceProvider.overrideWithValue(
        device ?? DemoDeviceService(delay: Duration.zero),
      ),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  final router = buildRouter(initialLocation: location);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: buildTheme(),
        debugShowCheckedModeBanner: false,
        routerConfig: router,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return container;
}
