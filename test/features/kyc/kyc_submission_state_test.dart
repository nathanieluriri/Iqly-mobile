import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/deadline.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/kyc_service.dart';
import 'package:iqly_mobile/features/kyc/kyc_controller.dart';
import 'package:iqly_mobile/features/kyc/kyc_nudge.dart';
import 'package:iqly_mobile/features/kyc/kyc_sheet.dart';
import 'package:iqly_mobile/ui/button.dart';
import 'package:iqly_mobile/ui/segmented.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _KycService implements KycService {
  KycStatus current;
  KycRefused? failure;
  KycCheck? sent;

  _KycService(this.current);

  @override
  Future<KycStatus> status() async {
    if (failure != null) throw failure!;
    return current;
  }

  @override
  Future<KycStatus> verify(KycCheck check) async {
    sent = check;
    return current;
  }

  @override
  Future<KycStatus> upload(KycCheckKind check, KycEvidence file) async =>
      current;
}

class _BlockingKyc extends _KycService {
  _BlockingKyc(super.current);

  final next = Completer<KycStatus>();
  var calls = 0;

  @override
  Future<KycStatus> status() {
    calls++;
    return calls == 1 ? super.status() : next.future;
  }
}

KycStatus _status({
  int tier = 0,
  bool verified = false,
  int requiredTier = 1,
  KycMethod? method,
  KycCheckKind nextCheck = KycCheckKind.identity,
  Map<KycCheckKind, KycCheckState> checks = const {},
}) => KycStatus(
  tier: tier,
  verified: verified,
  requiredTier: requiredTier,
  method: method,
  nextCheck: nextCheck,
  checks: checks,
);

void main() {
  test(
    'C1 contributors can submit even when withdrawal needs a higher tier',
    () {
      final status = _status(
        tier: 1,
        verified: true,
        requiredTier: 3,
        nextCheck: KycCheckKind.document,
      );
      expect(status.canSubmit, isTrue);
      expect(status.canWithdraw, isFalse);
      expect(_status().canSubmit, isFalse);
    },
  );

  test('tier one is NIN-only even for a legacy BVN status', () {
    expect(_status(requiredTier: 1, method: KycMethod.bvn).ninOnly, isTrue);
    expect(_status(requiredTier: 2, method: KycMethod.bvn).ninOnly, isFalse);
  });

  test('Discover KYC copy covers submission and withdrawal requirements', () {
    expect(
      kycNudgeCopy(status: _status(), surface: KycNudgeSurface.discover)?.title,
      'Verify to submit and withdraw',
    );
    expect(
      kycNudgeCopy(
        status: _status(
          tier: 1,
          verified: true,
          nextCheck: KycCheckKind.none,
          checks: const {
            KycCheckKind.identity: KycCheckState.passed,
            KycCheckKind.bankMatch: KycCheckState.passed,
            KycCheckKind.amlIndividual: KycCheckState.passed,
          },
        ),
        surface: KycNudgeSurface.discover,
      ),
      isNull,
    );
    expect(
      kycNudgeCopy(
        status: _status(
          tier: 1,
          verified: true,
          requiredTier: 2,
          nextCheck: KycCheckKind.document,
        ),
        surface: KycNudgeSurface.discover,
      )?.title,
      'Verify to withdraw',
    );
  });

  test('KYC errors remain visible instead of disappearing', () {
    expect(
      kycNudgeCopy(
        error: const KycRefused(KycProblem.unavailable),
        surface: KycNudgeSurface.discover,
      )?.title,
      'Verification status unavailable',
    );
  });

  test('controller failure keeps the last good status and fetchedAt', () async {
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime(2026, 11, 27, 12);
    final service = _KycService(_status(tier: 1, verified: true));
    final container = ProviderContainer(
      overrides: [
        kycServiceProvider.overrideWithValue(service),
        sharedPreferencesProvider.overrideWithValue(prefs),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    container.listen(kycControllerProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    final before = container.read(kycControllerProvider);
    expect(before.fetchedAt, now);
    service.failure = const KycRefused(KycProblem.unavailable);
    await container.read(kycControllerProvider.notifier).refresh(force: true);
    final after = container.read(kycControllerProvider);
    expect(after.status, before.status);
    expect(after.fetchedAt, before.fetchedAt);
    expect(after.error?.problem, KycProblem.unavailable);
  });

  test('account changes clear the previous contributor KYC status', () async {
    SharedPreferences.setMockInitialValues({
      'session.signedIn': true,
      'session.userId': 'u1',
    });
    final prefs = await SharedPreferences.getInstance();
    final service = _BlockingKyc(_status(tier: 1, verified: true));
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        kycServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    container.listen(kycControllerProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    expect(container.read(kycControllerProvider).status?.canSubmit, isTrue);
    await container.read(sessionProvider.notifier).setUserId('u2');
    await Future<void>.delayed(Duration.zero);
    final state = container.read(kycControllerProvider);
    expect(state.status, isNull);
    expect(state.loading, isTrue);
    expect(service.calls, 2);
  });

  testWidgets('tier one hides BVN and forces a legacy BVN status to NIN', (
    tester,
  ) async {
    final service = _KycService(
      _status(requiredTier: 1, method: KycMethod.bvn),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [kycServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          home: Scaffold(
            body: KycSheet(
              initialStatus: _status(requiredTier: 1, method: KycMethod.bvn),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(IqSegmented), findsNothing);
    expect(find.text('BVN'), findsNothing);
    expect(find.text('NIN'), findsOneWidget);
    await tester.enterText(find.byType(EditableText).first, '12345678901');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).at(0), 'Ada');
    await tester.enterText(find.byType(EditableText).at(1), 'Obi');
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(IqButton, 'Verify identity'));
    await tester.pumpAndSettle();
    expect(service.sent?.method, KycMethod.nin);
  });

  testWidgets('tier two keeps the BVN option', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: KycSheet(
              initialStatus: _status(
                requiredTier: 2,
                method: KycMethod.bvn,
                nextCheck: KycCheckKind.identity,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(IqSegmented), findsOneWidget);
    expect(find.text('BVN'), findsNWidgets(2));
  });
}
