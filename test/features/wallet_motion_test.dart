import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iqly_mobile/core/deadline.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/features/wallet/wallet_motion.dart';
import 'package:iqly_mobile/features/wallet/wallet_state.dart';
import 'package:iqly_mobile/features/withdrawals/withdrawal_widgets.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/timeline_row.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../golden/screens/app_harness.dart';
import '../golden/screens/wallet_harness.dart';

const _box = SizedBox(width: 100, height: 20);

void _reduce(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

double _dy(WidgetTester tester, Finder of) => tester
    .widget<Transform>(
      find.descendant(of: of, matching: find.byType(Transform)).first,
    )
    .transform
    .getTranslation()
    .y;

double _opacity(WidgetTester tester, Finder of) => tester
    .widget<Opacity>(
      find.descendant(of: of, matching: find.byType(Opacity)).first,
    )
    .opacity;

Withdrawal _withdrawal({
  WithdrawalStatus status = WithdrawalStatus.pending,
  DateTime? approvedAt,
  DateTime? sentAt,
  DateTime? completedAt,
}) => Withdrawal(
  id: 'w3',
  amountKobo: 1000000,
  status: status,
  createdAt: figmaNow.subtract(const Duration(hours: 2, minutes: 1)),
  approvedAt: approvedAt,
  sentAt: sentAt,
  completedAt: completedAt,
);

void main() {
  group('Cue', () {
    Widget beat({Duration at = Duration.zero}) => Choreography(
      length: WalletDurations.list,
      child: Cue(at: at, child: _box),
    );

    testWidgets('arrive: fades in and rises 12 over 260 ease-out', (
      tester,
    ) async {
      await _pump(tester, beat());
      final cue = find.byType(Cue);
      expect(_opacity(tester, cue), 0);
      expect(_dy(tester, cue), 12);
      await tester.pump(const Duration(milliseconds: 130));
      expect(_opacity(tester, cue), inExclusiveRange(0.5, 1));
      expect(_dy(tester, cue), inExclusiveRange(0, 6));
      await tester.pump(const Duration(milliseconds: 130));
      expect(_opacity(tester, cue), 1);
      expect(_dy(tester, cue), 0);
      await tester.pumpAndSettle();
    });

    testWidgets('a later slot waits its 40 ms turns', (tester) async {
      await _pump(tester, beat(at: WalletDurations.stagger * 5));
      await tester.pump(const Duration(milliseconds: 190));
      expect(_opacity(tester, find.byType(Cue)), 0);
      await tester.pump(const Duration(milliseconds: 140));
      expect(_opacity(tester, find.byType(Cue)), greaterThan(0));
      await tester.pumpAndSettle();
      expect(_opacity(tester, find.byType(Cue)), 1);
    });

    testWidgets('slots past the sixth render in place', (tester) async {
      await _pump(
        tester,
        Choreography(
          length: WalletDurations.list,
          child: Cue.arrive(6, const Text('seventh')),
        ),
      );
      expect(find.byType(Cue), findsNothing);
      expect(find.text('seventh'), findsOneWidget);
    });

    testWidgets('reduced motion: everything fades in together, no rise', (
      tester,
    ) async {
      _reduce(tester);
      await _pump(tester, beat(at: WalletDurations.stagger * 4));
      final fade = tester.widget<FadeTransition>(
        find.descendant(
          of: find.byType(Cue),
          matching: find.byType(FadeTransition),
        ),
      );
      expect(
        find.descendant(of: find.byType(Cue), matching: find.byType(Transform)),
        findsNothing,
      );
      await tester.pump(const Duration(milliseconds: 75));
      expect(fade.opacity.value, inExclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 75));
      expect(fade.opacity.value, 1);
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('a hidden tab waits to play until it is shown', (tester) async {
      Widget app(bool shown) => MaterialApp(
        home: TickerMode(enabled: shown, child: beat()),
      );
      await tester.pumpWidget(app(false));
      await tester.pump(const Duration(seconds: 1));
      expect(_opacity(tester, find.byType(Cue)), 0);
      await tester.pumpWidget(app(true));
      expect(_opacity(tester, find.byType(Cue)), 0);
      await tester.pump(const Duration(milliseconds: 130));
      expect(_opacity(tester, find.byType(Cue)), inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
    });
  });

  group('RollingText', () {
    Widget roll(String text) => RollingText(text, style: const TextStyle());

    testWidgets('shows the first text plainly, then rolls the change', (
      tester,
    ) async {
      await _pump(tester, roll('₦12,500'));
      expect(find.text('₦12,500'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);

      await _pump(tester, roll('₦7,500'));
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.text('₦'), findsOneWidget);
      expect(find.text(',500'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('₦7,500'), findsOneWidget);
      expect(find.text('7'), findsNothing);
    });

    testWidgets('waits while hidden and rolls when shown', (tester) async {
      Widget app(String text, bool shown) => MaterialApp(
        home: TickerMode(enabled: shown, child: roll(text)),
      );
      await tester.pumpWidget(app('₦12,500', true));
      await tester.pumpWidget(app('₦7,500', false));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('₦12,500'), findsOneWidget);
      await tester.pumpWidget(app('₦7,500', true));
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.text('7'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('₦7,500'), findsOneWidget);
    });

    testWidgets('reduced motion: a cut', (tester) async {
      _reduce(tester);
      await _pump(tester, roll('₦12,500'));
      await _pump(tester, roll('₦7,500'));
      await tester.pump();
      expect(find.text('₦7,500'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('LoadingGate', () {
    Widget gate(bool loading, {bool keep = false}) => LoadingGate(
      loading: loading,
      keepSkeleton: keep,
      skeleton: const Text('skeleton'),
      child: const Text('content'),
    );

    testWidgets('data inside 300 goes straight to the content', (tester) async {
      await _pump(tester, gate(true));
      expect(find.text('skeleton'), findsNothing);
      await tester.pump(const Duration(milliseconds: 200));
      await _pump(tester, gate(false));
      expect(find.text('content'), findsOneWidget);
      expect(find.text('skeleton'), findsNothing);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('skeleton'), findsNothing);
    });

    testWidgets('the skeleton shows after 300 and stays at least 600', (
      tester,
    ) async {
      await _pump(tester, gate(true));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('skeleton'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      await _pump(tester, gate(false));
      expect(find.text('content'), findsNothing);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('content'), findsOneWidget);
      expect(find.text('skeleton'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('skeleton'), findsNothing);
    });

    testWidgets('a retry keeps the skeleton it already shows', (tester) async {
      await _pump(tester, gate(false, keep: true));
      await _pump(tester, gate(true, keep: true));
      expect(find.text('skeleton'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      await _pump(tester, gate(false, keep: true));
      await tester.pumpAndSettle();
      expect(find.text('content'), findsOneWidget);
    });
  });

  group('ExpandIn', () {
    testWidgets('opens its slot, then the row arrives', (tester) async {
      await _pump(tester, const ExpandIn(child: _box));
      final size = tester.widget<SizeTransition>(find.byType(SizeTransition));
      expect(size.sizeFactor.value, 0);
      await tester.pump(const Duration(milliseconds: 240));
      expect(size.sizeFactor.value, 1);
      expect(_opacity(tester, find.byType(ExpandIn)), 0);
      await tester.pump(const Duration(milliseconds: 130));
      expect(_opacity(tester, find.byType(ExpandIn)), inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(_opacity(tester, find.byType(ExpandIn)), 1);
    });

    testWidgets('reduced motion: it fades in', (tester) async {
      _reduce(tester);
      await _pump(tester, const ExpandIn(child: _box));
      expect(find.byType(SizeTransition), findsNothing);
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('pages', () {
    Future<GoRouter> app(WidgetTester tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (context, state) => const Text('home')),
          GoRoute(
            path: '/push',
            pageBuilder: (context, state) => walletPushPage<void>(
              context,
              state,
              const SizedBox.expand(key: ValueKey('pushed')),
            ),
          ),
          GoRoute(
            path: '/sheet',
            pageBuilder: (context, state) => walletSheetPage<void>(
              context,
              state,
              const SizedBox(
                key: ValueKey('sheet'),
                height: 400,
                width: double.infinity,
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      return router;
    }

    double left(WidgetTester tester) =>
        tester.getTopLeft(find.byKey(const ValueKey('pushed'))).dx;

    testWidgets('push: in from 24 over 300 ease-out, back over 240', (
      tester,
    ) async {
      final router = await app(tester);
      router.push('/push');
      await tester.pump();
      await tester.pump();
      expect(left(tester), closeTo(24, .5));
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        left(tester),
        closeTo(24 * (1 - WalletCurves.easeOut.transform(.5)), .5),
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(left(tester), 0);
      router.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(left(tester), greaterThan(0));
      await tester.pump(const Duration(milliseconds: 240));
      expect(find.byKey(const ValueKey('pushed')), findsNothing);
    });

    testWidgets('reduced motion: push crossfades in place over 150', (
      tester,
    ) async {
      _reduce(tester);
      final router = await app(tester);
      router.push('/push');
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 75));
      expect(left(tester), 0);
      await tester.pump(const Duration(milliseconds: 75));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('sheet: rises from the bottom edge over 300, drops on close', (
      tester,
    ) async {
      final router = await app(tester);
      router.push('/sheet');
      await tester.pump();
      await tester.pump();
      double top() => tester.getTopLeft(find.byKey(const ValueKey('sheet'))).dy;
      expect(top(), closeTo(844, .5));
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        top(),
        closeTo(444 + 400 * (1 - WalletCurves.easeOut.transform(.5)), .5),
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(top(), 444);
      router.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(top(), greaterThan(444));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const ValueKey('sheet')), findsNothing);
    });

    testWidgets('reduced motion: the sheet fades in place', (tester) async {
      _reduce(tester);
      final router = await app(tester);
      router.push('/sheet');
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 75));
      expect(tester.getTopLeft(find.byKey(const ValueKey('sheet'))).dy, 444);
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.hasRunningAnimations, isFalse);
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

    testWidgets(
      'a step completes, then the next dot takes the ring (ink + draw)',
      (tester) async {
        await tester.pumpWidget(timeline(_withdrawal()));
        await tester.pump(const Duration(seconds: 1));
        expect(state(tester, 'Awaiting approval'), IqTimelineRowState.current);

        await tester.pumpWidget(
          timeline(
            _withdrawal(
              status: WithdrawalStatus.processing,
              approvedAt: figmaNow,
            ),
          ),
        );
        expect(state(tester, 'Approved by iQLY'), IqTimelineRowState.done);
        expect(state(tester, 'Sent to your bank'), IqTimelineRowState.upcoming);
        await tester.pump(const Duration(milliseconds: 400));
        expect(state(tester, 'Sent to your bank'), IqTimelineRowState.upcoming);
        await tester.pump(const Duration(milliseconds: 40));
        expect(state(tester, 'Sent to your bank'), IqTimelineRowState.current);
        await tester.pump(const Duration(seconds: 2));
      },
    );

    testWidgets('steps that land together go one by one', (tester) async {
      await tester.pumpWidget(timeline(_withdrawal()));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(
        timeline(
          _withdrawal(
            status: WithdrawalStatus.completed,
            approvedAt: figmaNow,
            sentAt: figmaNow,
            completedAt: figmaNow,
          ),
        ),
      );
      expect(state(tester, 'Sent to your bank'), IqTimelineRowState.upcoming);
      await tester.pump(const Duration(milliseconds: 440));
      expect(state(tester, 'Sent to your bank'), IqTimelineRowState.done);
      expect(state(tester, 'Arrived'), IqTimelineRowState.upcoming);
      await tester.pump(const Duration(milliseconds: 440));
      expect(state(tester, 'Arrived'), IqTimelineRowState.done);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('reduced motion: the new state at once', (tester) async {
      _reduce(tester);
      await tester.pumpWidget(timeline(_withdrawal(), reduced: true));
      await tester.pumpWidget(
        timeline(
          _withdrawal(
            status: WithdrawalStatus.completed,
            approvedAt: figmaNow,
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
      await tester.pump(const Duration(seconds: 1));
      expect(state(tester, 'Failed at the bank'), IqTimelineRowState.current);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  testWidgets('the Wallet rolls a change it did not see, once back in view', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(signedInPrefs());
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        repositoryProvider.overrideWithValue(WalletRepository()),
        clockProvider.overrideWithValue(() => figmaNow),
        ...walletOverrides(),
      ],
    );
    addTearDown(container.dispose);
    final router = buildRouter(initialLocation: Routes.wallet);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: buildTheme(), routerConfig: router),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('₦12,500'), findsOneWidget);

    router.push(Routes.withdraw);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    container
        .read(walletProvider.notifier)
        .add(RequestedWalletRepository.requested);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('₦12,500'), findsOneWidget);

    router.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('₦12,500'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.text('7'), findsOneWidget);
    expect(find.text(',500'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('₦7,500'), findsOneWidget);
    expect(find.text('ON HOLD · 2 PENDING'), findsOneWidget);
  });
}
