import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/money.dart';
import 'package:iqly_mobile/data/activations_data.dart';
import 'package:iqly_mobile/data/help_data.dart';
import 'package:iqly_mobile/data/help_service.dart';
import 'package:iqly_mobile/data/media_service.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/features/activations/activations_routes.dart';
import 'package:iqly_mobile/features/activations/activations_state.dart';
import 'package:iqly_mobile/features/help/help_thread_screen.dart';
import 'package:iqly_mobile/features/wallet/wallet_state.dart';
import 'package:iqly_mobile/ui/proof_tile.dart';

import '../golden/screens/activations_harness.dart';
import '../golden/screens/app_harness.dart';
import '../golden/screens/polls_notifications_help_harness.dart';

const _message =
    'My order went in yesterday but step 2 is still not confirmed.';

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _askForHelp(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Ask for help'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await _tap(tester, find.text('Ask for help'));
}

Future<void> _sendToSupport(WidgetTester tester) async {
  await tester.enterText(find.byType(EditableText).first, _message);
  await tester.pumpAndSettle();
  await _tap(tester, find.text('Send to support'));
}

/// The award rows on the wallet, by ledger id.
Map<String, int> _awards(ProviderContainer container) => {
  for (final l in container.read(walletProvider).value!.ledger)
    if (l.type == LedgerType.award && l.id.startsWith('activation-'))
      l.id: l.amountKobo,
};

String _available(ProviderContainer container) =>
    naira(container.read(walletProvider).value!.totals.withdrawableKobo);

void main() {
  testWidgets('Unibooks, stuck at step 2: its proof, its help request and '
      'support’s reply all name it, and its ₦800 counts once', (tester) async {
    final help = instantHelp();
    final container = await pumpActivations(
      tester,
      activationPath('a3'),
      now: figmaNow,
      service: instantActivations(
        now: figmaNow,
        seed: [
          DemoActivations(figmaNow).unibooks
              .withProgress(DemoActivations(figmaNow).stuckAtStep2),
        ],
        step: const Duration(seconds: 4),
      ),
      overrides: [helpServiceProvider.overrideWithValue(help)],
    );
    await _tap(tester, find.text('Upload proof of step 2'));
    await _tap(tester, find.byType(IqProofTile));
    expect(find.text('unibooks-signup.mp4'), findsOneWidget);
    await _tap(tester, find.text('Send proof'));
    expect(find.text('Not credited yet?'), findsOneWidget);
    expect(find.text('unibooks-signup.mp4'), findsOneWidget);

    await _askForHelp(tester);
    // The proof check pays Unibooks while the request is being written.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(_awards(container), {'activation-a3': 80000});

    await _sendToSupport(tester);
    expect(find.byType(HelpThreadScreen), findsOneWidget);
    final request = help.requests.single;
    expect(request.subject, 'Unibooks activation');
    expect(request.activation?.id, 'a3');
    expect(find.text('Unibooks activation'), findsOneWidget);
    expect(
      find.text(
        'Thanks, Adaeze. Both steps confirmed. ₦800.00 is in your wallet.',
      ),
      findsOneWidget,
    );
    expect(_available(container), '₦15,800.00');
    expect(_awards(container), {'activation-a3': 80000});
  });

  testWidgets('Kudi Box with its proof still checking: support credits the '
      '₦1,500, and the activation paying later adds nothing', (tester) async {
    final container = await pumpActivations(
      tester,
      activationPath('a2'),
      now: figmaNow,
      service: instantActivations(
        now: figmaNow,
        seed: Figma.world(figmaNow, kudiBox: Figma.proofSent),
      ),
      overrides: [helpServiceProvider.overrideWithValue(instantHelp())],
    );
    await _askForHelp(tester);
    await _sendToSupport(tester);
    expect(find.text('Kudi Box activation'), findsOneWidget);
    expect(
      find.text(
        'Thanks, Adaeze. All three steps confirmed. ₦1,500.00 is in your '
        'wallet.',
      ),
      findsOneWidget,
    );
    expect(_available(container), '₦16,500.00');
    expect(_awards(container), {'activation-a2': 150000});

    await container.read(activationsProvider.notifier).refresh('a2');
    await tester.pumpAndSettle();
    expect(container.read(activationProvider('a2'))!.credited, isTrue);
    expect(_awards(container), {'activation-a2': 150000});
    expect(_available(container), '₦16,500.00');
  });

  group('the demo support', () {
    final demo = DemoActivations(figmaNow);
    final started = ActivationProgress(startedAt: figmaNow);

    Future<HelpTicket> answer(Activation? about) async {
      final service = DemoHelpService(
        delay: Duration.zero,
        typingAfter: Duration.zero,
        replyAfter: Duration.zero,
        clock: () => figmaNow,
      );
      final ticket = await service.send(
        HelpRequest(subject: 'Help', message: 'Help', activation: about),
      );
      return (await service.watch(ticket.id).toList()).last;
    }

    test('answers about the activation, with its steps and its reward', () {
      expect(
        answer(demo.orchidFoods.withProgress(started)),
        completion(
          isA<HelpTicket>()
              .having((t) => t.credit?.amountKobo, 'credit', 50000)
              .having((t) => t.credit?.id, 'row', 'activation-a1')
              .having(
                (t) => t.messages.last.body,
                'reply',
                'Thanks, Adaeze. All three steps confirmed. ₦500.00 is in '
                    'your wallet.',
              ),
        ),
      );
    });

    test('credits nothing when the reward was paid already', () async {
      final paid = await answer(
        demo.unibooks.withProgress(
          ActivationProgress(
            startedAt: figmaNow,
            confirmedAt: [figmaNow, figmaNow],
            paidAt: figmaNow,
          ),
        ),
      );
      expect(paid.credit, isNull);
      expect(paid.answered, isTrue);
      expect(
        paid.messages.last.body,
        'Thanks, Adaeze. Both steps confirmed. ₦800.00 is in your wallet.',
      );
    });

    test(
      'never answers for an activation that was not started, or none',
      () async {
        for (final about in [demo.kudiBox, null]) {
          final ticket = await answer(about);
          expect(ticket.answered, isFalse);
          expect(ticket.credit, isNull);
          expect(ticket.supportTyping, isFalse);
        }
      },
    );

    test('a recording picked for an activation is named for it', () async {
      final media = DemoMediaService(delay: Duration.zero);
      expect((await media.pickVideo())?.name, 'kudi-box-signup.mp4');
      expect(
        (await media.pickVideo(about: 'Unibooks'))?.name,
        'unibooks-signup.mp4',
      );
      final service = DemoHelpService(uploadStep: Duration.zero);
      expect(
        (await service.addRecording(about: 'Unibooks').last).file.name,
        'unibooks-wallet.mp4',
      );
      expect(
        (await service.addRecording(about: 'Kudi Box').last).file.name,
        DemoHelp.recording.name,
      );
    });
  });
}
