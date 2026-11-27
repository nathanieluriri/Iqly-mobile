import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/kyc_service.dart';
import 'package:iqly_mobile/features/kyc/kyc_controller.dart';
import 'package:iqly_mobile/features/kyc/kyc_nudge.dart';
import 'package:iqly_mobile/features/kyc/kyc_sheet.dart';
import 'package:iqly_mobile/features/more/more_screen.dart';
import 'package:iqly_mobile/features/wallet/kyc_sheet.dart' as withdraw;
import 'package:iqly_mobile/ui/button.dart';
import 'package:iqly_mobile/features/wallet/withdraw_sheet.dart';
import 'package:iqly_mobile/router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/live/live_data_fixtures.dart' show FakeApi;
import '../../support/live_launch.dart';

const unverified = KycStatus(
  required: true,
  verified: false,
  tier: 1,
  requiredTier: 2,
  nextCheck: KycCheckKind.document,
  checks: {KycCheckKind.identity: KycCheckState.passed},
);

class FakeKyc implements KycService {
  FakeKyc(this.current);

  KycStatus current;
  KycRefused? failure;
  var reads = 0;

  @override
  Future<KycStatus> status() async {
    reads++;
    if (failure != null) throw failure!;
    return current;
  }

  @override
  Future<KycStatus> verify(KycCheck check) async => current;

  @override
  Future<KycStatus> upload(KycCheckKind check, KycEvidence file) async =>
      current;
}

class _QueuedKyc extends FakeKyc {
  _QueuedKyc(super.current, this.responses);

  final List<Completer<KycStatus>> responses;
  Completer<KycStatus>? fallback;
  var _calls = 0;

  @override
  Future<KycStatus> status() async {
    _calls++;
    if (_calls == 1) return current;
    if (responses.isNotEmpty) return responses.removeAt(0).future;
    if (fallback != null) return fallback!.future;
    return current;
  }
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(const {});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('Discover shows KYC outside withdrawal and opens the KYC sheet', (
    tester,
  ) async {
    final kyc = FakeKyc(unverified);
    await pumpLiveLaunch(tester, Routes.home, api: FakeApi().api(), kyc: kyc);
    await tester.pumpAndSettle();
    expect(find.byType(KycNudge), findsOneWidget);
    expect(find.text('Verify to submit and withdraw'), findsOneWidget);
    await tester.tap(find.text('Verify to submit and withdraw'));
    await tester.pumpAndSettle();
    expect(find.byType(KycSheet), findsOneWidget);
  });

  testWidgets('More exposes the current tier on phone and tablet', (
    tester,
  ) async {
    final kyc = FakeKyc(unverified);
    await pumpLiveLaunch(tester, Routes.more, api: FakeApi().api(), kyc: kyc);
    tester.view.physicalSize = const Size(1024, 844);
    await tester.pumpAndSettle();
    expect(find.byType(MoreScreen), findsOneWidget);
    expect(find.text('Tier 1 of 2'), findsOneWidget);
    await tester.tap(find.text('Verification'));
    await tester.pumpAndSettle();
    expect(find.byType(KycSheet), findsOneWidget);
  });

  testWidgets('phone More exposes the current verification tier', (
    tester,
  ) async {
    final kyc = FakeKyc(unverified);
    await pumpLiveLaunch(tester, Routes.more, api: FakeApi().api(), kyc: kyc);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Verification'));
    await tester.pumpAndSettle();
    expect(find.text('Tier 1 of 2'), findsOneWidget);
  });

  testWidgets('Tier 1 confirms the legal name before verification', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const identity = KycStatus(
      required: true,
      requiredTier: 1,
      nextCheck: KycCheckKind.identity,
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: KycSheet(initialStatus: identity)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('First name'), findsNothing);
    await tester.enterText(find.byType(EditableText).first, '12345678901');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('First name'), findsOneWidget);
    expect(find.text('Last name'), findsOneWidget);
    await tester.enterText(find.byType(EditableText).at(0), 'Ada');
    await tester.enterText(find.byType(EditableText).at(1), 'Okafor');
    expect(
      tester
          .widget<IqButton>(find.widgetWithText(IqButton, 'Verify identity'))
          .disabled,
      isTrue,
    );
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<IqButton>(find.widgetWithText(IqButton, 'Verify identity'))
          .disabled,
      isFalse,
    );
  });

  testWidgets('KYC states show their launch illustrations', (tester) async {
    const states = [
      (
        KycStatus(
          required: true,
          requiredTier: 1,
          nextCheck: KycCheckKind.identity,
        ),
        'kyc-illustration-identity',
      ),
      (unverified, 'kyc-illustration-evidence'),
      (
        KycStatus(
          required: true,
          tier: 2,
          requiredTier: 3,
          nextCheck: KycCheckKind.selfie,
        ),
        'kyc-illustration-evidence',
      ),
      (
        KycStatus(
          required: true,
          verified: true,
          tier: 1,
          requiredTier: 2,
          nextCheck: KycCheckKind.none,
        ),
        'kyc-illustration-evidence',
      ),
      (
        KycStatus(
          required: true,
          verified: true,
          tier: 2,
          requiredTier: 2,
          nextCheck: KycCheckKind.none,
          checks: {
            KycCheckKind.identity: KycCheckState.passed,
            KycCheckKind.bankMatch: KycCheckState.passed,
            KycCheckKind.amlIndividual: KycCheckState.passed,
            KycCheckKind.document: KycCheckState.passed,
          },
        ),
        'kyc-illustration-success',
      ),
    ];
    for (final (status, key) in states) {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: KycSheet(
                key: ValueKey(
                  '${status.nextCheck}-${status.tier}-${status.requiredTier}',
                ),
                initialStatus: status,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey(key)), findsOneWidget);
    }
  });

  testWidgets('unverified withdrawal opens KYC, never WithdrawSheet', (
    tester,
  ) async {
    final kyc = FakeKyc(unverified);
    await pumpLiveLaunch(
      tester,
      Routes.withdraw,
      api: FakeApi().api(),
      kyc: kyc,
    );
    await tester.pumpAndSettle();
    expect(find.byType(withdraw.WithdrawEntry), findsOneWidget);
    expect(find.byType(KycSheet), findsOneWidget);
    expect(find.text('Add your government ID'), findsOneWidget);
    expect(find.byType(WithdrawSheet), findsNothing);
  });

  testWidgets('provider outage fails closed', (tester) async {
    final kyc = FakeKyc(unverified)
      ..failure = const KycRefused(KycProblem.unavailable);
    await pumpLiveLaunch(
      tester,
      Routes.withdraw,
      api: FakeApi().api(),
      kyc: kyc,
    );
    await tester.pumpAndSettle();
    expect(
      find.text('The identity check did not complete. Try again.'),
      findsOneWidget,
    );
    expect(find.byType(WithdrawSheet), findsNothing);
    expect(find.text('Try again'), findsWidgets);
  });

  testWidgets('missing KYC configuration explains that setup is pending', (
    tester,
  ) async {
    final kyc = FakeKyc(unverified)
      ..failure = const KycRefused(KycProblem.notConfigured);
    await pumpLiveLaunch(
      tester,
      Routes.withdraw,
      api: FakeApi().api(),
      kyc: kyc,
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Account verification isn’t set up yet. Please try again later.',
      ),
      findsOneWidget,
    );
    expect(find.byType(WithdrawSheet), findsNothing);
  });

  testWidgets('missing API service fails closed', (tester) async {
    await pumpLiveLaunch(
      tester,
      Routes.withdraw,
      api: FakeApi().api(),
      kyc: UnavailableKycService(),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('The identity check did not complete. Try again.'),
      findsOneWidget,
    );
    expect(find.byType(WithdrawSheet), findsNothing);
  });

  testWidgets('required tier must pass before withdrawal opens', (
    tester,
  ) async {
    final kyc = FakeKyc(
      const KycStatus(
        verified: true,
        tier: 1,
        requiredTier: 2,
        nextCheck: KycCheckKind.document,
      ),
    );
    await pumpLiveLaunch(
      tester,
      Routes.withdraw,
      api: FakeApi().api(),
      kyc: kyc,
    );
    await tester.pumpAndSettle();
    expect(find.byType(KycSheet), findsOneWidget);
    expect(find.byType(WithdrawSheet), findsNothing);
    kyc.current = const KycStatus(
      verified: true,
      tier: 2,
      requiredTier: 2,
      nextCheck: KycCheckKind.none,
      checks: {
        KycCheckKind.identity: KycCheckState.passed,
        KycCheckKind.bankMatch: KycCheckState.passed,
        KycCheckKind.amlIndividual: KycCheckState.passed,
        KycCheckKind.document: KycCheckState.passed,
      },
    );
    tester.widget<KycSheet>(find.byType(KycSheet)).onComplete!(kyc.current);
    await tester.pumpAndSettle();
    expect(find.byType(WithdrawSheet), findsOneWidget);
  });

  testWidgets('withdrawal completion rechecks status after a stale POST', (
    tester,
  ) async {
    const stale = KycStatus(
      verified: true,
      tier: 2,
      requiredTier: 2,
      nextCheck: KycCheckKind.none,
    );
    final kyc = FakeKyc(unverified);
    await pumpLiveLaunch(
      tester,
      Routes.withdraw,
      api: FakeApi().api(),
      kyc: kyc,
    );
    await tester.pumpAndSettle();
    kyc.current = unverified;
    tester.widget<KycSheet>(find.byType(KycSheet)).onComplete!(stale);
    await tester.pumpAndSettle();
    expect(kyc.reads, 2);
    expect(find.byType(WithdrawSheet), findsNothing);
    expect(find.byType(KycSheet), findsOneWidget);
  });

  testWidgets('withdrawal completion fails closed when fresh GET fails', (
    tester,
  ) async {
    const stale = KycStatus(
      verified: true,
      tier: 2,
      requiredTier: 2,
      nextCheck: KycCheckKind.none,
    );
    final kyc = FakeKyc(unverified);
    await pumpLiveLaunch(
      tester,
      Routes.withdraw,
      api: FakeApi().api(),
      kyc: kyc,
    );
    await tester.pumpAndSettle();
    kyc.failure = const KycRefused(KycProblem.unavailable);
    tester.widget<KycSheet>(find.byType(KycSheet)).onComplete!(stale);
    await tester.pumpAndSettle();
    expect(kyc.reads, 2);
    expect(find.byType(WithdrawSheet), findsNothing);
    expect(
      find.text('The identity check did not complete. Try again.'),
      findsOneWidget,
    );
  });

  testWidgets('successful sheet refresh clears a stale error', (tester) async {
    final kyc = FakeKyc(unverified)
      ..failure = const KycRefused(KycProblem.unavailable);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          kycServiceProvider.overrideWithValue(kyc),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(home: Scaffold(body: KycSheet())),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      find.text('The identity check did not complete. Try again.'),
      findsOneWidget,
    );
    kyc.failure = null;
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      find.text('The identity check did not complete. Try again.'),
      findsNothing,
    );
  });

  test('controller successful writes stop loading and advance steps', () async {
    const identity = KycStatus(nextCheck: KycCheckKind.identity);
    const document = unverified;
    const selfie = KycStatus(tier: 2, nextCheck: KycCheckKind.selfie);
    final kyc = FakeKyc(identity);
    final container = ProviderContainer(
      overrides: [
        kycServiceProvider.overrideWithValue(kyc),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);
    container.listen(kycControllerProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    kyc.current = document;
    await container
        .read(kycControllerProvider.notifier)
        .verify(
          const KycCheck(
            method: KycMethod.nin,
            number: '12345678901',
            firstName: 'Ada',
            lastName: 'Obi',
          ),
        );
    expect(container.read(kycControllerProvider).loading, isFalse);
    expect(container.read(kycControllerProvider).status, document);
    kyc.current = selfie;
    await container
        .read(kycControllerProvider.notifier)
        .upload(
          KycCheckKind.document,
          const KycEvidence(
            filename: 'id.png',
            bytes: [1],
            contentType: 'image/png',
          ),
        );
    final state = container.read(kycControllerProvider);
    expect(state.loading, isFalse);
    expect(state.status, selfie);
  });

  test('controller ignores superseded and disposed responses', () async {
    final first = Completer<KycStatus>();
    final second = Completer<KycStatus>();
    final third = Completer<KycStatus>();
    final kyc = _QueuedKyc(unverified, []);
    final container = ProviderContainer(
      overrides: [
        kycServiceProvider.overrideWithValue(kyc),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    container.listen(kycControllerProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    kyc.responses.addAll([first, second, third]);
    final old = container.read(kycControllerProvider.notifier).refresh();
    final latest = container.read(kycControllerProvider.notifier).refresh();
    const ready = KycStatus(
      verified: true,
      tier: 2,
      requiredTier: 2,
      nextCheck: KycCheckKind.none,
    );
    second.complete(ready);
    await latest;
    first.complete(unverified);
    await old;
    expect(container.read(kycControllerProvider).status, ready);
    final disposed = Completer<KycStatus>();
    kyc.responses.clear();
    kyc.fallback = disposed;
    final pending = container.read(kycControllerProvider.notifier).refresh();
    container.dispose();
    disposed.complete(unverified);
    await pending;
  });

  test('controller keeps verified gating status on refresh failure', () async {
    final kyc = FakeKyc(unverified);
    final container = ProviderContainer(
      overrides: [
        kycServiceProvider.overrideWithValue(kyc),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);
    container.listen(kycControllerProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    final ready = const KycStatus(
      verified: true,
      tier: 2,
      nextCheck: KycCheckKind.none,
    );
    kyc.current = ready;
    await container.read(kycControllerProvider.notifier).refresh();
    kyc.failure = const KycRefused(KycProblem.unavailable);
    await container.read(kycControllerProvider.notifier).refresh();
    final state = container.read(kycControllerProvider);
    expect(state.status, same(ready));
    expect(state.loading, isFalse);
  });

  test('controller keeps review and outage states unverified', () async {
    final kyc = FakeKyc(unverified);
    final container = ProviderContainer(
      overrides: [
        kycServiceProvider.overrideWithValue(kyc),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(kycControllerProvider, (_, _) {});
    addTearDown(subscription.close);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(kycControllerProvider).status, unverified);
    kyc.failure = const KycRefused(KycProblem.review);
    await container.read(kycControllerProvider.notifier).refresh();
    final state = container.read(kycControllerProvider);
    expect(state.error?.problem, KycProblem.review);
    expect(state.status, same(unverified));
  });
}
