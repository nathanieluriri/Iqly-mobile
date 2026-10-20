import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/activations_data.dart';
import 'package:iqly_mobile/data/activations_service.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/media_service.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/features/activations/activations_routes.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/proof_tile.dart';

import '../golden.dart';
import 'activations_harness.dart';
import 'app_harness.dart' show figmaNow;

Future<void> _golden(
  WidgetTester tester,
  String name,
  String location, {
  required DateTime now,
  DemoActivationsService? service,
  DemoMediaService? media,
  IqlyRepository? repository,
  Future<void> Function(WidgetTester tester)? act,
  bool supportChannels = false,
}) async {
  await pumpActivations(
    tester,
    location,
    now: now,
    service: service,
    media: media,
    repository: repository,
    supportChannels: supportChannels,
  );
  await precacheImages(tester);
  if (act != null) {
    await act(tester);
    await tester.pumpAndSettle();
  }
  await expectMatchesGolden(find.byType(MaterialApp), 'goldens/$name.png');
}

Future<void> _pickRecording(WidgetTester tester) async {
  await tester.tap(find.byType(IqProofTile));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  final thursday = Figma.thursday;
  final friday = Figma.friday;

  DemoActivationsService underWay(DateTime now) => instantActivations(
    now: now,
    seed: Figma.world(
      now,
      kudiBox: Figma.step1,
      orchidFoods: Figma.orchidStarted,
    ),
  );

  group('B8 activations', () {
    testWidgets('activations (141:4597, 161:16268)', (tester) async {
      await _golden(
        tester,
        'activations_list',
        Routes.activations,
        now: thursday,
        service: underWay(thursday),
      );
    });

    testWidgets('loading (165:7704)', (tester) async {
      await pumpActivations(
        tester,
        Routes.activations,
        now: thursday,
        service: HangingActivations(now: thursday),
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await expectMatchesGolden(
        find.byType(MaterialApp),
        'goldens/activations_loading.png',
      );
    });

    testWidgets('empty (165:7855)', (tester) async {
      await _golden(
        tester,
        'activations_empty',
        Routes.activations,
        now: thursday,
        service: instantActivations(now: thursday, seed: const []),
      );
    });

    testWidgets('failed to load (165:8008)', (tester) async {
      await _golden(
        tester,
        'activations_failed',
        Routes.activations,
        now: thursday,
        service: instantActivations(now: thursday, loadFailures: 1),
      );
    });

    testWidgets('my activations, Active (485:38281)', (tester) async {
      await _golden(
        tester,
        'activations_mine',
        myActivationsPath,
        now: thursday,
        service: underWay(thursday),
      );
    });

    testWidgets('my activations, Done (no frame)', (tester) async {
      await _golden(
        tester,
        'activations_mine_done',
        myActivationsPath,
        now: thursday,
        service: instantActivations(
          now: thursday,
          seed: [
            ...Figma.world(thursday, kudiBox: Figma.step1).take(2),
            DemoActivations(thursday).unibooks.withProgress(
              ActivationProgress(
                startedAt: Figma.startedAt,
                confirmedAt: [Figma.step1At, Figma.step1At],
                paidAt: Figma.step1At,
              ),
            ),
          ],
        ),
        act: (tester) => tester.tap(find.text('Done')),
      );
    });

    testWidgets('activation detail (141:4941, 161:16280)', (tester) async {
      await _golden(
        tester,
        'activations_detail',
        activationPath('a2'),
        now: thursday,
      );
    });

    testWidgets('expired (485:38428)', (tester) async {
      final ended = DemoActivations(thursday).kudiBox.closesAt
          .add(const Duration(days: 2));
      await _golden(
        tester,
        'activations_expired',
        activationPath('a2'),
        now: ended,
        service: instantActivations(now: ended, seed: Figma.world(thursday)),
      );
    });

    testWidgets('just started (179:8001)', (tester) async {
      await _golden(
        tester,
        'activations_just_started',
        activationPath('a2'),
        now: thursday,
        service: instantActivations(
          now: thursday,
          seed: Figma.world(thursday, kudiBox: Figma.started),
        ),
      );
    });

    testWidgets('in progress (141:5090)', (tester) async {
      await _golden(
        tester,
        'activations_in_progress',
        activationPath('a2'),
        now: thursday,
        service: instantActivations(
          now: thursday,
          seed: Figma.world(thursday, kudiBox: Figma.step1),
        ),
      );
    });

    testWidgets('reward credited, steps confirmed (154:6312)', (tester) async {
      await _golden(
        tester,
        'activations_credited',
        activationPath('a2'),
        now: thursday,
        service: instantActivations(
          now: thursday,
          seed: Figma.world(thursday, kudiBox: Figma.paid),
        ),
        repository: CreditedRepository(credits: [kudiBoxCredit(Figma.paidAt)]),
      );
    });
  });

  group('B9 proof', () {
    DemoActivationsService stuck({int uploadFailures = 0}) =>
        instantActivations(
          now: friday,
          seed: Figma.world(friday, kudiBox: Figma.step1),
          uploadFailures: uploadFailures,
        );

    testWidgets('step not confirmed (154:6202)', (tester) async {
      await _golden(
        tester,
        'activations_step_not_confirmed',
        activationPath('a2'),
        now: friday,
        service: stuck(),
      );
    });

    testWidgets('proof empty (141:5210)', (tester) async {
      await _golden(
        tester,
        'activations_proof_empty',
        proofPath('a2'),
        now: friday,
        service: stuck(),
      );
    });

    testWidgets('photo permission (485:38820)', (tester) async {
      await _golden(
        tester,
        'activations_proof_permission',
        proofPath('a2'),
        now: friday,
        service: stuck(),
        media: DemoMediaService(delay: Duration.zero),
        act: (tester) async {
          await tester.tap(find.byType(IqProofTile));
          await tester.pump(const Duration(milliseconds: 400));
        },
      );
    });

    testWidgets('proof ready (141:5372)', (tester) async {
      await _golden(
        tester,
        'activations_proof_ready',
        proofPath('a2'),
        now: friday,
        service: stuck(),
        act: _pickRecording,
      );
    });

    testWidgets('remove recording? (141:5492)', (tester) async {
      await _golden(
        tester,
        'activations_proof_remove',
        proofPath('a2'),
        now: friday,
        service: stuck(),
        act: (tester) async {
          await _pickRecording(tester);
          await tester.tap(find.bySemanticsLabel('Remove'));
          await tester.pump(const Duration(milliseconds: 400));
        },
      );
    });

    testWidgets('upload failed (485:38534)', (tester) async {
      await _golden(
        tester,
        'activations_proof_upload_failed',
        proofPath('a2'),
        now: friday,
        service: stuck(uploadFailures: 1),
        act: _pickRecording,
      );
    });

    testWidgets('video too long (485:38622)', (tester) async {
      await _golden(
        tester,
        'activations_proof_too_long',
        proofPath('a2'),
        now: friday,
        service: stuck(),
        media: DemoMediaService(
          delay: Duration.zero,
          access: MediaAccess.allowed,
          video: DemoMediaService.tooLong,
        ),
        act: _pickRecording,
      );
    });

    testWidgets('proof submitted (141:5549)', (tester) async {
      await _golden(
        tester,
        'activations_proof_submitted',
        activationPath('a2'),
        now: friday,
        service: instantActivations(
          now: friday,
          seed: Figma.world(friday, kudiBox: Figma.proofSent),
        ),
      );
    });

    testWidgets('proof not accepted (485:38715)', (tester) async {
      await _golden(
        tester,
        'activations_proof_not_accepted',
        activationPath('a2'),
        now: friday,
        service: instantActivations(
          now: friday,
          seed: Figma.world(friday, kudiBox: Figma.proofRefused),
        ),
      );
    });

    testWidgets('reward credited, proof checked (141:5693)', (tester) async {
      await _golden(
        tester,
        'activations_credited_proof',
        activationPath('a2'),
        now: Figma.saturday,
        service: instantActivations(
          now: Figma.saturday,
          seed: Figma.world(Figma.saturday, kudiBox: Figma.proofPaid),
        ),
        repository: CreditedRepository(
          credits: [kudiBoxCredit(Figma.proofPaidAt)],
        ),
      );
    });
  });

  group('the rules of 19 Oct', () {
    List<Activation> byStep(DateTime now, ActivationProgress? run) {
      final demo = DemoActivations(now);
      return [
        run == null
            ? demo.orchidFoodsByStep
            : demo.orchidFoodsByStep.withProgress(run),
        demo.kudiBox,
        demo.unibooks,
      ];
    }

    testWidgets('proof mode, just started: record step 1 now', (tester) async {
      await _golden(
        tester,
        'activations_proof_mode_started',
        activationPath('a1'),
        now: thursday,
        service: instantActivations(
          now: thursday,
          seed: Figma.world(thursday, orchidFoods: Figma.orchidStarted),
        ),
      );
    });

    testWidgets('paid step by step: the offer reads Up to', (tester) async {
      await _golden(
        tester,
        'activations_detail_per_step',
        activationPath('a1'),
        now: thursday,
        service: instantActivations(
          now: thursday,
          seed: byStep(thursday, null),
        ),
      );
    });

    testWidgets('paid step by step: step 1 paid, step 2 to record', (
      tester,
    ) async {
      await _golden(
        tester,
        'activations_per_step_next',
        activationPath('a1'),
        now: thursday,
        service: instantActivations(
          now: thursday,
          seed: byStep(thursday, Figma.orchidStep1Paid()),
        ),
      );
    });

    testWidgets('paid step by step: Upload proof promises the step', (
      tester,
    ) async {
      await _golden(
        tester,
        'activations_per_step_proof',
        proofPath('a1'),
        now: thursday,
        service: instantActivations(
          now: thursday,
          seed: byStep(thursday, Figma.orchidStep1Paid()),
        ),
      );
    });

    testWidgets('paid step by step: Your proof pays the step', (tester) async {
      await _golden(
        tester,
        'activations_per_step_checking',
        activationPath('a1'),
        now: thursday,
        service: instantActivations(
          now: thursday,
          seed: byStep(thursday, Figma.orchidStep1Paid(proof: true)),
        ),
      );
    });

    testWidgets('Not credited yet? asks the business in a chat (141:5549, '
        'supportChannels)', (tester) async {
      await _golden(
        tester,
        'activations_proof_help_channels',
        activationPath('a1'),
        now: thursday,
        supportChannels: true,
        service: instantActivations(
          now: thursday,
          seed: byStep(thursday, Figma.orchidStep1Paid(proof: true)),
        ),
      );
    });

    testWidgets('postback mode: the run’s code with Copy', (tester) async {
      await _golden(
        tester,
        'activations_run_code',
        activationPath('a2'),
        now: thursday,
        service: instantActivations(
          now: thursday,
          seed: Figma.world(thursday, kudiBox: Figma.step1WithCode),
        ),
      );
    });

    testWidgets('postback mode: step 1 a day unconfirmed can be proven', (
      tester,
    ) async {
      await _golden(
        tester,
        'activations_first_step_not_confirmed',
        activationPath('a2'),
        now: friday,
        service: instantActivations(
          now: friday,
          seed: Figma.world(friday, kudiBox: Figma.started),
        ),
      );
    });

    testWidgets('postback mode: a step the business holds is not to prove', (
      tester,
    ) async {
      await _golden(
        tester,
        'activations_held_step',
        activationPath('a2'),
        now: friday,
        service: instantActivations(
          now: friday,
          seed: Figma.world(friday, kudiBox: Figma.step1Held),
        ),
      );
    });
  });

  test('the Discover row counts what the list shows closing today', () {
    final open = DemoActivations(figmaNow).all;
    final today = open.where(
      (a) => a.closesAt.difference(figmaNow) < ActivationRules.closingSoon,
    );
    expect(today.length, DemoData.activations.closingToday);
  });
}
