import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iqly_mobile/core/deadline.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/core/transitions.dart';
import 'package:iqly_mobile/data/activations_data.dart';
import 'package:iqly_mobile/data/activations_service.dart';
import 'package:iqly_mobile/data/device.dart';
import 'package:iqly_mobile/data/media_service.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/features/activations/activation_screen.dart';
import 'package:iqly_mobile/features/activations/activations_routes.dart';
import 'package:iqly_mobile/features/activations/activations_screen.dart';
import 'package:iqly_mobile/features/activations/proof_player_screen.dart';
import 'package:iqly_mobile/features/activations/proof_screen.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/wallet/wallet_screen.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/balance_hero.dart';
import 'package:iqly_mobile/ui/wallet_card.dart';
import 'package:iqly_mobile/ui/pressable.dart';
import 'package:iqly_mobile/ui/proof_tile.dart';
import 'package:iqly_mobile/ui/video_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../golden/golden.dart' show loadAppFonts;
import '../golden/screens/activations_harness.dart';
import '../golden/screens/app_harness.dart' show signedInPrefs;
import 'entry_harness.dart' show recordHaptics;

const _success = 'HapticFeedbackType.successNotification';
const _commit = 'HapticFeedbackType.lightImpact';
const _error = 'HapticFeedbackType.mediumImpact';

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

IqBalanceHero _hero(WidgetTester tester) =>
    tester.widget<IqBalanceHero>(find.byType(IqBalanceHero));

/// A service at [now] that confirms on the prototype's 4 s beats.
DemoActivationsService _live(DateTime now, {List<Activation>? seed}) =>
    DemoActivationsService(
      seed: seed ?? Figma.world(now),
      clock: () => now,
      load: const Duration(milliseconds: 1200),
      delay: Duration.zero,
      uploadTick: Duration.zero,
    );

void main() {
  setUpAll(loadAppFonts);

  final thursday = Figma.thursday;
  final friday = Figma.friday;

  testWidgets(
    'B8: Discover → loading → Activations → detail → started → confirmed → '
    'paid → wallet',
    (tester) async {
      final haptics = recordHaptics(tester);
      await pumpActivations(
        tester,
        Routes.home,
        now: thursday,
        service: _live(thursday),
      );
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('1 closes today'), findsOneWidget);

      await tester.tap(find.text('Activations'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ActivationsScreen), findsOneWidget);
      expect(find.text('LOADING…'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
      expect(find.text('LOADING…'), findsNothing);
      expect(find.text('SHORT TASKS FROM BUSINESSES'), findsOneWidget);
      expect(find.text('CLOSING SOON · 1'), findsOneWidget);
      expect(find.text('ALL ACTIVATIONS · 3'), findsOneWidget);
      expect(find.text('Rate 3 recipes in the Orchid Foods app'), findsOne);
      expect(find.text('5h 40m'), findsOneWidget);
      expect(find.text('Earn ₦500'), findsOneWidget);
      expect(find.text('Earn ₦1,500'), findsOneWidget);
      expect(find.text('My activations'), findsNothing);

      await _tap(tester, find.text('Open a Kudi Box account and save ₦1,000'));
      expect(find.byType(ActivationScreen), findsOneWidget);
      expect(find.text('Activation'), findsOneWidget);
      expect(find.text('HOW YOU GET PAID'), findsOneWidget);
      expect(find.text('By Kudi Box, automatically'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Missed step? Proof within 48 hours.'),
        200,
      );
      expect(find.text('Settings → Verification. About 2 min'), findsOne);
      expect(haptics, isEmpty);

      await _tap(tester, find.text('Start activation'));
      expect(haptics, [_commit]);
      expect(find.text('Step 0 of 3 confirmed'), findsOneWidget);
      expect(find.text('2 days left'), findsOneWidget);
      expect(find.text('Settings → Verification'), findsOneWidget);
      expect(find.text('Open Kudi Box'), findsOneWidget);
      expect(find.text('Start activation'), findsNothing);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('Step 1 of 3 confirmed'), findsOneWidget);
      expect(find.text('Confirmed by Kudi Box · Thu, 1:55 pm'), findsOneWidget);
      expect(find.text('Confirming, usually minutes'), findsOneWidget);
      expect(haptics, [_commit], reason: 'a confirmation is passive');

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('Your reward'), findsOneWidget);
      expect(find.text('Paid ₦1,500'), findsOneWidget);
      expect(find.text('Steps confirmed by Kudi Box'), findsOneWidget);
      expect(find.text('Thu, 1:55 pm · 3 of 3 steps'), findsOneWidget);
      expect(_hero(tester).amount, '₦16,500');
      expect(_hero(tester).decimals, '.00');
      expect(_hero(tester).earned, '₦66,500.00');
      expect(_hero(tester).onHold, '₦10,000.00');
      expect(find.text('Withdraw'), findsNothing);
      expect(haptics, [_commit, _success]);

      await _tap(tester, find.text('View wallet'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byType(WalletScreen), findsOneWidget);
      expect(
        tester.widget<IqWalletCard>(find.byType(IqWalletCard)).amount,
        '₦16,500.00',
      );
      expect(find.text('+₦1,500.00'), findsWidgets);
    },
  );

  testWidgets('B8: tapping the confirming step asks again; it is paid', (
    tester,
  ) async {
    final service = instantActivations(
      now: thursday,
      seed: Figma.world(thursday, kudiBox: Figma.step1),
    );
    await pumpActivations(
      tester,
      activationPath('a2'),
      now: thursday,
      service: service,
    );
    expect(find.text('Step 1 of 3 confirmed'), findsOneWidget);
    await _tap(tester, find.text('Verify your BVN in the app'));
    expect(find.text('Your reward'), findsOneWidget);
    expect(service['a2'].credited, isTrue);
  });

  testWidgets(
    'B8: My activations opens the one under way; back and Find another '
    'activation return to the list, the paid one gone',
    (tester) async {
      final device = DemoDeviceService(delay: Duration.zero);
      await pumpActivations(
        tester,
        Routes.activations,
        now: thursday,
        device: device,
        service: instantActivations(
          now: thursday,
          seed: Figma.world(thursday, kudiBox: Figma.step1),
        ),
      );
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Step 1 of 3 confirmed · about 10 min'), findsOne);
      await _tap(tester, find.text('My activations'));
      expect(find.text('Kudi Box · step 1 of 3 confirmed'), findsNothing);
      expect(find.text('Step 1 of 3 confirmed'), findsOneWidget);

      await _tap(tester, find.text('Open Kudi Box'));
      expect(device.opened, [Uri.parse('https://kudibox.example/app')]);

      await _tap(tester, _button('Back'));
      expect(find.byType(ActivationsScreen), findsOneWidget);
      await _tap(tester, find.text('Continue'));
      await _tap(tester, find.text('Verify your BVN in the app'));
      await _tap(tester, find.text('Find another activation'));
      expect(find.byType(ActivationsScreen), findsOneWidget);
      expect(find.text('ALL ACTIVATIONS · 2'), findsOneWidget);
      expect(
        find.text('Open a Kudi Box account and save ₦1,000'),
        findsNothing,
      );
      expect(find.text('My activations'), findsNothing);
    },
  );

  testWidgets(
    'B9: step not confirmed → upload proof → ready → keep, remove → send → '
    'checking → paid → wallet',
    (tester) async {
      final haptics = recordHaptics(tester);
      final service = instantActivations(
        now: friday,
        seed: Figma.world(friday, kudiBox: Figma.step1),
      );
      await pumpActivations(
        tester,
        Routes.activations,
        now: friday,
        service: service,
      );
      await _tap(tester, find.text('My activations'));
      expect(find.text('Step 2 not confirmed yet'), findsOneWidget);
      expect(find.text('1 day waiting'), findsOneWidget);
      expect(find.text('Not confirmed after a day'), findsOneWidget);

      await _tap(tester, find.text('Upload proof of step 2'));
      expect(haptics, [_commit]);
      expect(find.byType(ProofScreen), findsOneWidget);
      expect(
        find.text('Record step 2. iQLY checks it, then pays ₦1,500.'),
        findsOneWidget,
      );
      expect(find.text('PROOF OF STEP 2 · UP TO 60 SECONDS'), findsOneWidget);
      expect(find.text('Kudi Box account phone number (optional)'), findsOne);

      await _tap(tester, find.byType(IqProofTile));
      expect(find.text('kudi-box-signup.mp4'), findsOneWidget);
      expect(find.text('18 MB · uploaded, ready to send'), findsOneWidget);

      await _tap(tester, _button('Remove'));
      expect(find.text('Remove this recording?'), findsOneWidget);
      expect(find.text('You’ll need to upload it again.'), findsOneWidget);
      await _tap(tester, find.text('Keep it'));
      expect(find.text('Remove this recording?'), findsNothing);
      expect(find.text('18 MB · uploaded, ready to send'), findsOneWidget);

      await _tap(tester, _button('Remove'));
      await _tap(tester, find.text('Remove recording'));
      expect(find.text('Add your screen recording'), findsOneWidget);
      expect(service.discarded, ['upload-1']);
      expect(haptics.last, 'HapticFeedbackType.mediumImpact');

      await _tap(tester, find.byType(IqProofTile));
      await tester.enterText(find.byType(EditableText).first, '0801 234 5678');
      await tester.enterText(find.byType(EditableText).last, 'Same number');
      await tester.pump();
      haptics.clear();
      await _tap(tester, find.text('Send proof'));
      expect(haptics, [_success]);
      expect(find.byType(ProofScreen), findsNothing);
      expect(find.text('Your proof'), findsOneWidget);
      expect(find.text('Checking'), findsOneWidget);
      expect(find.text('STEP 2 · KUDI BOX'), findsOneWidget);
      expect(find.text('Proof received'), findsOneWidget);
      expect(find.text('Fri, 2:10 pm'), findsOneWidget);
      expect(find.text('₦1,500 after confirmation'), findsOneWidget);
      expect(find.text('0:42 · 18 MB'), findsOneWidget);
      expect(service.sent.single.phone, '0801 234 5678');
      expect(service.sent.single.note, 'Same number');

      await _tap(tester, find.text('Checking with Kudi Box'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Your reward'), findsOneWidget);
      expect(find.text('Confirmed Fri, 2:10 pm'), findsOneWidget);
      expect(_hero(tester).amount, '₦16,500');
      expect(haptics.last, _success);

      await _tap(tester, find.text('View wallet'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byType(WalletScreen), findsOneWidget);
      expect(find.text('+₦1,500.00'), findsWidgets);
    },
  );

  testWidgets('B9: Send proof with nothing picked shakes the tile', (
    tester,
  ) async {
    final haptics = recordHaptics(tester);
    await pumpActivations(
      tester,
      proofPath('a2'),
      now: friday,
      service: instantActivations(
        now: friday,
        seed: Figma.world(friday, kudiBox: Figma.step1),
      ),
    );
    await _tap(tester, find.text('Send proof'));
    expect(haptics, [_error]);
    expect(find.byType(ProofScreen), findsOneWidget);
  });

  testWidgets('B9: a recording over 60 s, then another that fits', (
    tester,
  ) async {
    final haptics = recordHaptics(tester);
    final media = DemoMediaService(
      delay: Duration.zero,
      video: const ProofVideo(
        name: 'long.mp4',
        bytes: 31000000,
        length: Duration(seconds: 74),
      ),
    );
    await pumpActivations(
      tester,
      proofPath('a2'),
      now: friday,
      media: media,
      service: instantActivations(
        now: friday,
        seed: Figma.world(friday, kudiBox: Figma.step1),
      ),
    );
    await _tap(tester, find.byType(IqProofTile));
    expect(find.text('That recording is over 60 seconds'), findsOneWidget);
    expect(haptics, [_error]);
    media.video = DemoMediaService.sample;
    await _tap(tester, find.text('Choose another'));
    expect(find.text('18 MB · uploaded, ready to send'), findsOneWidget);
  });

  testWidgets('B9: a failed upload offers Retry', (tester) async {
    await pumpActivations(
      tester,
      proofPath('a2'),
      now: friday,
      service: instantActivations(
        now: friday,
        seed: Figma.world(friday, kudiBox: Figma.step1),
        uploadFailures: 1,
      ),
    );
    await _tap(tester, find.byType(IqProofTile));
    expect(
      find.text('Upload failed. Check your connection and retry.'),
      findsOneWidget,
    );
    await _tap(tester, find.text('Retry'));
    expect(find.text('18 MB · uploaded, ready to send'), findsOneWidget);
  });

  testWidgets('B9: a send that fails says so and tries again', (tester) async {
    final haptics = recordHaptics(tester);
    await pumpActivations(
      tester,
      proofPath('a2'),
      now: friday,
      service: instantActivations(
        now: friday,
        seed: Figma.world(friday, kudiBox: Figma.step1),
        sendFailures: 1,
      ),
    );
    await _tap(tester, find.byType(IqProofTile));
    await _tap(tester, find.text('Send proof'));
    expect(find.text('Couldn’t send. Check your connection.'), findsOneWidget);
    expect(haptics, [_error]);
    await _tap(tester, find.text('Try again'));
    expect(find.byType(ProofScreen), findsNothing);
    expect(find.text('Checking'), findsOneWidget);
  });

  testWidgets('B8: a start that fails says so and tries again', (tester) async {
    await pumpActivations(
      tester,
      activationPath('a2'),
      now: thursday,
      service: instantActivations(now: thursday, startFailures: 1),
    );
    await _tap(tester, find.text('Start activation'));
    expect(find.text('Couldn’t start. Check your connection.'), findsOne);
    await _tap(tester, find.text('Try again'));
    expect(find.text('Step 0 of 3 confirmed'), findsOneWidget);
  });

  testWidgets('B8: failed to load, Try again loads the list', (tester) async {
    final haptics = recordHaptics(tester);
    await pumpActivations(
      tester,
      Routes.activations,
      now: thursday,
      service: instantActivations(now: thursday, loadFailures: 2),
    );
    expect(find.text('Couldn’t load. Check your connection.'), findsOne);
    expect(find.text('Nothing to show yet'), findsOneWidget);
    await _tap(tester, find.text('Try again'));
    expect(find.text('Couldn’t load. Check your connection.'), findsOne);
    expect(haptics, [_error], reason: 'the retry failed again');
    await _tap(tester, find.text('Try again'));
    expect(find.text('SHORT TASKS FROM BUSINESSES'), findsOneWidget);
    expect(haptics, [_error]);
  });

  testWidgets('B8: no activations', (tester) async {
    await pumpActivations(
      tester,
      Routes.activations,
      now: thursday,
      service: instantActivations(now: thursday, seed: const []),
    );
    expect(find.text('No activations right now'), findsOneWidget);
    expect(find.text('Check back soon.'), findsOneWidget);
    await _tap(tester, _button('Back'));
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('B9: the waiting step turns to not confirmed at 24 hours', (
    tester,
  ) async {
    final since = thursday.subtract(
      ActivationRules.confirmWindow - const Duration(minutes: 1),
    );
    var now = thursday;
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
    expect(find.text('Confirming, usually minutes'), findsOneWidget);
    expect(find.text('Upload proof of step 2'), findsNothing);
    now = thursday.add(const Duration(minutes: 1));
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(find.text('Not confirmed after a day'), findsOneWidget);
    expect(find.text('Upload proof of step 2'), findsOneWidget);
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
    expect(find.text('Your proof'), findsOneWidget);
    expect(find.text('YOUR PROOF'), findsOneWidget);
  });

  testWidgets('B9: Ask for help opens Help', (tester) async {
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
    expect(find.text('NOT CREDITED YET?'), findsOneWidget);
    expect(find.text('Support replies within 2 hours.'), findsOneWidget);
    await _tap(tester, find.text('Ask for help'));
    expect(router.state.uri.path, Routes.help);
    expect(router.state.uri.queryParameters['about'], 'a2');
  });

  for (final (name, location, seed, now) in [
    ('list', Routes.activations, Figma.step1, thursday),
    ('offer', activationPath('a2'), null, thursday),
    ('in progress', activationPath('a2'), Figma.step1, thursday),
    ('not confirmed', activationPath('a2'), Figma.step1, friday),
    ('checking', activationPath('a2'), Figma.proofSent, friday),
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
          seed: Figma.world(now, kudiBox: seed),
        ),
      );
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });
  }

  // IqField's semantics node is its 22 pt text line, not the 62 pt field
  // (stage 2 of the motion pass owns that fix), so the proof screen checks
  // its labels only.
  testWidgets('proof: every target labelled', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpActivations(
      tester,
      proofPath('a2'),
      now: friday,
      service: instantActivations(
        now: friday,
        seed: Figma.world(friday, kudiBox: Figma.step1),
      ),
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
      service: instantActivations(
        now: friday,
        seed: Figma.world(friday, kudiBox: Figma.step1),
      ),
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
}
