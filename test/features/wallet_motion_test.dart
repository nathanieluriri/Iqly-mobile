import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iqly_mobile/core/deadline.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/data/wallet_service.dart';
import 'package:iqly_mobile/features/wallet/select_bank_screen.dart';
import 'package:iqly_mobile/features/wallet/wallet_routes.dart';
import 'package:iqly_mobile/features/wallet/wallet_state.dart';
import 'package:iqly_mobile/features/wallet/withdraw_sheet.dart';
import 'package:iqly_mobile/features/wallet/withdrawal_pending_screen.dart';
import 'package:iqly_mobile/features/withdrawals/withdrawal_widgets.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/activity_row.dart';
import 'package:iqly_mobile/ui/balance_hero.dart';
import 'package:iqly_mobile/ui/banner.dart';
import 'package:iqly_mobile/ui/field.dart';
import 'package:iqly_mobile/ui/highlight.dart';
import 'package:iqly_mobile/ui/list_row.dart';
import 'package:iqly_mobile/ui/receipt_card.dart';
import 'package:iqly_mobile/ui/timeline_row.dart';
import 'package:iqly_mobile/ui/top_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iqly_mobile/data/activations_service.dart';

import '../golden/screens/app_harness.dart';
import '../golden/screens/wallet_harness.dart';
import 'entry_harness.dart' show recordHaptics;

const _ms = Duration(milliseconds: 1);
const _commit = 'HapticFeedbackType.lightImpact';
const _success = 'HapticFeedbackType.successNotification';

double _eo(double t) => IqCurves.easeOut.transform(t);
double _ei(double t) => IqCurves.easeIn.transform(t);

void _reduce(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

/// The real router at [location], motion on unless [reduced], the clock at
/// the Figma 9:41. It never settles (the BalanceHero wash loops), so tests
/// read their key frames with pump.
Future<(ProviderContainer, GoRouter)> _pumpApp(
  WidgetTester tester,
  String location, {
  IqlyRepository? repository,
  DemoWalletService? wallet,
  bool reduced = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 54, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 54, bottom: 34);
  addTearDown(tester.view.reset);
  if (reduced) _reduce(tester);
  SharedPreferences.setMockInitialValues(signedInPrefs());
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      repositoryProvider.overrideWithValue(repository ?? WalletRepository()),
      clockProvider.overrideWithValue(() => figmaNow),
      activationsServiceProvider.overrideWithValue(
        DemoActivationsService(
          clock: () => figmaNow,
          load: Duration.zero,
          delay: Duration.zero,
        ),
      ),
      ...walletOverrides(wallet: wallet),
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
  // The demo data lands on the next frame, as it would on a device.
  await tester.pump();
  return (container, router);
}

/// Pumps [total] as 16 ms frames, as a device draws them, so what starts
/// once seen starts on time.
Future<void> _frames(WidgetTester tester, Duration total) async {
  const frame = Duration(milliseconds: 16);
  var left = total;
  while (left > Duration.zero) {
    final step = left < frame ? left : frame;
    await tester.pump(step);
    left -= step;
  }
}

/// The product of the fades between [of] and the screen.
double _opacity(WidgetTester tester, Finder of) {
  var opacity = 1.0;
  for (final widget in tester.widgetList(
    find.ancestor(
      of: of,
      matching: find.byWidgetPredicate(
        (w) => w is FadeTransition || w is Opacity,
      ),
    ),
  )) {
    opacity *= widget is FadeTransition
        ? widget.opacity.value
        : (widget as Opacity).opacity;
  }
  return opacity;
}

/// The arrive fade of the stagger slot [of] sits in.
double _arrive(WidgetTester tester, Finder of) => tester
    .widget<FadeTransition>(
      find
          .descendant(
            of: find.ancestor(of: of, matching: find.byType(StaggerItem)).first,
            matching: find.byType(FadeTransition),
          )
          .first,
    )
    .opacity
    .value;

/// A ledger that answers when the test says so.
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
  group('Wallet', () {
    testWidgets('the hero, the Activity title and the rows arrive 40 ms '
        'apart, once', (tester) async {
      await _pumpApp(tester, Routes.wallet);
      final hero = find.byType(IqBalanceHero);
      final title = find.text('Activity');
      final row = find.byType(IqActivityRowWithdrawal).first;
      expect(_arrive(tester, hero), 0);
      await tester.pump(_ms * 130);
      expect(_arrive(tester, hero), closeTo(_eo(130 / 260), 0.01));
      expect(_arrive(tester, title), closeTo(_eo(90 / 260), 0.01));
      expect(_arrive(tester, row), closeTo(_eo(50 / 260), 0.01));
      await tester.pump(_ms * 331);
      expect(_arrive(tester, row), 1);

      await tester.tap(find.text('Discover'));
      await tester.pump();
      await tester.pump(_ms * 300);
      await tester.tap(find.text('Wallet').last);
      await tester.pump();
      expect(_arrive(tester, hero), 1);
      expect(_arrive(tester, row), 1);
    });

    testWidgets('reduced motion: everything fades in together, 150', (
      tester,
    ) async {
      await _pumpApp(tester, Routes.wallet, reduced: true);
      await tester.pump(_ms * 75);
      final hero = find.byType(IqBalanceHero);
      final row = find.byType(IqActivityRowWithdrawal).first;
      expect(_arrive(tester, hero), closeTo(_eo(0.5), 0.01));
      expect(_arrive(tester, row), closeTo(_eo(0.5), 0.01));
      expect(tester.getTopLeft(hero).dy, 150);
      await tester.pump(_ms * 76);
      expect(_arrive(tester, row), 1);
    });

    testWidgets('a slow first load: nothing for 300, the skeletons for at '
        'least 600, then the wallet arrives over them', (tester) async {
      final repository = _HeldWalletRepository();
      await _pumpApp(tester, Routes.wallet, repository: repository);
      await tester.pump(_ms * 299);
      expect(find.byType(IqBanner), findsNothing);
      expect(find.byType(IqBalanceHero), findsNothing);
      await tester.pump(_ms);
      expect(find.byType(IqBanner), findsOneWidget);
      await tester.pump(_ms * 100);
      repository.answer.complete();
      await tester.pump();
      await tester.pump(_ms * 499);
      expect(find.byType(IqBalanceHero), findsNothing);
      await tester.pump(_ms * 61);
      expect(find.byType(IqBalanceHero), findsOneWidget);
      expect(find.byType(IqBanner), findsOneWidget);
      await tester.pump(_ms * 200);
      expect(find.byType(IqBanner), findsNothing);
    });

    testWidgets('failed: the banner slides down over the skeletons; Try '
        'again slides it away, keeps them, and the wallet takes over', (
      tester,
    ) async {
      final haptics = recordHaptics(tester);
      final repository = FailingWalletRepository();
      await _pumpApp(tester, Routes.wallet, repository: repository);
      double banner() => tester
          .widget<SizeTransition>(
            find.descendant(
              of: find.byType(IqBanner),
              matching: find.byType(SizeTransition),
            ),
          )
          .sizeFactor
          .value;
      expect(banner(), 0);
      await tester.pump(_ms * 120);
      expect(banner(), closeTo(_eo(0.5), 0.01));
      await tester.pump(_ms * 700);
      expect(banner(), 1);

      repository.fail = false;
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump(_ms * 90);
      expect(banner(), closeTo(_eo(0.5), 0.01));
      expect(find.byType(IqBalanceHero), findsNothing);
      await tester.pump(_ms * 61);
      expect(find.byType(IqBalanceHero), findsOneWidget);
      await tester.pump(_ms * 200);
      expect(find.byType(IqBanner), findsNothing);
      expect(haptics, isEmpty);
    });

    testWidgets('a retry that fails again brings the banner back with the '
        'error haptic', (tester) async {
      final haptics = recordHaptics(tester);
      final repository = FailingWalletRepository();
      await _pumpApp(tester, Routes.wallet, repository: repository);
      await tester.pump(_ms * 800);
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump(_ms * 300);
      expect(
        find.text('Couldn’t load. Check your connection.'),
        findsOneWidget,
      );
      expect(haptics, ['HapticFeedbackType.mediumImpact']);
    });

    testWidgets('Withdraw rises the sheet over its .5 scrim in 300 ease-out; '
        'the amount takes the keyboard once it has risen', (tester) async {
      final haptics = recordHaptics(tester);
      await _pumpApp(tester, Routes.wallet);
      await tester.pump(_ms * 500);
      await tester.tap(find.text('Withdraw'));
      await tester.pump();
      expect(haptics, [_commit]);
      double top() => tester.getTopLeft(find.byType(WithdrawSheet)).dy;
      double scrim() => tester
          .widget<ColoredBox>(
            find
                .descendant(
                  of: find.byType(ModalBarrier),
                  matching: find.byType(ColoredBox),
                )
                .last,
          )
          .color
          .a;
      bool amountFocused() => tester
          .widget<EditableText>(
            find.descendant(
              of: find.byWidgetPredicate(
                (w) => w is IqField && w.label == 'Amount',
              ),
              matching: find.byType(EditableText),
            ),
          )
          .focusNode
          .hasFocus;

      await tester.pump(_ms * 150);
      final mid = top();
      expect(scrim(), closeTo(IqOpacity.sheetScrim * _eo(0.5), 0.01));
      expect(amountFocused(), isFalse);
      await tester.pump(_ms * 151);
      final rest = top();
      expect(mid, closeTo(rest + (844 - rest) * (1 - _eo(0.5)), 0.5));
      expect(scrim(), closeTo(IqOpacity.sheetScrim, 0.01));
      await tester.pump();
      expect(amountFocused(), isTrue);
    });

    testWidgets('To pushes Select bank over the sheet, from 24 in 300', (
      tester,
    ) async {
      await _pumpApp(tester, withdrawLocation(amountKobo: 500000));
      await tester.pump(_ms * 500);
      await tester.tap(find.text('Access Bank ••6789 · ADAEZE OKAFOR'));
      await tester.pump();
      await tester.pump(_ms * 150);
      expect(
        tester.getTopLeft(find.byType(SelectBankScreen)).dx,
        closeTo(24 * (1 - _eo(0.5)), 0.5),
      );
      await tester.pump(_ms * 151);
      expect(tester.getTopLeft(find.byType(SelectBankScreen)).dx, 0);
    });

    testWidgets('a withdrawal: the commit haptic, the sheet drops with the '
        'keypad, then the pending moment pushes with the success haptic and '
        'its Highlight starts at +240 (spec 7.1)', (tester) async {
      final haptics = recordHaptics(tester);
      await _pumpApp(tester, withdrawLocation(amountKobo: 500000));
      await tester.pump(_ms * 500);
      expect(tester.testTextInput.isVisible, isTrue);
      final sheet = find.byType(WithdrawSheet);
      final rest = tester.getTopLeft(sheet).dy;
      await tester.tap(find.text('Withdraw').last);
      await tester.pump();
      await tester.pump();
      expect(haptics, [_commit]);
      expect(tester.testTextInput.isVisible, isFalse);

      // Only the sheet moves: 200 ease-in, the pending moment waiting.
      final pending = find.byType(WithdrawalPendingScreen, skipOffstage: false);
      await tester.pump(_ms * 100);
      expect(tester.getTopLeft(sheet).dy, greaterThan(rest));
      expect(pending, findsNothing);
      var waited = 100;
      while (haptics.length == 1 && waited < 400) {
        expect(pending, findsNothing);
        await tester.pump(_ms * 10);
        waited += 10;
      }
      expect(haptics, [_commit, _success]);
      expect(sheet, findsNothing);
      expect(waited, inInclusiveRange(200, 240));
      await tester.pump();
      expect(pending, findsOneWidget);

      final page = find.byType(WithdrawalPendingScreen);
      final title = find.text('Withdrawal pending');
      final highlight = find.byType(IqHighlight);
      await tester.pump();
      expect(tester.getTopLeft(page).dx, closeTo(24, 1));
      await tester.pump(_ms * 79);
      expect(_opacity(tester, title), 0);
      await tester.pump(_ms * 100);
      expect(_opacity(tester, title), greaterThan(0));
      final before = tester.element(highlight);
      await tester.pump(_ms * 62);
      expect(tester.element(highlight), isNot(same(before)));
      expect(_opacity(tester, highlight), greaterThan(0));
    });

    testWidgets('reduced motion: the pending moment fades in as the sheet '
        'fades out, with the success haptic', (tester) async {
      final haptics = recordHaptics(tester);
      await _pumpApp(
        tester,
        withdrawLocation(amountKobo: 500000),
        reduced: true,
      );
      await tester.pump(_ms * 500);
      await tester.tap(find.text('Withdraw').last);
      await tester.pump();
      await tester.pump();
      expect(find.byType(WithdrawalPendingScreen), findsOneWidget);
      expect(haptics, [_success]);
      await tester.pump(_ms * 151);
      await tester.pump();
      expect(find.byType(WithdrawSheet), findsNothing);
      expect(tester.getTopLeft(find.byType(WithdrawalPendingScreen)).dx, 0);
    });

    testWidgets('back on the Wallet after a withdrawal: the figures and the '
        'count roll once, the new row opens its slot, then arrives', (
      tester,
    ) async {
      final (container, router) = await _pumpApp(tester, Routes.wallet);
      await tester.pump(_ms * 500);
      expect(find.text('₦12,500'), findsOneWidget);

      router.push(Routes.withdraw);
      await tester.pump();
      await tester.pump(_ms * 500);
      container
          .read(walletProvider.notifier)
          .add(RequestedWalletRepository.requested);
      await tester.pump(_ms * 500);
      expect(find.text('₦12,500'), findsOneWidget);

      router.pop();
      await tester.pump();
      await tester.pump(_ms * 100);
      expect(find.text('₦12,500'), findsOneWidget);
      await tester.pump(_ms * 140);
      await tester.pump(_ms * 80);
      expect(find.text('₦12,500'), findsOneWidget);
      expect(find.text('₦7,500'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);

      double slot() => tester
          .widget<SizeTransition>(
            find.ancestor(
              of: find.text('Just now'),
              matching: find.byType(SizeTransition),
            ),
          )
          .sizeFactor
          .value;
      // The new row's slot opens from the frame after it turns up.
      expect(slot(), 0);
      await tester.pump(_ms * 120);
      expect(slot(), closeTo(_eo(0.5), 0.01));
      expect(find.text('₦7,500'), findsOneWidget);
      expect(find.text('₦12,500'), findsNothing);
      expect(find.text('ON HOLD · 2 PENDING'), findsOneWidget);
      await tester.pump(_ms * 121);
      expect(slot(), 1);
      expect(_opacity(tester, find.text('Just now')), 0);
      await tester.pump();
      await tester.pump(_ms * 261);
      expect(_opacity(tester, find.text('Just now')), 1);
    });

    testWidgets('reduced motion: the figures cut to the new value', (
      tester,
    ) async {
      final (container, router) = await _pumpApp(
        tester,
        Routes.wallet,
        reduced: true,
      );
      await tester.pumpAndSettle();
      router.push(Routes.withdraw);
      await tester.pumpAndSettle();
      container
          .read(walletProvider.notifier)
          .add(RequestedWalletRepository.requested);
      router.pop();
      await tester.pump();
      await tester.pump(_ms * 151);
      await tester.pump();
      expect(find.text('₦7,500'), findsOneWidget);
      expect(find.text('₦12,500'), findsNothing);
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('withdrawals', () {
    testWidgets('tracker: the receipt arrives and draws its tear line, the '
        'steps stand still and Awaiting approval breathes', (tester) async {
      await _pumpApp(tester, withdrawalPath('w3'));
      final receipt = find.byType(IqReceiptCard);
      expect(_arrive(tester, receipt), 0);
      await _frames(tester, _ms * 130);
      expect(_arrive(tester, receipt), closeTo(_eo(0.5), 0.01));
      expect(
        find.ancestor(
          of: find.byType(IqTimelineRow).first,
          matching: find.byType(StaggerItem),
        ),
        findsNothing,
      );
      double ring() => tester
          .widget<ScaleTransition>(
            find.descendant(
              of: find.widgetWithText(IqTimelineRow, 'Awaiting approval'),
              matching: find.byType(ScaleTransition),
            ),
          )
          .scale
          .value;
      await _frames(tester, _ms * 400);
      expect(ring(), greaterThan(1));
      final tear = tester.widget<ClipRect>(
        find.descendant(of: receipt, matching: find.byType(ClipRect)).last,
      );
      expect(tear.clipBehavior, Clip.none);
    });

    testWidgets('a payout landing: the chain plays and the tag crossfades '
        'to Completed, with no haptic', (tester) async {
      final haptics = recordHaptics(tester);
      await _pumpApp(
        tester,
        withdrawalPath('w3'),
        wallet: instantWallet(payoutStep: const Duration(seconds: 1)),
      );
      for (var step = 0; step < 3; step++) {
        await tester.pump(_ms * 1000);
      }
      await tester.pump(_ms * 75);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      await tester.pump(_ms * 76);
      expect(find.text('Pending'), findsNothing);
      await tester.pump(_ms * 1500);
      expect(
        tester
            .widget<IqTimelineRow>(
              find.widgetWithText(IqTimelineRow, 'Arrived'),
            )
            .state,
        IqTimelineRowState.done,
      );
      expect(haptics, isEmpty);
    });

    testWidgets('failed: the banner slides down, the failed step does not '
        'breathe; Check bank details commits', (tester) async {
      final haptics = recordHaptics(tester);
      await _pumpApp(tester, withdrawalPath('w1'));
      await tester.pump(_ms * 120);
      expect(
        tester
            .widget<SizeTransition>(
              find.descendant(
                of: find.byType(IqBanner),
                matching: find.byType(SizeTransition),
              ),
            )
            .sizeFactor
            .value,
        closeTo(_eo(0.5), 0.01),
      );
      await tester.pump(_ms * 600);
      expect(
        tester
            .widget<ScaleTransition>(
              find.descendant(
                of: find.widgetWithText(IqTimelineRow, 'Failed at the bank'),
                matching: find.byType(ScaleTransition),
              ),
            )
            .scale
            .value,
        1,
      );
      await tester.tap(find.text('Check bank details'));
      await tester.pump();
      await tester.pump(_ms * 300);
      expect(haptics, [_commit]);
      expect(find.byType(SelectBankScreen), findsOneWidget);
    });

    testWidgets('failed to Select bank and back: the back button holds while '
        'the titles cross (spec 4.3)', (tester) async {
      await _pumpApp(tester, withdrawalPath('w1'));
      await tester.pump(_ms * 800);
      final bar = tester.getTopLeft(find.byType(IqTopBar));

      await tester.tap(find.text('Check bank details'));
      await tester.pump();
      await tester.pump();
      await tester.pump(_ms * 60);
      expect(tester.getTopLeft(find.byType(IqTopBar).last), bar);
      expect(
        _opacity(tester, find.text('Withdrawal').last),
        closeTo(1 - _ei(0.5), 0.02),
      );
      expect(
        tester
            .renderObject<RenderParagraph>(find.text('Withdrawal').last)
            .text
            .style
            ?.decoration,
        isNull,
      );
      await tester.pump(_ms * 60);
      expect(_opacity(tester, find.text('Withdrawal').last), closeTo(0, 0.001));
      await tester.pump(_ms * 300);
      expect(find.byType(SelectBankScreen), findsOneWidget);
      expect(tester.getTopLeft(find.byType(IqTopBar)), bar);

      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pump();
      await tester.pump();
      await tester.pump(_ms * 48);
      expect(tester.getTopLeft(find.byType(IqTopBar).last), bar);
      expect(
        _opacity(tester, find.text('Select bank').last),
        closeTo(1 - _ei(0.5), 0.02),
      );
      await tester.pump(_ms * 300);
      expect(find.byType(SelectBankScreen), findsNothing);
      expect(find.text('Withdrawal'), findsOneWidget);
    });

    testWidgets('Home after payout: the payout row is the first to arrive, '
        'no haptic', (tester) async {
      final haptics = recordHaptics(tester);
      await _pumpApp(
        tester,
        Routes.home,
        repository: PaidOutWalletRepository(),
      );
      final row = find.widgetWithText(IqListRow, '₦10,000.00 completed');
      await tester.pump();
      expect(_opacity(tester, row), 0);
      await _frames(tester, _ms * 160);
      expect(_opacity(tester, row), inExclusiveRange(0.3, 0.9));
      await _frames(tester, _ms * 300);
      expect(_opacity(tester, row), 1);
      expect(haptics, isEmpty);
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

    testWidgets('a step completes, then the next dot takes the ring once the '
        'dot has inked and the line has drawn', (tester) async {
      await tester.pumpWidget(timeline(_withdrawal()));
      await tester.pump(_ms * 1000);
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
      await tester.pump(chain - _ms);
      expect(state(tester, 'Sent to your bank'), IqTimelineRowState.upcoming);
      await tester.pump(_ms);
      expect(state(tester, 'Sent to your bank'), IqTimelineRowState.current);
      await tester.pump(_ms * 2000);
    });

    testWidgets('steps that land together go one by one', (tester) async {
      await tester.pumpWidget(timeline(_withdrawal()));
      await tester.pump(_ms * 1000);
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
      await tester.pump(chain + _ms * 20);
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
      await tester.pump(_ms * 1000);
      expect(state(tester, 'Failed at the bank'), IqTimelineRowState.current);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
