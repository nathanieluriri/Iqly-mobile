import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/activations_data.dart';
import 'package:iqly_mobile/data/activations_service.dart';
import 'package:iqly_mobile/data/media_service.dart';
import 'package:iqly_mobile/features/activations/activation_format.dart';
import 'package:iqly_mobile/features/activations/activations_routes.dart';

import '../golden/screens/activations_harness.dart';
import '../golden/screens/app_harness.dart';

final _now = DateTime(2026, 11, 26, 12);

Activation _legacy({
  List<ActivationStepPayout> payouts = const [],
  List<ActivationStep>? steps,
}) => Activation(
  id: 'legacy',
  business: 'Kudi Box',
  title: 'Legacy per-step activation',
  minutes: 10,
  rewardKobo: 150000,
  closesAt: _now.add(const Duration(days: 1)),
  spotsLeft: 2,
  spotsTotal: 2,
  steps:
      steps ??
      const [
        ActivationStep(title: 'Open', hint: 'Open the app', rewardKobo: 50000),
        ActivationStep(title: 'Save', hint: 'Save money', rewardKobo: 100000),
      ],
  link: Uri.parse('https://example.com/join'),
  confirmationMode: ConfirmationMode.proof,
  rewardMode: RewardMode.perStep,
  progress: ActivationProgress(
    startedAt: _now.subtract(const Duration(hours: 1)),
    confirmedAt: [_now.subtract(const Duration(minutes: 10))],
    stepPayouts: payouts,
  ),
);

class _CountingActivations extends DemoActivationsService {
  _CountingActivations(Activation activation)
    : super(
        seed: [activation],
        clock: () => _now,
        load: Duration.zero,
        delay: Duration.zero,
        step: null,
        uploadTick: Duration.zero,
      );

  int starts = 0;

  @override
  Future<Activation> start(String id) {
    starts++;
    return super.start(id);
  }
}

void main() {
  test('final legacy step promises only the unpaid allocation', () {
    final activation = _legacy(
      payouts: [ActivationStepPayout(step: 0, kobo: 50000, paidAt: _now)],
    );
    expect(activation.paysFor(0), 0);
    expect(activation.paysFor(1), 100000);
  });

  test('no historical payout promises every allocation on the final step', () {
    final activation = _legacy();
    expect(activation.paysFor(0), 0);
    expect(activation.paysFor(1), 150000);
  });

  test(
    'already paid allocations are excluded using zero-based API indices',
    () {
      final activation = _legacy(
        payouts: [
          ActivationStepPayout(step: 0, kobo: 50000, paidAt: _now),
          ActivationStepPayout(step: 1, kobo: 100000, paidAt: _now),
        ],
      );
      expect(activation.paysFor(1), 0);
    },
  );

  test('payout history belongs to one run only', () {
    final paid = _legacy(
      payouts: [ActivationStepPayout(step: 0, kobo: 50000, paidAt: _now)],
    );
    final unpaid = _legacy();
    expect(paid.paysFor(1), 100000);
    expect(unpaid.paysFor(1), 150000);
  });

  test('per-run payment keeps the whole reward on the final step', () {
    final legacy = _legacy(
      payouts: [ActivationStepPayout(step: 0, kobo: 50000, paidAt: _now)],
    );
    final perRun = Activation(
      id: legacy.id,
      business: legacy.business,
      title: legacy.title,
      minutes: legacy.minutes,
      rewardKobo: legacy.rewardKobo,
      closesAt: legacy.closesAt,
      spotsLeft: legacy.spotsLeft,
      spotsTotal: legacy.spotsTotal,
      steps: legacy.steps,
      link: legacy.link,
      confirmationMode: ConfirmationMode.proof,
      progress: legacy.progress,
    );
    expect(perRun.paysFor(0), 0);
    expect(perRun.paysFor(1), 150000);
  });

  testWidgets('proof copy promises the unpaid final-step remainder', (
    tester,
  ) async {
    final activation = _legacy(
      payouts: [ActivationStepPayout(step: 0, kobo: 50000, paidAt: _now)],
    );
    await pumpActivations(
      tester,
      proofPath(activation.id),
      now: _now,
      service: _CountingActivations(activation),
    );
    expect(find.textContaining('then we pay ₦1,000.'), findsOneWidget);
    expect(find.textContaining('then we pay ₦1,500.'), findsNothing);
  });

  for (final size in [const Size(390, 844), const Size(1024, 768)]) {
    testWidgets('dated-full detail explains Full at $size without starting', (
      tester,
    ) async {
      final activation = _legacy();
      final full = Activation(
        id: activation.id,
        business: activation.business,
        title: activation.title,
        minutes: activation.minutes,
        rewardKobo: activation.rewardKobo,
        closesAt: activation.closesAt,
        spotsLeft: 0,
        spotsTotal: activation.spotsTotal,
        steps: activation.steps,
        link: activation.link,
        confirmationMode: activation.confirmationMode,
        rewardMode: activation.rewardMode,
      );
      final service = _CountingActivations(full);
      await pumpApp(
        tester,
        activationPath(full.id),
        clock: () => _now,
        size: size,
        tabletFrame: size.width >= 600,
        overrides: [activationsServiceProvider.overrideWithValue(service)],
      );
      expect(full.availableAt(_now), isTrue);
      expect(find.text('Full'), findsWidgets);
      expect(find.text('No spots left'), findsOneWidget);
      expect(find.text('Start activation'), findsNothing);
      await tester.tap(find.text('Full').last);
      await tester.pump();
      expect(service.starts, 0);
    });
  }

  test('detail step copy shows the whole unpaid final remainder', () {
    final activation = _legacy(
      steps: const [
        ActivationStep(title: 'Open', hint: '', rewardKobo: 50000),
        ActivationStep(title: 'Save', hint: '', rewardKobo: 30000),
        ActivationStep(title: 'Finish', hint: '', rewardKobo: 70000),
      ],
      payouts: [ActivationStepPayout(step: 0, kobo: 50000, paidAt: _now)],
    );
    expect(stepRewardText(activation, 0), 'Paid ₦500');
    expect(stepRewardText(activation, 1), '₦300');
    expect(stepRewardText(activation, 2), '₦1,000');
  });

  test(
    'demo final payment records each unpaid legacy allocation once',
    () async {
      final legacy = _legacy();
      final activation = Activation(
        id: legacy.id,
        business: legacy.business,
        title: legacy.title,
        minutes: legacy.minutes,
        rewardKobo: 150000,
        closesAt: legacy.closesAt,
        spotsLeft: legacy.spotsLeft,
        spotsTotal: legacy.spotsTotal,
        steps: const [
          ActivationStep(title: 'Open', hint: '', rewardKobo: 50000),
          ActivationStep(title: 'Save', hint: '', rewardKobo: 30000),
          ActivationStep(title: 'Finish', hint: '', rewardKobo: 70000),
        ],
        link: legacy.link,
        confirmationMode: ConfirmationMode.proof,
        rewardMode: RewardMode.perStep,
        progress: ActivationProgress(
          startedAt: _now.subtract(const Duration(hours: 1)),
          confirmedAt: [
            _now.subtract(const Duration(minutes: 20)),
            _now.subtract(const Duration(minutes: 10)),
          ],
          stepPayouts: [
            ActivationStepPayout(step: 0, kobo: 50000, paidAt: _now),
          ],
        ),
      );
      final service = _CountingActivations(activation);
      await service.start(activation.id);
      await service.sendProof(
        activation.id,
        step: 2,
        uploadId: 'proof',
        video: DemoMediaService.sample,
      );
      final paid = await service.refresh(activation.id);
      expect(
        [
          for (final payout in paid.progress!.stepPayouts)
            (payout.step, payout.kobo),
        ],
        [(0, 50000), (1, 30000), (2, 70000)],
      );
      expect(earnedLine(paid), '₦1,500 paid');
      service.dispose();
    },
  );

  test('paid timeline totals historical credits without promising another', () {
    final activation = _legacy(
      payouts: [
        ActivationStepPayout(step: 0, kobo: 50000, paidAt: _now),
        ActivationStepPayout(step: 1, kobo: 100000, paidAt: _now),
      ],
    );
    final paid = activation.withProgress(
      activation.progress!.copyWith(
        confirmedAt: [
          _now.subtract(const Duration(minutes: 10)),
          _now.subtract(const Duration(minutes: 5)),
        ],
        paidAt: _now,
      ),
    );
    expect(paid.paysFor(1), 0);
    expect(earnedLine(paid), '₦1,500 paid');
  });
}
