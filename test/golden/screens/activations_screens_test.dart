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
}) async {
  await pumpActivations(
    tester,
    location,
    now: now,
    service: service,
    media: media,
    repository: repository,
  );
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

  group('B8 activations', () {
    testWidgets('activations (141:4597, 161:16268)', (tester) async {
      await _golden(
        tester,
        'activations_list',
        Routes.activations,
        now: thursday,
      );
    });

    testWidgets('activations, scrolled: Kudi Box under way', (tester) async {
      await _golden(
        tester,
        'activations_list_mine',
        Routes.activations,
        now: thursday,
        service: instantActivations(
          now: thursday,
          seed: Figma.world(thursday, kudiBox: Figma.step1),
        ),
        act: (tester) =>
            tester.drag(find.byType(ListView), const Offset(0, -400)),
      );
    });

    testWidgets('loading (165:7704)', (tester) async {
      await _golden(
        tester,
        'activations_loading',
        Routes.activations,
        now: thursday,
        service: HangingActivations(now: thursday),
        act: (tester) => tester.pump(const Duration(milliseconds: 400)),
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

    testWidgets('activation detail (141:4941, 161:16280)', (tester) async {
      await _golden(
        tester,
        'activations_detail',
        activationPath('a2'),
        now: thursday,
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
    DemoActivationsService stuck() => instantActivations(
      now: friday,
      seed: Figma.world(friday, kudiBox: Figma.step1),
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

    testWidgets('a recording over 60 s (kit ProofTile Error)', (tester) async {
      await _golden(
        tester,
        'activations_proof_too_long',
        proofPath('a2'),
        now: friday,
        service: stuck(),
        media: DemoMediaService(
          delay: Duration.zero,
          video: const ProofVideo(
            name: 'kudi-box-signup.mp4',
            bytes: 31000000,
            length: Duration(seconds: 74),
          ),
        ),
        act: _pickRecording,
      );
    });
  });

  test('the Discover row counts what the list shows closing today', () {
    final open = DemoActivations(figmaNow).all;
    final today = open.where(
      (a) => a.closesAt.difference(figmaNow) < const Duration(days: 1),
    );
    expect(today.length, DemoData.activations.closingToday);
  });
}
