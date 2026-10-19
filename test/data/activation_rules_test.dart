import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/activations_data.dart';
import 'package:iqly_mobile/data/activations_service.dart';
import 'package:iqly_mobile/data/media_service.dart';
import 'package:iqly_mobile/features/activations/activation_format.dart';

final _now = DateTime(2026, 10, 2, 14, 10);
final _demo = DemoActivations(_now);

ActivationProgress _run({
  Duration started = const Duration(hours: 1),
  List<Duration> confirmed = const [],
  ActivationProof? proof,
  bool paid = false,
  List<ActivationStepPayout> payouts = const [],
}) => ActivationProgress(
  startedAt: _now.subtract(started),
  confirmedAt: [for (final ago in confirmed) _now.subtract(ago)],
  proof: proof,
  paidAt: paid ? _now : null,
  stepPayouts: payouts,
);

ActivationProof _proof(int step, {String? refused, bool checked = false}) =>
    ActivationProof(
      step: step,
      video: DemoMediaService.sample,
      receivedAt: _now.subtract(const Duration(minutes: 10)),
      checkedAt: checked ? _now : null,
      notAccepted: refused,
    );

/// Kudi Box (three steps) in [mode] with [run].
Activation _kudiBox(ConfirmationMode? mode, ActivationProgress? run) {
  final a = _demo.kudiBox;
  final moded = Activation(
    id: a.id,
    business: a.business,
    title: a.title,
    minutes: a.minutes,
    rewardKobo: a.rewardKobo,
    closesAt: a.closesAt,
    spotsLeft: a.spotsLeft,
    spotsTotal: a.spotsTotal,
    steps: a.steps,
    link: a.link,
    confirmationMode: mode,
  );
  return run == null ? moded : moded.withProgress(run);
}

void main() {
  group('without a mode (the API before 19 Oct, or the gate off)', () {
    final cases = <(String, ActivationProgress?, ActivationPhase, int?)>[
      ('offer', null, ActivationPhase.offer, null),
      ('just started', _run(), ActivationPhase.started, null),
      (
        'a day after the start, nothing confirmed',
        _run(started: const Duration(days: 2)),
        ActivationPhase.started,
        null,
      ),
      (
        'step 1 confirmed',
        _run(confirmed: [const Duration(hours: 1)]),
        ActivationPhase.confirming,
        1,
      ),
      (
        'step 2 a day unconfirmed',
        _run(confirmed: [const Duration(hours: 25)]),
        ActivationPhase.notConfirmed,
        1,
      ),
      (
        'proof checking',
        _run(confirmed: [const Duration(hours: 25)], proof: _proof(1)),
        ActivationPhase.checking,
        null,
      ),
      (
        'proof turned down',
        _run(
          confirmed: [const Duration(hours: 25)],
          proof: _proof(1, refused: 'Too short.'),
        ),
        ActivationPhase.notAccepted,
        1,
      ),
      (
        'an accepted proof for a step since confirmed still stands',
        _run(
          confirmed: [const Duration(hours: 30), const Duration(hours: 2)],
          proof: _proof(0, checked: true),
        ),
        ActivationPhase.checking,
        null,
      ),
      (
        'paid',
        _run(confirmed: [Duration.zero], paid: true),
        ActivationPhase.credited,
        null,
      ),
    ];
    for (final (name, run, phase, step) in cases) {
      test(name, () {
        final a = _kudiBox(null, run);
        expect(a.phaseAt(_now), phase);
        expect(a.proofStep, step);
      });
    }
  });

  group('proof mode (D1)', () {
    final cases = <(String, ActivationProgress?, ActivationPhase, int?)>[
      ('offer', null, ActivationPhase.offer, null),
      ('just started: step 1 to record', _run(), ActivationPhase.recording, 0),
      (
        'step 1 proof pending',
        _run(proof: _proof(0)),
        ActivationPhase.checking,
        0,
      ),
      (
        'step 1 proof turned down: record it again',
        _run(proof: _proof(0, refused: 'Too short.')),
        ActivationPhase.notAccepted,
        0,
      ),
      (
        'step 1 accepted: step 2 to record at once',
        _run(confirmed: [Duration.zero], proof: _proof(0, checked: true)),
        ActivationPhase.recording,
        1,
      ),
      (
        'step 2 proof pending',
        _run(confirmed: [const Duration(hours: 1)], proof: _proof(1)),
        ActivationPhase.checking,
        1,
      ),
      (
        'every step confirmed, the pay on its way',
        _run(
          confirmed: [Duration.zero, Duration.zero, Duration.zero],
          proof: _proof(2, checked: true),
        ),
        ActivationPhase.confirming,
        null,
      ),
      (
        'paid',
        _run(
          confirmed: [Duration.zero, Duration.zero, Duration.zero],
          proof: _proof(2, checked: true),
          paid: true,
        ),
        ActivationPhase.credited,
        null,
      ),
    ];
    for (final (name, run, phase, step) in cases) {
      test(name, () {
        final a = _kudiBox(ConfirmationMode.proof, run);
        expect(a.phaseAt(_now), phase);
        expect(a.proofStep, step);
        expect(a.waitingStep, isNull, reason: 'nothing waits on the business');
      });
    }

    test('closed before step 1 was recorded: ended', () {
      final a = _kudiBox(ConfirmationMode.proof, _run());
      expect(
        a.phaseAt(a.closesAt.add(const Duration(minutes: 1))),
        ActivationPhase.expired,
      );
    });
  });

  group('postback mode (D3)', () {
    final cases =
        <(String, ActivationProgress?, ActivationPhase, int?, Duration?)>[
          ('offer', null, ActivationPhase.offer, null, null),
          (
            'just started: step 1 waits from the start',
            _run(),
            ActivationPhase.started,
            0,
            const Duration(hours: 1),
          ),
          (
            'a day after the start, nothing confirmed: step 1 can be proven',
            _run(started: const Duration(hours: 24, minutes: 1)),
            ActivationPhase.notConfirmed,
            0,
            const Duration(hours: 24, minutes: 1),
          ),
          (
            'step 1 confirmed',
            _run(
              started: const Duration(days: 2),
              confirmed: [const Duration(hours: 1)],
            ),
            ActivationPhase.confirming,
            1,
            const Duration(hours: 1),
          ),
          (
            'step 2 a day unconfirmed',
            _run(
              started: const Duration(days: 2),
              confirmed: [const Duration(hours: 25)],
            ),
            ActivationPhase.notConfirmed,
            1,
            const Duration(hours: 25),
          ),
          (
            'a checked proof of step 2: step 3 waits on the app',
            _run(
              started: const Duration(days: 2),
              confirmed: [const Duration(hours: 25), Duration.zero],
              proof: _proof(1, checked: true),
            ),
            ActivationPhase.confirming,
            2,
            Duration.zero,
          ),
          (
            'paid',
            _run(confirmed: [Duration.zero], paid: true),
            ActivationPhase.credited,
            null,
            null,
          ),
        ];
    for (final (name, run, phase, step, since) in cases) {
      test(name, () {
        final a = _kudiBox(ConfirmationMode.postback, run);
        expect(a.phaseAt(_now), phase);
        expect(a.proofStep, step);
        expect(a.waitingSince, since == null ? null : _now.subtract(since));
      });
    }
  });

  group('paid step by step (Round 18)', () {
    final byStep = _demo.orchidFoodsByStep;

    test('each step pays its own amount; a per-run one pays the reward', () {
      expect(
        [for (var i = 0; i < 3; i++) byStep.paysFor(i)],
        [10000, 20000, 20000],
      );
      expect(_demo.orchidFoods.paysFor(0), 50000);
      expect(offerReward(byStep), 'Up to ₦500');
      expect(offerReward(_demo.orchidFoods), '₦500');
    });

    test('amounts show once more than one step pays', () {
      expect(byStep.showsStepRewards, isTrue);
      expect(_demo.orchidFoods.showsStepRewards, isFalse);
      final one = Activation(
        id: 'one',
        business: 'Unibooks',
        title: 'One paid step',
        minutes: 5,
        rewardKobo: 80000,
        closesAt: _now.add(const Duration(days: 1)),
        spotsLeft: 1,
        spotsTotal: 1,
        steps: const [
          ActivationStep(title: 'Sign up', hint: '', rewardKobo: 0),
          ActivationStep(title: 'Order', hint: '', rewardKobo: 80000),
        ],
        link: Uri(),
        rewardMode: RewardMode.perStep,
      );
      expect(one.showsStepRewards, isFalse);
    });

    test('a paid step reads Paid with what it paid', () {
      final run = byStep.withProgress(
        _run(
          confirmed: [Duration.zero],
          payouts: [ActivationStepPayout(step: 0, kobo: 10000, paidAt: _now)],
        ),
      );
      expect(stepRewardText(run, 0), 'Paid ₦100');
      expect(stepRewardText(run, 1), '₦200');
      expect(run.payoutOf(1), isNull);
    });
  });

  group('the demo service', () {
    DemoActivationsService service(List<Activation> seed) =>
        DemoActivationsService(
          seed: seed,
          clock: () => _now,
          load: Duration.zero,
          delay: Duration.zero,
          step: null,
          uploadTick: Duration.zero,
        );

    Future<Activation> prove(DemoActivationsService demo, String id) async {
      final step = demo[id].proofStep!;
      await demo.sendProof(
        id,
        step: step,
        uploadId: 'u',
        video: DemoMediaService.sample,
      );
      return demo.refresh(id);
    }

    test(
      'proof mode: each recording confirms its step; the last pays',
      () async {
        final demo = service([_demo.orchidFoods]);
        final started = await demo.start('a1');
        expect(started.phaseAt(_now), ActivationPhase.recording);
        expect(started.progress!.refCode, isNull);

        final first = await prove(demo, 'a1');
        expect(first.confirmed, 1);
        expect(first.credited, isFalse);
        expect(first.phaseAt(_now), ActivationPhase.recording);
        expect(first.proofStep, 1);

        await prove(demo, 'a1');
        final last = await prove(demo, 'a1');
        expect(last.confirmed, 3);
        expect(last.phaseAt(_now), ActivationPhase.credited);
        expect(last.progress!.stepPayouts, isEmpty, reason: 'paid per run');
        demo.dispose();
      },
    );

    test('proof mode by step: each step pays as it is confirmed', () async {
      final demo = service([_demo.orchidFoodsByStep]);
      await demo.start('a1');
      final first = await prove(demo, 'a1');
      expect(
        [for (final p in first.progress!.stepPayouts) (p.step, p.kobo)],
        [(0, 10000)],
      );
      await prove(demo, 'a1');
      final last = await prove(demo, 'a1');
      expect(
        [for (final p in last.progress!.stepPayouts) p.kobo],
        [10000, 20000, 20000],
      );
      expect(last.credited, isTrue);
      demo.dispose();
    });

    test('postback mode: the run has its code; a refreshed proof confirms '
        'its step and the app the rest', () async {
      final demo = service([_demo.kudiBox]);
      final started = await demo.start('a2');
      expect(started.progress!.refCode, DemoActivations.runCode);
      expect(started.phaseAt(_now), ActivationPhase.started);
      await demo.sendProof(
        'a2',
        step: 0,
        uploadId: 'u',
        video: DemoMediaService.sample,
      );
      final paid = await demo.refresh('a2');
      expect(paid.confirmed, 3);
      expect(paid.credited, isTrue);
      demo.dispose();
    });

    test('without a mode a checked proof pays the run, as before', () async {
      final demo = service([
        _kudiBox(null, _run(confirmed: [Duration.zero])),
      ]);
      await demo.sendProof(
        'a2',
        step: 1,
        uploadId: 'u',
        video: DemoMediaService.sample,
      );
      final paid = await demo.refresh('a2');
      expect(paid.confirmed, 1);
      expect(paid.credited, isTrue);
      demo.dispose();
    });
  });
}
