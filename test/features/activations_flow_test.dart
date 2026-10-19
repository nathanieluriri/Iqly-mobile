import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iqly_mobile/core/deadline.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/core/transitions.dart';
import 'package:iqly_mobile/data/activations_data.dart';
import 'package:iqly_mobile/data/activations_service.dart';
import 'package:iqly_mobile/data/media_service.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/features/activations/activation_screen.dart';
import 'package:iqly_mobile/features/activations/activations_routes.dart';
import 'package:iqly_mobile/features/activations/activations_screen.dart';
import 'package:iqly_mobile/features/activations/activations_state.dart';
import 'package:iqly_mobile/features/activations/activations_widgets.dart';
import 'package:iqly_mobile/features/activations/my_activations_screen.dart';
import 'package:iqly_mobile/features/activations/proof_player_screen.dart';
import 'package:iqly_mobile/features/activations/proof_screen.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/help/help_request_screen.dart';
import 'package:iqly_mobile/features/wallet/wallet_screen.dart';
import 'package:iqly_mobile/features/wallet/wallet_state.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/banner.dart';
import 'package:iqly_mobile/ui/button.dart';
import 'package:iqly_mobile/ui/pressable.dart';
import 'package:iqly_mobile/ui/proof_tile.dart';
import 'package:iqly_mobile/ui/video_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../golden/golden.dart' show loadAppFonts;
import '../golden/screens/activations_harness.dart';
import '../golden/screens/app_harness.dart' show signedInPrefs;
import 'entry_harness.dart' show recordHaptics;

const _light = 'HapticFeedbackType.lightImpact';
const _success = 'HapticFeedbackType.successNotification';
const _commit = 'HapticFeedbackType.heavyImpact';
const _error = 'HapticFeedbackType.heavyImpact';

/// Taps [finder], scrolling the screen's list to it first when it waits in
/// the list's cache area, where finders count it offstage.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// The IqPressable a screen reader announces as [label].
Finder _button(String label) =>
    find.byWidgetPredicate((w) => w is IqPressable && w.semanticLabel == label);

IqButton _iqButton(WidgetTester tester, String label) =>
    tester.widget<IqButton>(
      find.byWidgetPredicate((w) => w is IqButton && w.label == label),
    );

/// The activation rewards on the wallet, by ledger id.
Map<String, int> _awards(ProviderContainer container) => {
  for (final l in container.read(walletProvider).value!.ledger)
    if (l.type == LedgerType.award && l.id.startsWith('activation-'))
      l.id: l.amountKobo,
};

/// A service at [now] that confirms on the prototype's 4 s beats.
DemoActivationsService _live(DateTime now, {List<Activation>? seed}) =>
    DemoActivationsService(
      seed: seed ?? Figma.world(now),
      clock: () => now,
      load: const Duration(milliseconds: 1200),
      delay: Duration.zero,
      uploadTick: Duration.zero,
    );

const _kudiBox = 'Open a Kudi Box account and save ₦1,000.00';

void main() {
  setUpAll(loadAppFonts);

  final thursday = Figma.thursday;
  final friday = Figma.friday;

  DemoActivationsService stuck({
    int uploadFailures = 0,
    int sendFailures = 0,
    int refusals = 0,
    Duration? step,
  }) => instantActivations(
    now: friday,
    seed: Figma.world(friday, kudiBox: Figma.step1),
    uploadFailures: uploadFailures,
    sendFailures: sendFailures,
    step: step,
  )..refusals = refusals;

  testWidgets(
    'B8: Discover, loading, Activations, detail, started, confirmed, paid, '
    'wallet',
    (tester) async {
      final haptics = recordHaptics(tester);
      final container = await pumpActivations(
        tester,
        Routes.home,
        now: thursday,
        service: _live(thursday),
      );
      expect(find.byType(HomeScreen), findsOneWidget);
      // Discover waits for its Activations block, then opens the list with
      // what it loaded.
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();
      expect(find.text('Activations'), findsOneWidget);
      expect(find.text('Closes in 5h 40m'), findsOneWidget);

      await tester.tap(find.text('Rate 3 recipes in the Orchid Foods app'));
      await tester.pumpAndSettle();
      expect(find.byType(ActivationsScreen), findsOneWidget);
      expect(find.byType(ActivationsLoading), findsNothing);
      expect(find.text('Rate 3 recipes in the Orchid Foods app'), findsOne);
      expect(find.text('Closes in 5h 40m'), findsOneWidget);
      expect(find.text('₦500'), findsOneWidget);
      expect(find.text('₦1.5k'), findsOneWidget);
      expect(find.text('₦800'), findsOneWidget);
      expect(find.text('My activations'), findsNothing);

      await _tap(tester, find.text(_kudiBox));
      expect(find.byType(ActivationScreen), findsOneWidget);
      expect(find.text('Activation'), findsNWidgets(2));
      expect(
        find.text(
          'Paid to your iQLY wallet once Kudi Box confirms, usually within '
          '24 hours.',
        ),
        findsOneWidget,
      );
      expect(find.text('Closes in 2 days'), findsOneWidget);
      expect(find.text('Settings → Verification. About 2 min'), findsOne);
      const opened = [_light, _light];
      expect(haptics, opened);

      await _tap(tester, find.text('Start activation'));
      expect(haptics, [...opened, _commit]);
      expect(find.text('Not started · 3 steps'), findsOneWidget);
      expect(find.text('Settings → Verification'), findsOneWidget);
      expect(find.text('Earn ₦1,500'), findsOneWidget);
      expect(find.text('when all 3 steps are confirmed'), findsOneWidget);
      expect(find.text('Open Kudi Box'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('Step 1 of 3 confirmed'), findsOneWidget);
      expect(find.text('Confirmed by Kudi Box · Thu, 1:55 pm'), findsOneWidget);
      expect(
        find.text('Kudi Box is checking. Usually a few minutes.'),
        findsOneWidget,
      );
      expect(haptics, [
        ...opened,
        _commit,
      ], reason: 'a confirmation is passive');

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('Your reward'), findsOneWidget);
      expect(find.text('₦1,500.00 is yours'), findsOneWidget);
      expect(
        find.text("Kudi Box confirmed all 3 steps. It's in your wallet."),
        findsOneWidget,
      );
      expect(find.text('Steps confirmed by Kudi Box'), findsOneWidget);
      expect(find.text('Thu, 1:55 pm · 3 of 3 steps'), findsOneWidget);
      expect(haptics, [...opened, _commit, _success]);
      expect(_awards(container), {'activation-a2': 150000});

      await _tap(tester, find.text('View wallet'));
      expect(find.byType(WalletScreen), findsOneWidget);
    },
  );

  testWidgets('B8: My activations lists both under way; Done holds the paid '
      'one; back returns to the opener', (tester) async {
    await pumpActivations(
      tester,
      Routes.activations,
      now: thursday,
      service: instantActivations(
        now: thursday,
        seed: [
          ...Figma.world(
            thursday,
            kudiBox: Figma.step1,
            orchidFoods: Figma.orchidStarted,
          ).take(2),
          DemoActivations(thursday).unibooks.withProgress(
            ActivationProgress(
              startedAt: Figma.startedAt,
              confirmedAt: [Figma.step1At, Figma.step1At],
              paidAt: Figma.step1At,
            ),
          ),
        ],
      ),
    );
    expect(find.text('Kudi Box · step 1 of 3 confirmed'), findsOneWidget);
    expect(find.text('Place your first Unibooks order'), findsNothing);
    await _tap(tester, find.text('My activations'));
    expect(find.byType(MyActivationsScreen), findsOneWidget);
    expect(find.text('Rate 3 recipes in the Orchid Foods app'), findsOne);
    expect(find.text(_kudiBox), findsOneWidget);
    expect(find.text('Place your first Unibooks order'), findsNothing);

    await _tap(tester, find.text('Done'));
    expect(find.text('Place your first Unibooks order'), findsOneWidget);
    expect(find.text('Paid to your wallet'), findsOneWidget);
    expect(find.text(_kudiBox), findsNothing);

    await _tap(tester, find.text('Active'));
    await _tap(tester, find.text(_kudiBox));
    expect(find.byType(ActivationScreen), findsOneWidget);
    await _tap(tester, _button('Back'));
    expect(find.byType(MyActivationsScreen), findsOneWidget);
    await _tap(tester, _button('Back'));
    expect(find.byType(ActivationsScreen), findsOneWidget);
  });

  testWidgets('B8: My activations opens the activation when there is one', (
    tester,
  ) async {
    await pumpActivations(
      tester,
      Routes.activations,
      now: thursday,
      service: instantActivations(
        now: thursday,
        seed: Figma.world(thursday, kudiBox: Figma.step1),
      ),
    );
    await _tap(tester, find.text('My activations'));
    expect(find.byType(MyActivationsScreen), findsNothing);
    expect(find.text('Step 1 of 3 confirmed'), findsOneWidget);
    await _tap(tester, _button('Back'));
    expect(find.byType(ActivationsScreen), findsOneWidget);
  });

  test('My activations goes to the list unless exactly one is yours', () {
    final none = Figma.world(thursday);
    final one = Figma.world(thursday, kudiBox: Figma.step1);
    final two = Figma.world(
      thursday,
      kudiBox: Figma.step1,
      orchidFoods: Figma.orchidStarted,
    );
    expect(myActivationsTarget(none), myActivationsPath);
    expect(myActivationsTarget(one), activationPath('a2'));
    expect(myActivationsTarget(two), myActivationsPath);
  });

  testWidgets('B8: an activation that has ended cannot start', (tester) async {
    final ended = DemoActivations(thursday).kudiBox.closesAt
        .add(const Duration(days: 2));
    await pumpActivations(
      tester,
      activationPath('a2'),
      now: ended,
      service: instantActivations(now: ended, seed: Figma.world(thursday)),
    );
    expect(find.text('Ended 2 days ago'), findsOneWidget);
    expect(_iqButton(tester, 'This activation has ended').disabled, isTrue);
    expect(find.text('Start activation'), findsNothing);
  });

  testWidgets('B8: a start that fails says so and tries again', (tester) async {
    final haptics = recordHaptics(tester);
    await pumpActivations(
      tester,
      activationPath('a2'),
      now: thursday,
      service: instantActivations(now: thursday, startFailures: 1),
    );
    await _tap(tester, find.text('Start activation'));
    expect(find.text("Couldn't start. Check your connection."), findsOne);
    expect(haptics, [_error], reason: 'the failure replaces the commit');
    await _tap(tester, find.text('Try again'));
    expect(find.text('Not started · 3 steps'), findsOneWidget);
  });

  testWidgets('B8: failed to load, Try again loads the list', (tester) async {
    await pumpActivations(
      tester,
      Routes.activations,
      now: thursday,
      service: instantActivations(now: thursday, loadFailures: 1),
    );
    expect(find.text("Couldn't load activations"), findsOneWidget);
    await _tap(tester, find.text('Try again'));
    expect(find.text("Couldn't load activations"), findsNothing);
    expect(find.text(_kudiBox), findsOneWidget);
  });

  testWidgets('B8: no activations, Browse briefs goes to Discover', (
    tester,
  ) async {
    await pumpActivations(
      tester,
      Routes.activations,
      now: thursday,
      service: instantActivations(now: thursday, seed: const []),
    );
    expect(find.text('No activations right now'), findsOneWidget);
    await _tap(tester, find.text('Browse briefs'));
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('B8: tapping the confirming step asks again; it is paid', (
    tester,
  ) async {
    await pumpActivations(
      tester,
      activationPath('a2'),
      now: thursday,
      service: instantActivations(
        now: thursday,
        seed: Figma.world(thursday, kudiBox: Figma.step1),
      ),
    );
    await _tap(
      tester,
      find.text('Kudi Box is checking. Usually a few minutes.'),
    );
    expect(find.text('₦1,500.00 is yours'), findsOneWidget);
  });

  testWidgets('B9: the waiting step turns to not confirmed at 24 hours', (
    tester,
  ) async {
    var now = thursday;
    final since = thursday.subtract(
      ActivationRules.confirmWindow - const Duration(minutes: 1),
    );
    await pumpActivations(
      tester,
      activationPath('a2'),
      now: thursday,
      service: instantActivations(
        now: thursday,
        seed: Figma.world(
          thursday,
          kudiBox: ActivationProgress(startedAt: since, confirmedAt: [since]),
        ),
      ),
      clock: () => now,
    );
    expect(find.text('Upload proof of step 2'), findsNothing);
    now = thursday.add(const Duration(minutes: 1));
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(find.text('Step 2 not confirmed yet'), findsOneWidget);
    expect(find.text('1 day waiting'), findsOneWidget);
    expect(find.text('Not confirmed after a day'), findsOneWidget);
    expect(find.text('Upload proof of step 2'), findsOneWidget);
  });

  testWidgets('B9: photo access first; Don’t Allow leaves the tile, Allow '
      'picks; Send proof turns the activation to Your proof', (tester) async {
    final haptics = recordHaptics(tester);
    final media = DemoMediaService(delay: Duration.zero);
    await pumpActivations(
      tester,
      activationPath('a2'),
      now: friday,
      service: stuck(),
      media: media,
    );
    await _tap(tester, find.text('Upload proof of step 2'));
    expect(find.byType(ProofScreen), findsOneWidget);
    expect(
      find.text('Record step 2. Kudi Box confirms it.'),
      findsOneWidget,
      reason: 'step 2 of 3 pays nothing on its own (D1)',
    );
    expect(_iqButton(tester, 'Send proof').disabled, isTrue);

    await _tap(tester, find.byType(IqProofTile));
    expect(find.text('“iQLY” Would Like to Access Your Photos'), findsOne);
    await _tap(tester, find.text('Don’t Allow'));
    expect(media.picks, 0);
    expect(find.byType(IqProofTile), findsOneWidget);

    await _tap(tester, find.byType(IqProofTile));
    expect(
      _iqButton(tester, 'Allow Full Access').kind,
      IqButtonKind.primary,
      reason: '485:38820 draws the prompt\'s answer as Primary, not Danger',
    );
    await _tap(tester, find.text('Allow Full Access'));
    expect(media.picks, 1);
    expect(find.text('18 MB · uploaded, ready to send'), findsOneWidget);

    await _tap(tester, find.text('kudi-box-signup.mp4'));
    expect(media.picks, 1, reason: 'the polaroid is not a picker');

    haptics.clear();
    await _tap(tester, find.text('Send proof'));
    expect(haptics.last, _success);
    expect(find.byType(ProofScreen), findsNothing);
    expect(find.text('Your proof'), findsWidgets);
    expect(find.text('Checking with Kudi Box'), findsWidgets);
    expect(find.textContaining('after confirmation'), findsNothing);
  });

  testWidgets('B9: a recording over 60 s is refused; Retry picks another', (
    tester,
  ) async {
    final haptics = recordHaptics(tester);
    final media = DemoMediaService(
      delay: Duration.zero,
      access: MediaAccess.allowed,
      video: DemoMediaService.tooLong,
    );
    await pumpActivations(
      tester,
      proofPath('a2'),
      now: friday,
      service: stuck(),
      media: media,
    );
    await _tap(tester, find.byType(IqProofTile));
    expect(
      find.text(
        'Your video is 1:42. Keep it under 60 seconds and end on the '
        'Verification page.',
      ),
      findsOneWidget,
    );
    expect(haptics, contains(_error));
    expect(
      tester.widget<IqVideoPreview>(find.byType(IqVideoPreview)).state,
      IqVideoPreviewState.failed,
    );

    media.video = DemoMediaService.sample;
    await _tap(tester, find.text('Retry'));
    expect(media.picks, 2);
    expect(find.byType(IqBanner), findsNothing);
    expect(find.text('18 MB · uploaded, ready to send'), findsOneWidget);
  });

  testWidgets('B9: a recording over 50 MB is refused', (tester) async {
    await pumpActivations(
      tester,
      proofPath('a2'),
      now: friday,
      service: stuck(),
      media: DemoMediaService(
        delay: Duration.zero,
        access: MediaAccess.allowed,
        video: const ProofVideo(name: 'big.mp4', bytes: 64000000),
      ),
    );
    await _tap(tester, find.byType(IqProofTile));
    expect(
      find.text(
        'Your video is 64 MB. Keep it under 50 MB and end on the '
        'Verification page.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('B9: a failed upload offers Retry', (tester) async {
    await pumpActivations(
      tester,
      proofPath('a2'),
      now: friday,
      service: stuck(uploadFailures: 1),
    );
    await _tap(tester, find.byType(IqProofTile));
    expect(
      find.text('Upload failed. Check your connection and retry.'),
      findsOneWidget,
    );
    await _tap(tester, find.text('Retry'));
    expect(find.text('18 MB · uploaded, ready to send'), findsOneWidget);
  });

  testWidgets('B9: Send proof before the upload is in shakes the slot', (
    tester,
  ) async {
    final haptics = recordHaptics(tester);
    await pumpActivations(
      tester,
      proofPath('a2'),
      now: friday,
      service: stuck(uploadFailures: 1),
    );
    await _tap(tester, find.byType(IqProofTile));
    haptics.clear();
    await _tap(tester, find.text('Send proof'));
    expect(haptics, [_error]);
    expect(find.byType(ProofScreen), findsOneWidget);
  });

  testWidgets('B9: remove asks first, then the tile comes back', (
    tester,
  ) async {
    await pumpActivations(
      tester,
      proofPath('a2'),
      now: friday,
      service: stuck(),
    );
    await _tap(tester, find.byType(IqProofTile));
    await _tap(tester, _button('Remove'));
    expect(find.text('Remove this recording?'), findsOneWidget);
    expect(find.text('You’ll need to upload it again.'), findsOneWidget);
    await _tap(tester, find.text('Keep it'));
    expect(find.byType(IqVideoPreview), findsOneWidget);
    await _tap(tester, _button('Remove'));
    await _tap(tester, find.text('Remove recording'));
    expect(find.byType(IqVideoPreview), findsNothing);
    expect(find.byType(IqProofTile), findsOneWidget);
  });

  testWidgets('B9: a send that fails says so and tries again', (tester) async {
    await pumpActivations(
      tester,
      proofPath('a2'),
      now: friday,
      service: stuck(sendFailures: 1),
    );
    await _tap(tester, find.byType(IqProofTile));
    await _tap(tester, find.text('Send proof'));
    expect(find.text("Couldn't send. Check your connection."), findsOne);
    await _tap(tester, find.text('Try again'));
    expect(find.byType(ProofScreen), findsNothing);
  });

  testWidgets('B9: proof not accepted; Record again opens a fresh upload', (
    tester,
  ) async {
    await pumpActivations(
      tester,
      activationPath('a2'),
      now: friday,
      service: stuck(refusals: 1, step: const Duration(seconds: 4)),
    );
    await _tap(tester, find.text('Upload proof of step 2'));
    await _tap(tester, find.byType(IqProofTile));
    await _tap(tester, find.text('Send proof'));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Proof not accepted. The recording ends before the Verification '
        'page.',
      ),
      findsOneWidget,
    );
    await _tap(tester, find.text('Record again'));
    expect(find.byType(ProofScreen), findsOneWidget);
    expect(find.byType(IqProofTile), findsOneWidget);
    await _tap(tester, find.byType(IqProofTile));
    await _tap(tester, find.text('Send proof'));
    expect(find.textContaining('Proof not accepted'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    // A checked proof confirms its own step; Kudi Box’s app confirms the last.
    expect(find.text('Step 2 of 3 confirmed'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('₦1,500.00 is yours'), findsOneWidget);
  });

  testWidgets('proof mode (Orchid Foods): step 1 is recorded right after '
      'Start, each accepted proof moves to the next, the last pays', (
    tester,
  ) async {
    final container = await pumpActivations(
      tester,
      activationPath('a1'),
      now: thursday,
      service: instantActivations(
        now: thursday,
        step: const Duration(seconds: 4),
      ),
    );
    await _tap(tester, find.text('Start activation'));
    expect(find.text('Not started · 3 steps'), findsOneWidget);
    for (var step = 1; step <= 3; step++) {
      await _tap(tester, find.text('Upload proof of step $step'));
      expect(find.byType(ProofScreen), findsOneWidget);
      expect(find.text('Proof of step $step · up to 60 seconds'), findsOne);
      await _tap(tester, find.byType(IqProofTile));
      await _tap(tester, find.text('Send proof'));
      expect(find.text('Your proof'), findsWidgets);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      if (step < 3) {
        expect(find.text('Step $step of 3 confirmed'), findsOneWidget);
        expect(
          container.read(activationProvider('a1'))!.credited,
          isFalse,
          reason: 'it pays on the last',
        );
      }
    }
    expect(find.text('₦500.00 is yours'), findsOneWidget);
    expect(_awards(container), {'activation-a1': 50000});
  });

  testWidgets('paid by step: each accepted proof puts its step on the wallet', (
    tester,
  ) async {
    final container = await pumpActivations(
      tester,
      activationPath('a1'),
      now: thursday,
      service: instantActivations(
        now: thursday,
        seed: [DemoActivations(thursday).orchidFoodsByStep],
        step: const Duration(seconds: 4),
      ),
    );
    await _tap(tester, find.text('Start activation'));
    await _tap(tester, find.text('Upload proof of step 1'));
    expect(
      find.text('Record step 1. Orchid Foods confirms it, then we pay ₦100.'),
      findsOneWidget,
    );
    await _tap(tester, find.byType(IqProofTile));
    await _tap(tester, find.text('Send proof'));
    expect(find.text('₦100.00 after confirmation'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Paid ₦100'), findsOneWidget);
    expect(_awards(container), {'activation-a1-step-0': 10000});
  });

  testWidgets('a run under way asks for help about itself', (tester) async {
    await pumpActivations(
      tester,
      activationPath('a2'),
      now: thursday,
      service: instantActivations(
        now: thursday,
        seed: Figma.world(thursday, kudiBox: Figma.step1),
      ),
    );
    await _tap(tester, find.text('Ask for help'));
    expect(find.byType(HelpRequestScreen), findsOneWidget);
    expect(find.text('Send to support'), findsOneWidget);
  });

  testWidgets('B9: play opens the recording; back returns', (tester) async {
    await pumpActivations(
      tester,
      activationPath('a2'),
      now: friday,
      service: instantActivations(
        now: friday,
        seed: Figma.world(friday, kudiBox: Figma.proofSent),
      ),
    );
    await _tap(tester, _button('Play'));
    expect(find.byType(ProofPlayerScreen), findsOneWidget);
    expect(find.text('kudi-box-signup.mp4'), findsOneWidget);
    await _tap(tester, _button('Back'));
    expect(find.byType(ProofPlayerScreen), findsNothing);
    expect(find.text('Not credited yet?'), findsOneWidget);
  });

  testWidgets('B9: Ask for help opens the support inbox about the activation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    SharedPreferences.setMockInitialValues(signedInPrefs());
    final shared = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation: activationPath('a2'),
      routes: [
        ...activationsRoutes,
        GoRoute(
          path: Routes.help,
          pageBuilder: (context, state) =>
              pushPage(state, const Scaffold(body: Text('Help'))),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(shared),
          clockProvider.overrideWithValue(() => friday),
          repositoryProvider.overrideWithValue(CreditedRepository()),
          activationsServiceProvider.overrideWithValue(
            instantActivations(
              now: friday,
              seed: Figma.world(friday, kudiBox: Figma.proofSent),
            ),
          ),
        ],
        child: MaterialApp.router(theme: buildTheme(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Support usually replies within an hour on weekdays, within a day '
        'at weekends.',
      ),
      findsOneWidget,
    );
    await _tap(tester, find.text('Ask for help'));
    expect(router.state.uri.path, Routes.help);
    expect(router.state.uri.queryParameters['about'], 'a2');
  });

  for (final (name, location, seed, now) in [
    ('list', Routes.activations, Figma.step1, thursday),
    ('my activations', myActivationsPath, Figma.step1, thursday),
    ('offer', activationPath('a2'), null, thursday),
    ('in progress', activationPath('a2'), Figma.step1, thursday),
    ('not confirmed', activationPath('a2'), Figma.step1, friday),
    ('checking', activationPath('a2'), Figma.proofSent, friday),
    ('not accepted', activationPath('a2'), Figma.proofRefused, friday),
    ('credited', activationPath('a2'), Figma.paid, thursday),
  ]) {
    testWidgets('$name: 44 pt targets, all labelled', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpActivations(
        tester,
        location,
        now: now,
        service: instantActivations(
          now: now,
          seed: Figma.world(
            now,
            kudiBox: seed,
            orchidFoods: Figma.orchidStarted,
          ),
        ),
      );
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });
  }

  testWidgets('proof: every target labelled', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpActivations(
      tester,
      proofPath('a2'),
      now: friday,
      service: stuck(),
    );
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await _tap(tester, find.byType(IqProofTile));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('the proof screen scrolls its fields above a 336 pt keyboard', (
    tester,
  ) async {
    await pumpActivations(
      tester,
      proofPath('a2'),
      now: friday,
      service: stuck(),
    );
    await tester.tap(find.byType(EditableText).last);
    tester.view.padding = const FakeViewPadding(top: 54);
    tester.view.viewInsets = const FakeViewPadding(bottom: 336);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final field = tester.getRect(find.byType(EditableText).last);
    expect(field.bottom, lessThan(844 - 336));
  });

  testWidgets('Your proof: the sent recording has no remove sticker', (
    tester,
  ) async {
    await pumpActivations(
      tester,
      activationPath('a2'),
      now: friday,
      service: instantActivations(
        now: friday,
        seed: Figma.world(friday, kudiBox: Figma.proofSent),
      ),
    );
    expect(
      tester.widget<IqVideoPreview>(find.byType(IqVideoPreview)).showRemove,
      isFalse,
    );
    expect(_button('Remove'), findsNothing);
  });

  test('the device picker falls back to the demo recording without the '
      'plugin', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final picked = await DeviceMediaService().pickVideo(about: 'Kudi Box');
    expect(picked?.name, 'kudi-box-signup.mp4');
  });
}
