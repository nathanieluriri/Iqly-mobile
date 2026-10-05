import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iqly_mobile/core/deadline.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/core/transitions.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/features/submissions/submission_widgets.dart'
    show SkeletonCard;
import 'package:iqly_mobile/features/wallet/activity_screen.dart';
import 'package:iqly_mobile/features/wallet/wallet_routes.dart';
import 'package:iqly_mobile/features/wallet/withdraw_sheet.dart';
import 'package:iqly_mobile/features/withdrawals/withdrawal_widgets.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/dock.dart';
import 'package:iqly_mobile/ui/timeline_row.dart';
import 'package:iqly_mobile/ui/wallet_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../golden/screens/app_harness.dart';
import '../golden/screens/wallet_harness.dart';

const _ms = Duration(milliseconds: 1);

void _reduce(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

/// The real router at [location] with motion on; tests read key frames
/// with pump.
Future<GoRouter> _pumpApp(
  WidgetTester tester,
  String location, {
  IqlyRepository? repository,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 54, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 54, bottom: 34);
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(signedInPrefs());
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      repositoryProvider.overrideWithValue(repository ?? WalletRepository()),
      clockProvider.overrideWithValue(() => figmaNow),
      ...walletOverrides(),
    ],
  );
  addTearDown(container.dispose);
  final router = buildRouter(initialLocation: location);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: buildTheme(), routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
  return router;
}

ModalRoute<dynamic> _routeOf(WidgetTester tester, Finder finder) =>
    ModalRoute.of(tester.element(finder))!;

class _HeldWalletRepository extends WalletRepository {
  final answer = Completer<void>();

  @override
  Future<List<LedgerEntry>> ledger() async {
    await answer.future;
    return super.ledger();
  }
}

Withdrawal _withdrawal({
  WithdrawalStatus status = WithdrawalStatus.pending,
  bool held = false,
  DateTime? approvedAt,
  DateTime? sentAt,
  DateTime? completedAt,
}) => Withdrawal(
  id: 'w3',
  amountKobo: 1000000,
  status: status,
  createdAt: figmaNow.subtract(const Duration(hours: 2, minutes: 1)),
  held: held,
  approvedAt: approvedAt,
  sentAt: sentAt,
  completedAt: completedAt,
);

void main() {
  group('Wallet motion (designer doc rev 55)', () {
    testWidgets('sheets rise 300 and drop 200', (tester) async {
      final router = await _pumpApp(tester, Routes.wallet);
      router.push(Routes.withdraw);
      await tester.pump();
      await tester.pump();
      final route = _routeOf(tester, find.byType(WithdrawSheet));
      expect(route.transitionDuration, IqDurations.screen);
      expect(route.reverseTransitionDuration, IqDurations.swap);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('pushes go 300 in and 240 back', (tester) async {
      final router = await _pumpApp(tester, Routes.wallet);
      router.push(activityPath());
      await tester.pump();
      await tester.pump();
      final route = _routeOf(tester, find.byType(ActivityScreen));
      expect(route.transitionDuration, IqDurations.screen);
      expect(route.reverseTransitionDuration, IqDurations.screenBack);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('the balance tabs crossfade the card 200, the dock stays', (
      tester,
    ) async {
      await _pumpApp(tester, Routes.wallet);
      await tester.tap(find.text('Earned'));
      await tester.pump();
      await tester.pump(IqDurations.swap ~/ 2);
      expect(find.text('₦15,000.00'), findsOneWidget);
      expect(find.text('₦65,000.00'), findsOneWidget);
      expect(find.byType(IqDock), findsOneWidget);
      await tester.pump(IqDurations.swap ~/ 2 + _ms);
      await tester.pump();
      expect(find.text('₦15,000.00'), findsNothing);
      expect(
        tester.widget<IqWalletCard>(find.byType(IqWalletCard)).balance,
        IqWalletCardBalance.earned,
      );
    });

    testWidgets('Activity tabs crossfade the list 200 under still chrome', (
      tester,
    ) async {
      await _pumpApp(tester, activityPath());
      await tester.tap(find.text('Rewards'));
      await tester.pump();
      await tester.pump(IqDurations.swap ~/ 2);
      expect(find.text('Pending'), findsOneWidget);
      await tester.pump(IqDurations.swap ~/ 2 + _ms);
      await tester.pump();
      expect(find.text('Pending'), findsNothing);
      expect(find.byType(ActivityScreen), findsOneWidget);
    });

    testWidgets('the skeleton shows on the first visit only', (tester) async {
      final repository = _HeldWalletRepository();
      final router = await _pumpApp(
        tester,
        Routes.wallet,
        repository: repository,
      );
      expect(find.byType(SkeletonCard), findsWidgets);
      repository.answer.complete();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.byType(SkeletonCard), findsNothing);
      expect(find.byType(IqWalletCard), findsOneWidget);

      router.go(Routes.home);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      router.go(Routes.wallet);
      await tester.pump();
      expect(find.byType(SkeletonCard), findsNothing);
      expect(find.byType(IqWalletCard), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('WithdrawalTimeline', () {
    Widget timeline(Withdrawal w, {bool reduced = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 358,
          child: WithdrawalTimeline(withdrawal: w, now: figmaNow),
        ),
      ),
    );

    IqTimelineRowState state(WidgetTester tester, String title) => tester
        .widget<IqTimelineRow>(find.widgetWithText(IqTimelineRow, title))
        .state;

    final chain = IqDurations.ink + IqDurations.mark;

    testWidgets('a held withdrawal waits on approval, then moves on once '
        'the dot has inked and the line has drawn', (tester) async {
      await tester.pumpWidget(timeline(_withdrawal(held: true)));
      await tester.pump(_ms * 1000);
      expect(state(tester, 'Awaiting approval'), IqTimelineRowState.current);
      await tester.pumpWidget(
        timeline(
          _withdrawal(
            held: true,
            status: WithdrawalStatus.processing,
            approvedAt: figmaNow,
          ),
        ),
      );
      expect(state(tester, 'Approved by iQLY'), IqTimelineRowState.done);
      await tester.pump(chain + _ms);
      expect(state(tester, 'Sent to your bank'), IqTimelineRowState.upcoming);
      await tester.pump(_ms * 2000);
    });

    testWidgets('steps that land together go one by one', (tester) async {
      await tester.pumpWidget(timeline(_withdrawal()));
      await tester.pump(_ms * 1000);
      expect(find.text('Awaiting approval'), findsNothing);
      await tester.pumpWidget(
        timeline(
          _withdrawal(
            status: WithdrawalStatus.completed,
            sentAt: figmaNow,
            completedAt: figmaNow,
          ),
        ),
      );
      expect(state(tester, 'Sent to your bank'), IqTimelineRowState.done);
      expect(state(tester, 'Arrived'), IqTimelineRowState.upcoming);
      await tester.pump(chain + _ms * 20);
      expect(state(tester, 'Arrived'), IqTimelineRowState.done);
      await tester.pump(_ms * 2000);
    });

    testWidgets('reduced motion: the new state at once', (tester) async {
      _reduce(tester);
      await tester.pumpWidget(timeline(_withdrawal(), reduced: true));
      await tester.pumpWidget(
        timeline(
          _withdrawal(
            status: WithdrawalStatus.completed,
            sentAt: figmaNow,
            completedAt: figmaNow,
          ),
          reduced: true,
        ),
      );
      await tester.pump();
      expect(state(tester, 'Arrived'), IqTimelineRowState.done);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('the failed step does not breathe', (tester) async {
      await tester.pumpWidget(
        timeline(_withdrawal(status: WithdrawalStatus.failed)),
      );
      await tester.pump(_ms * 1000);
      expect(state(tester, 'Failed at the bank'), IqTimelineRowState.current);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  test('the sheet scrim is the .5 brand scrim', () {
    expect(IqScrim.sheet.a, closeTo(0.5, 0.01));
  });
}
