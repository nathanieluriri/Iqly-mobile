import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/features/discover/brief_detail_screen.dart';
import 'package:iqly_mobile/features/discover/discover_state.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/discover/saved_briefs_screen.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/banner.dart';
import 'package:iqly_mobile/ui/chip.dart';
import 'package:iqly_mobile/ui/dock.dart';
import 'package:iqly_mobile/ui/pull_indicator.dart';
import 'package:iqly_mobile/ui/skeleton.dart';
import 'package:iqly_mobile/ui/switch.dart';
import 'package:iqly_mobile/ui/ticket_card.dart';
import 'package:iqly_mobile/ui/tip_card.dart';

import '../golden/screens/app_harness.dart';
import 'entry_harness.dart';

const _ms = Duration(milliseconds: 1);

double _eo(double t) => IqCurves.easeOut.transform(t);

/// The demo data with the feed's first load and pull to refresh answered
/// when the test says so.
class _Controlled extends ScriptedRepository {
  _Controlled({this.holdFirst = false});

  final bool holdFirst;
  final first = Completer<List<Brief>>();
  Completer<List<Brief>>? refreshing;

  @override
  Future<List<Brief>> briefs({BriefsLoad load = BriefsLoad.any}) {
    if (load == BriefsLoad.feed && holdFirst) return first.future;
    if (load == BriefsLoad.refresh) {
      return (refreshing = Completer<List<Brief>>()).future;
    }
    return super.briefs(load: load);
  }
}

/// The feed answers at once, the Activations summary when the test says so.
class _LateActivations extends ScriptedRepository {
  final summary = Completer<ActivationsSummary>();

  @override
  Future<ActivationsSummary> activationsSummary() => summary.future;
}

/// The feed fails to load, and the retry waits for the test.
class _Failing extends ScriptedRepository {
  int _calls = 0;
  Completer<List<Brief>>? retry;

  @override
  Future<List<Brief>> briefs({BriefsLoad load = BriefsLoad.any}) {
    if (_calls++ == 0) return Future.error(Exception('offline'));
    return (retry = Completer<List<Brief>>()).future;
  }
}

/// Pumps frame by frame until [type] is first built, so the test sees the
/// page's very first frame (offstage, while heroes are measured).
Future<Finder> _firstFrameOf(WidgetTester tester, Type type) async {
  final page = find.byType(type, skipOffstage: false);
  for (var i = 0; i < 5 && page.evaluate().isEmpty; i++) {
    await tester.pump();
  }
  expect(page, findsOneWidget);
  return page;
}

ScrollPosition _feed(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(HomeScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

double _top(WidgetTester tester, Finder finder) => tester.getTopLeft(finder).dy;

Finder get _chips => find.byType(IqChip).first;

double _indicatorOpacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find.descendant(
        of: find.byType(IqPullIndicator),
        matching: find.byType(Opacity),
      ),
    )
    .opacity;

void main() {
  testWidgets('first load: paper, then the skeleton, then the feed', (
    tester,
  ) async {
    // Reduced motion keeps the gate's timings and holds the skeleton still,
    // so the app can settle while the load is open.
    final repository = _Controlled(holdFirst: true);
    await pumpApp(tester, Routes.home, repository: repository);
    expect(find.byType(IqSkeleton), findsNothing);
    await tester.pump(_ms * 300);
    await tester.pump();
    expect(find.byType(IqSkeleton), findsNWidgets(4));
    // The chips stay live while it loads (192:9042).
    expect(_chips, findsOneWidget);

    repository.first.complete(repository.data.briefs);
    await tester.pump(_ms * 600);
    await tester.pump();
    // The hand-over: the skeleton fades out over the arriving feed.
    expect(find.text('Open polls'), findsOneWidget);
    expect(find.byType(IqSkeleton), findsWidgets);
    await tester.pumpAndSettle();
    expect(find.byType(IqSkeleton), findsNothing);
    expect(find.text('Closing soon'), findsOneWidget);
  });

  testWidgets('the feed waits for Open polls and Activations above it', (
    tester,
  ) async {
    final repository = _LateActivations();
    await pumpApp(tester, Routes.home, repository: repository);
    await tester.pump(_ms * 300);
    await tester.pump();
    expect(find.byType(IqSkeleton), findsNWidgets(4));
    await tester.pump(_ms * 900);
    expect(find.byType(IqTicketCard), findsNothing);
    expect(find.byType(IqSkeleton), findsNWidgets(4));

    repository.summary.complete(DemoData.activations);
    await tester.pumpAndSettle();
    expect(find.byType(IqSkeleton), findsNothing);
    expect(
      _top(tester, find.text('Activations')),
      lessThan(_top(tester, find.byType(IqTicketCard).first)),
    );
  });

  testWidgets('pull to refresh in one slot: fade, arm, hold, Done, close', (
    tester,
  ) async {
    final haptics = recordHaptics(tester);
    final repository = _Controlled();
    await pumpApp(
      tester,
      Routes.home,
      repository: repository,
      reducedMotion: false,
    );
    final listTop = _top(tester, _chips);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Closing soon')),
    );
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
    final pulled = -_feed(tester).pixels;
    expect(pulled, greaterThan(0));
    expect(pulled, lessThan(IqTravel.pullArm));
    expect(_indicatorOpacity(tester), closeTo(pulled / IqTravel.pullArm, 0.01));
    expect(haptics, isEmpty);

    for (var i = 0; i < 8 && -_feed(tester).pixels < 90; i++) {
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
    }
    expect(-_feed(tester).pixels, greaterThan(IqTravel.pullArm));
    expect(
      tester.widget<IqPullIndicator>(find.byType(IqPullIndicator)).armed,
      isTrue,
    );
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    expect(haptics, ['HapticFeedbackType.selectionClick']);

    await gesture.up();
    await tester.pump();
    expect(repository.refreshing, isNotNull);
    // The slot takes 52 of the pull; the rest settles over 200 ms.
    await tester.pump();
    await tester.pump(_ms * 201);
    expect(find.text('REFRESHING'), findsOneWidget);
    expect(_feed(tester).pixels, closeTo(0, 0.5));
    // The list holds the 52 pt slot: 40 row and 12 gap above the chips.
    expect(_top(tester, _chips), closeTo(listTop + IqTravel.refreshSlot, 0.5));

    repository.refreshing!.complete(repository.data.briefs);
    await tester.pump();
    await tester.pump(_ms * 200);
    expect(find.text('UP TO DATE · 9:41'), findsOneWidget);
    await tester.pump(_ms * 650);
    expect(_top(tester, _chips), closeTo(listTop + IqTravel.refreshSlot, 0.5));
    // After 800 the slot closes over 200 and the feed slides up with it.
    await tester.pump(_ms * 100);
    expect(_top(tester, _chips), greaterThan(listTop));
    expect(_top(tester, _chips), lessThan(listTop + IqTravel.refreshSlot));
    await tester.pumpAndSettle();
    expect(_top(tester, _chips), listTop);
    expect(haptics, ['HapticFeedbackType.selectionClick']);
  });

  testWidgets('a pull let go before 64 does not refresh', (tester) async {
    final repository = _Controlled();
    await pumpApp(
      tester,
      Routes.home,
      repository: repository,
      reducedMotion: false,
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Closing soon')),
    );
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(repository.refreshing, isNull);
    // The slot is closed, so the indicator is off screen.
    expect(find.byType(IqPullIndicator), findsNothing);
  });

  testWidgets('reduced motion: the slot opens at once and the feed holds', (
    tester,
  ) async {
    final repository = _Controlled();
    final container = await pumpApp(
      tester,
      Routes.home,
      repository: repository,
    );
    final listTop = _top(tester, _chips);
    container.read(discoverFeedProvider.notifier).refresh();
    await tester.pump();
    expect(find.text('REFRESHING'), findsOneWidget);
    expect(_top(tester, _chips), listTop + IqTravel.refreshSlot);
    repository.refreshing!.complete(repository.data.briefs);
    await tester.pump();
    await tester.pump(_ms * 801);
    await tester.pump();
    expect(_top(tester, _chips), listTop);
  });

  testWidgets('the lens chips stay pinned while the feed scrolls', (
    tester,
  ) async {
    await pumpApp(tester, Routes.home);
    final top = _top(tester, _chips);
    _feed(tester).jumpTo(900);
    await tester.pump();
    expect(_top(tester, _chips), top);
    expect(find.text('Open polls').hitTestable(), findsNothing);
  });

  testWidgets('a lens chip fades the content in, 200 ms, no stagger', (
    tester,
  ) async {
    final haptics = recordHaptics(tester);
    await pumpApp(tester, Routes.home, reducedMotion: false);
    await tester.tap(find.text('All'));
    await tester.pump();
    await tester.pump(_ms * 100);
    final fade = tester.widget<SliverFadeTransition>(
      find.byType(SliverFadeTransition),
    );
    expect(fade.opacity.value, closeTo(_eo(0.5), 0.01));
    await tester.pumpAndSettle();
    expect(fade.opacity.value, 1);
    expect(haptics, ['HapticFeedbackType.selectionClick']);

    // Saved is its own route, served with no page transition.
    await tester.tap(find.text('Saved'));
    await tester.pump();
    expect(find.byType(SavedBriefsScreen), findsOneWidget);
    expect(find.byType(HomeScreen).hitTestable(), findsNothing);
  });

  testWidgets('Try again sends the banner up; a failed retry brings it back', (
    tester,
  ) async {
    final haptics = recordHaptics(tester);
    final repository = _Failing();
    await pumpApp(
      tester,
      Routes.home,
      repository: repository,
      reducedMotion: false,
    );
    expect(find.text('Try again').hitTestable(), findsOneWidget);
    // Folded to nothing, the banner's sliver is offstage.
    double banner() =>
        tester.getSize(find.byType(IqBanner, skipOffstage: false)).height;
    final height = banner();
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump(_ms * 90);
    expect(banner(), lessThan(height));
    await tester.pump(_ms * 100);
    expect(banner(), 0);
    expect(haptics, isEmpty);

    repository.retry!.completeError(Exception('offline'));
    await tester.pump();
    await tester.pump();
    await tester.pump(IqBanner.enter + _ms);
    expect(banner(), height);
    expect(haptics, ['HapticFeedbackType.mediumImpact']);
  });

  testWidgets('tapping the lit tab at its root scrolls the feed to the top', (
    tester,
  ) async {
    final haptics = recordHaptics(tester);
    await pumpApp(tester, Routes.home, reducedMotion: false);
    _feed(tester).jumpTo(800);
    await tester.pump();
    await tester.tap(
      find.descendant(of: find.byType(IqDock), matching: find.text('Discover')),
    );
    await tester.pump();
    await tester.pump(_ms * 150);
    expect(_feed(tester).pixels, greaterThan(0));
    expect(_feed(tester).pixels, lessThan(800));
    await tester.pumpAndSettle();
    expect(_feed(tester).pixels, 0);
    expect(haptics, isEmpty);
  });

  testWidgets(
    'Brief detail is drawn from the tapped brief on its first frame',
    (tester) async {
      await pumpApp(tester, Routes.home, reducedMotion: false);
      final ticket = find.byWidgetPredicate(
        (w) => w is IqTicketCard && w.kind == IqTicketCardKind.list,
      );
      await tester.ensureVisible(ticket.first);
      await tester.pumpAndSettle();
      final title = tester.widget<IqTicketCard>(ticket.first).title;
      await tester.tap(ticket.first);
      final page = await _firstFrameOf(tester, BriefDetailScreen);
      for (final text in [title, 'Submit your response']) {
        expect(
          find.descendant(
            of: page,
            matching: find.text(text, skipOffstage: false),
            skipOffstage: false,
          ),
          findsOneWidget,
        );
      }
    },
  );

  testWidgets('"Remind me" opens in its state instead of switching into it', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Routes.home,
      prefs: {
        ...signedInPrefs(),
        'discover.closeReminders': ['c5'],
      },
      reducedMotion: false,
    );
    await tester.tap(find.text('A tagline for a solar kiosk network').first);
    await _firstFrameOf(tester, BriefDetailScreen);
    final remind = find.byType(IqSwitch, skipOffstage: false);
    expect(tester.widget<IqSwitch>(remind).state, IqSwitchState.on);
    await tester.pumpAndSettle();
    expect(tester.widget<IqSwitch>(remind).state, IqSwitchState.on);
  });

  testWidgets('Saved: an unsaved ticket folds away after 300 ms', (
    tester,
  ) async {
    await pumpApp(tester, Routes.savedBriefs, reducedMotion: false);
    expect(find.byType(IqTicketCard), findsNWidgets(2));
    final first = find.byType(IqTicketCard).first;
    final height = tester.getSize(first).height;
    await tester.tap(
      find.descendant(of: first, matching: find.bySemanticsLabel('Saved')),
    );
    await tester.pump(_ms * 299);
    expect(find.byType(IqTicketCard), findsNWidgets(2));
    expect(tester.getSize(find.byType(IqTicketCard).first).height, height);
    await tester.pump(_ms * 2);
    await tester.pump(_ms * 100);
    expect(find.byType(IqTicketCard), findsNWidgets(2));
    await tester.pump(_ms * 120);
    await tester.pumpAndSettle();
    expect(find.byType(IqTicketCard), findsOneWidget);
  });

  testWidgets(
    'the first tip leaves: card drops, scrim fades, Home takes taps',
    (tester) async {
      await pumpApp(
        tester,
        Routes.home,
        prefs: signedInPrefs(firstTipSeen: false),
        reducedMotion: false,
      );
      await tester.pump(_ms * 1000);
      expect(find.byType(IqTipCard), findsOneWidget);
      await tester.pump();
      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.light,
      );

      final cardTop = tester.getTopLeft(find.byType(IqTipCard)).dy;
      await tester.tap(find.text('OK, got it'));
      await tester.pump();
      await tester.pump(_ms * 80);
      expect(
        tester.getTopLeft(find.byType(IqTipCard)).dy,
        greaterThan(cardTop),
      );
      await tester.pump(_ms * 121);
      await tester.pump();
      expect(find.byType(IqTipCard), findsNothing);
      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.dark,
      );
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<IqChip>(find.byType(IqChip).at(1)).state,
        IqChipState.selected,
      );
    },
  );

  testWidgets('reduced motion: the tip fades in and out in place, 150', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Routes.home,
      prefs: signedInPrefs(firstTipSeen: false),
    );
    expect(find.byType(IqTipCard), findsOneWidget);
    final top = tester.getTopLeft(find.byType(IqTipCard)).dy;
    await tester.tap(find.text('OK, got it'));
    await tester.pump();
    await tester.pump(_ms * 75);
    expect(tester.getTopLeft(find.byType(IqTipCard)).dy, top);
    await tester.pump(_ms * 76);
    await tester.pump();
    expect(find.byType(IqTipCard), findsNothing);
  });
}
