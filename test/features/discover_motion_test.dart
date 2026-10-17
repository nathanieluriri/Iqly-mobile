import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/edge_haptics.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/core/transitions.dart';
import 'package:iqly_mobile/data/activations_data.dart';
import 'package:iqly_mobile/data/activations_service.dart';
import 'package:iqly_mobile/data/polls_service.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/features/discover/brief_detail_screen.dart';
import 'package:iqly_mobile/features/discover/discover_state.dart';
import 'package:iqly_mobile/features/discover/discover_widgets.dart';
import 'package:iqly_mobile/features/discover/filters_sheet.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/discover/saved_briefs_screen.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/banner.dart';
import 'package:iqly_mobile/ui/brief_card.dart';
import 'package:iqly_mobile/ui/button.dart';
import 'package:iqly_mobile/ui/chip.dart';
import 'package:iqly_mobile/ui/dock.dart';
import 'package:iqly_mobile/ui/illustration.dart';
import 'package:iqly_mobile/ui/pull_indicator.dart';
import 'package:iqly_mobile/ui/switch.dart';
import 'package:iqly_mobile/ui/ticket_card.dart';
import 'package:iqly_mobile/ui/tip_card.dart';

import '../golden/screens/app_harness.dart';
import '../golden/screens/app_harness.dart' as harness;
import '../golden/screens/polls_notifications_help_harness.dart';
import 'entry_harness.dart';

const _ms = Duration(milliseconds: 1);

/// The app with Quick polls and the activations answering at once, unless
/// [activations] stands in for them.
Future<ProviderContainer> pumpApp(
  WidgetTester tester,
  String location, {
  IqlyRepository? repository,
  Map<String, Object>? prefs,
  bool reducedMotion = true,
  bool settle = true,
  ActivationsService? activations,
  TransitionBuilder? builder,
}) => harness.pumpApp(
  tester,
  location,
  repository: repository,
  prefs: prefs,
  reducedMotion: reducedMotion,
  settle: settle,
  builder: builder,
  overrides: [
    pollsServiceProvider.overrideWithValue(instantPolls()),
    if (activations != null)
      activationsServiceProvider.overrideWithValue(activations),
  ],
);

/// The last frame a lens crossing fades out (the covers are images too).
final _snapshot = find.byWidgetPredicate(
  (w) => w is RawImage && w.fit == BoxFit.fill,
);

final _skeletons = find.byWidgetPredicate(
  (w) => w.runtimeType.toString() == '_SkeletonCard',
);

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

/// The activations answer when the test says so.
class _LateActivations extends DemoActivationsService {
  _LateActivations()
    : super(clock: () => figmaNow, load: Duration.zero, delay: Duration.zero);

  final list = Completer<List<Activation>>();

  @override
  Future<List<Activation>> activations() => list.future;
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

/// The product of every fade above [finder].
double _shown(WidgetTester tester, Finder finder) {
  var opacity = 1.0;
  for (final widget in tester.widgetList(
    find.ancestor(
      of: finder,
      matching: find.byWidgetPredicate(
        (w) => w is FadeTransition || w is Opacity || w is SliverFadeTransition,
      ),
    ),
  )) {
    opacity *= switch (widget) {
      FadeTransition(:final opacity) => opacity.value,
      SliverFadeTransition(:final opacity) => opacity.value,
      _ => (widget as Opacity).opacity,
    };
  }
  return opacity;
}

Finder get _chips => find.byType(IqChip).first;

/// How far the first tip's scrim is in; 0 while it is not up.
double _tipScrim(WidgetTester tester) {
  final scrim = find.byWidgetPredicate(
    (w) => w is ColoredBox && w.color == IqScrim.tip,
  );
  if (scrim.evaluate().isEmpty) return 0;
  return tester
      .widget<FadeTransition>(
        find.ancestor(of: scrim, matching: find.byType(FadeTransition)).first,
      )
      .opacity
      .value;
}

/// Whether an item of the feed is still on its way in.
bool _arriving(WidgetTester tester) {
  var arriving = false;
  for (final item in find.byType(ArriveItem).evaluate()) {
    item.visitChildren(
      (cue) => cue.visitChildren((move) {
        final widget = move.widget;
        if (widget is FadeTransition && widget.opacity.value < 1) {
          arriving = true;
        }
      }),
    );
  }
  return arriving;
}

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
    expect(_skeletons, findsNothing);
    await tester.pump(_ms * 300);
    await tester.pump();
    expect(_skeletons, findsWidgets);
    // The chips stay live while it loads (192:9042).
    expect(_chips, findsOneWidget);

    repository.first.complete(repository.data.briefs);
    await tester.pump(_ms * 600);
    await tester.pump();
    // The hand-over: the skeleton fades out over the arriving feed.
    expect(find.text('Quick polls'), findsWidgets);
    expect(_skeletons, findsWidgets);
    await tester.pumpAndSettle();
    expect(_skeletons, findsNothing);
    expect(find.text('A tagline for a solar kiosk network'), findsOneWidget);
  });

  testWidgets('the feed waits for Open polls and Activations above it', (
    tester,
  ) async {
    final activations = _LateActivations();
    await pumpApp(tester, Routes.home, activations: activations);
    await tester.pump(_ms * 300);
    await tester.pump();
    expect(_skeletons, findsNWidgets(2));
    await tester.pump(_ms * 900);
    expect(find.byType(IqBriefCard), findsNothing);
    expect(_skeletons, findsNWidgets(2));

    activations.list.complete(DemoActivations(figmaNow).all);
    await tester.pumpAndSettle();
    expect(_skeletons, findsNothing);
    expect(
      _top(tester, find.text('Activations')),
      lessThan(_top(tester, find.text('Briefs'))),
    );
  });

  group('the skeleton hands over to the final layout', () {
    /// The most shown copy of [text]: its opacity and top, or null.
    (double, double)? seen(WidgetTester tester, String text) {
      (double, double)? best;
      final finder = find.text(text);
      for (var i = 0; i < finder.evaluate().length; i++) {
        final one = finder.at(i);
        final shown = _shown(tester, one);
        if (best == null || shown > best.$1) best = (shown, _top(tester, one));
      }
      return best;
    }

    /// Lands the load with [land], then steps through the hand-over a frame
    /// at a time: once a text of [texts] is fully shown it never fades or
    /// moves, and it first shows within a rise of where it settles.
    Future<void> holds(
      WidgetTester tester,
      List<String> texts, {
      required VoidCallback land,
    }) async {
      final first = <String, double>{};
      final settled = <String, double>{};
      void sample() {
        for (final text in texts) {
          final now = seen(tester, text);
          if (now == null || now.$1 <= 0.01) {
            expect(settled[text], isNull, reason: '$text dropped out');
            continue;
          }
          first[text] ??= now.$2;
          final at = settled[text];
          if (at != null) {
            expect(now.$1, greaterThan(0.99), reason: '$text dipped');
            expect(now.$2, closeTo(at, 0.5), reason: '$text moved');
          } else if (now.$1 > 0.99) {
            settled[text] = now.$2;
          }
        }
      }

      sample();
      land();
      for (var frame = 0; frame < 90; frame++) {
        await tester.pump(_ms * 16);
        sample();
      }
      for (final text in texts) {
        final end = seen(tester, text)!;
        expect(end.$1, greaterThan(0.99));
        expect(
          (end.$2 - first[text]!).abs(),
          lessThanOrEqualTo(IqTravel.riseCard + 0.5),
          reason: '$text jumped from ${first[text]} to ${end.$2}',
        );
      }
    }

    testWidgets('Activations late: nothing is inserted above the skeleton', (
      tester,
    ) async {
      final activations = _LateActivations();
      await pumpApp(
        tester,
        Routes.home,
        activations: activations,
        reducedMotion: false,
        settle: false,
      );
      await tester.pump(_ms * 300);
      await tester.pump();
      expect(_skeletons, findsNWidgets(2));
      await tester.pump(_ms * 600);
      await holds(tester, [
        'Quick polls',
        'Activations',
        'Briefs',
      ], land: () => activations.list.complete(DemoActivations(figmaNow).all));
    });

    testWidgets('proposals in first: they stand still while the cards fade', (
      tester,
    ) async {
      final repository = _Controlled(holdFirst: true);
      await pumpApp(
        tester,
        Routes.home,
        repository: repository,
        reducedMotion: false,
        settle: false,
      );
      await tester.pump(_ms * 100);
      await tester.pump(_ms * 200);
      await tester.pump();
      expect(_skeletons, findsWidgets);
      expect(seen(tester, 'Quick polls')!.$1, 1);
      await tester.pump(_ms * 600);
      await holds(tester, [
        'Quick polls',
        'Activations',
        'Briefs',
      ], land: () => repository.first.complete(repository.data.briefs));
    });
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
      tester.getCenter(find.text('Briefs')),
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
    expect(haptics, ['HapticFeedbackType.lightImpact']);

    await gesture.up();
    await tester.pump();
    expect(repository.refreshing, isNotNull);
    // The slot takes 52 of the pull; the rest settles over 200 ms.
    await tester.pump();
    await tester.pump(_ms * 201);
    expect(find.text('Refreshing'), findsOneWidget);
    expect(_feed(tester).pixels, closeTo(0, 0.5));
    // The list holds the 52 pt slot: 40 row and 12 gap above the chips.
    expect(_top(tester, _chips), closeTo(listTop + IqTravel.refreshSlot, 0.5));

    repository.refreshing!.complete(repository.data.briefs);
    await tester.pump();
    await tester.pump(_ms * 200);
    expect(find.text('Up to date · 9:41'), findsOneWidget);
    await tester.pump(_ms * 650);
    expect(_top(tester, _chips), closeTo(listTop + IqTravel.refreshSlot, 0.5));
    // After 800 the slot closes over 200 and the feed slides up with it.
    await tester.pump(_ms * 100);
    expect(_top(tester, _chips), greaterThan(listTop));
    expect(_top(tester, _chips), lessThan(listTop + IqTravel.refreshSlot));
    await tester.pumpAndSettle();
    expect(_top(tester, _chips), listTop);
    expect(haptics, ['HapticFeedbackType.lightImpact']);
  });

  testWidgets('a drag up the feed stops at the top once; pulling on to arm '
      'the refresh in the same gesture adds no second buzz', (tester) async {
    final haptics = recordHaptics(tester);
    final repository = _Controlled();
    await pumpApp(
      tester,
      Routes.home,
      repository: repository,
      reducedMotion: false,
      builder: (context, child) => EdgeHaptics(child: child!),
    );
    _feed(tester).jumpTo(200);
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(HomeScreen)),
    );
    for (var i = 0; i < 20 && -_feed(tester).pixels < 90; i++) {
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
    }
    expect(
      tester.widget<IqPullIndicator>(find.byType(IqPullIndicator)).armed,
      isTrue,
    );
    expect(haptics, ['HapticFeedbackType.heavyImpact']);

    await gesture.up();
    await tester.pump();
    repository.refreshing!.complete(repository.data.briefs);
    await tester.pumpAndSettle();
    expect(haptics, ['HapticFeedbackType.heavyImpact']);
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
      tester.getCenter(find.text('Briefs')),
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
    expect(find.text('Refreshing'), findsOneWidget);
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
    expect(find.text('Quick polls').hitTestable(), findsNothing);
  });

  testWidgets('a lens chip holds the chrome and crosses the content over '
      '200 ms, so cards on both lenses stay steady (spec 3.7)', (tester) async {
    final haptics = recordHaptics(tester);
    await pumpApp(tester, Routes.home, reducedMotion: false);
    final chipsBottom = tester.getBottomLeft(find.byType(FeedChips)).dy;
    final shared = find.text('Quick polls');
    final old = find.descendant(
      of: find.byType(LensCrossfade),
      matching: _snapshot,
    );
    expect(old, findsNothing);

    await tester.tap(find.text('All'));
    await tester.pump();
    expect(_shown(tester, shared), 1);
    expect(_shown(tester, old), 1);
    final clip = tester.widget<ClipRect>(
      find.ancestor(of: old, matching: find.byType(ClipRect)).first,
    );
    expect(clip.clipper!.getClip(const Size(390, 844)).top, chipsBottom);
    await tester.pump(_ms * 100);
    expect(_shown(tester, shared), 1);
    expect(_shown(tester, old), closeTo(1 - _eo(0.5), 0.01));
    await tester.pump(_ms * 101);
    await tester.pump();
    expect(old, findsNothing);
    expect(_shown(tester, shared), 1);
    expect(haptics, ['HapticFeedbackType.lightImpact']);

    // Saved is its own route, served with no page transition.
    await tester.tap(find.text('Saved'));
    await tester.pump();
    expect(find.byType(SavedBriefsScreen), findsOneWidget);
    expect(find.byType(HomeScreen).hitTestable(), findsNothing);
    expect(_shown(tester, old), 1);
    await tester.pumpAndSettle();
    expect(old, findsNothing);
  });

  testWidgets('a second pick while the content crosses starts a new '
      'crossing from what is on screen', (tester) async {
    await pumpApp(tester, Routes.home, reducedMotion: false);
    final old = find.descendant(
      of: find.byType(LensCrossfade),
      matching: _snapshot,
    );
    await tester.tap(find.text('All'));
    await tester.pump();
    await tester.pump(_ms * 100);
    expect(_shown(tester, old), closeTo(1 - _eo(0.5), 0.01));
    await tester.tap(find.text('For you'));
    await tester.pump();
    expect(old, findsOneWidget);
    expect(_shown(tester, old), 1);
    await tester.pump(_ms * 100);
    expect(_shown(tester, old), closeTo(1 - _eo(0.5), 0.01));
    await tester.pumpAndSettle();
    expect(old, findsNothing);
    expect(_shown(tester, find.text('Quick polls')), 1);
  });

  testWidgets('reduced motion: a lens chip cuts to the new content', (
    tester,
  ) async {
    await pumpApp(tester, Routes.home);
    await tester.tap(find.text('All'));
    await tester.pump();
    expect(
      find.descendant(of: find.byType(LensCrossfade), matching: _snapshot),
      findsNothing,
    );
    expect(_shown(tester, find.text('Quick polls')), 1);
  });

  testWidgets('Filters: Show N briefs crosses the feed under the dropping '
      'sheet (spec 6.21)', (tester) async {
    await pumpApp(tester, Routes.filters, reducedMotion: false);
    await tester.tap(find.text('Tier'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    final old = find.descendant(
      of: find.byType(LensCrossfade),
      matching: _snapshot,
    );
    expect(old, findsNothing);
    await tester.tap(
      find.descendant(
        of: find.byType(FiltersSheet),
        matching: find.textContaining('Show '),
      ),
    );
    await tester.pump();
    expect(_shown(tester, old), 1);
    await tester.pump(_ms * 100);
    expect(_shown(tester, old), closeTo(1 - _eo(0.5), 0.01));
    await tester.pumpAndSettle();
    expect(old, findsNothing);
    expect(find.byType(FiltersSheet), findsNothing);
  });

  testWidgets('Saved to For you goes straight to For you: All never lights '
      '(spec 3.7)', (tester) async {
    await pumpApp(tester, Routes.home, reducedMotion: false);
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    expect(find.byType(SavedBriefsScreen), findsOneWidget);

    Color fill(String label) {
      final chip = find.descendant(
        of: find.byType(HomeScreen),
        matching: find.byWidgetPredicate(
          (w) => w is IqChip && w.label == label,
        ),
      );
      final box = tester.widget<Container>(
        find.descendant(of: chip, matching: find.byType(Container)).first,
      );
      return (box.decoration! as BoxDecoration).color!;
    }

    await tester.tap(find.text('For you'));
    var shown = 0;
    for (var i = 0; i < 12; i++) {
      await tester.pump(_ms * 16);
      if (find.byType(HomeScreen).evaluate().isEmpty) continue;
      shown++;
      expect(fill('All'), IqColors.card, reason: 'frame $i');
    }
    expect(shown, greaterThan(8));
    await tester.pumpAndSettle();
    expect(find.byType(SavedBriefsScreen), findsNothing);
    expect(fill('For you'), IqColors.tint);
    expect(fill('Saved'), IqColors.card);
    expect(fill('All'), IqColors.card);
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
    expect(haptics, ['HapticFeedbackType.lightImpact']);

    repository.retry!.completeError(Exception('offline'));
    await tester.pump();
    await tester.pump();
    await tester.pump(IqBanner.enter + _ms);
    expect(banner(), height);
    expect(haptics, [
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.heavyImpact',
    ]);
  });

  testWidgets('the lit tab is inert: tapping it leaves the feed where it is', (
    tester,
  ) async {
    final haptics = recordHaptics(tester);
    await pumpApp(tester, Routes.home, reducedMotion: false);
    _feed(tester).jumpTo(800);
    await tester.pump();
    await tester.tap(
      find.descendant(of: find.byType(IqDock), matching: find.text('Discover')),
    );
    await tester.pumpAndSettle();
    expect(_feed(tester).pixels, 800);
    expect(haptics, isEmpty);
  });

  testWidgets(
    'Brief detail is drawn from the tapped brief on its first frame',
    (tester) async {
      await pumpApp(tester, Routes.home, reducedMotion: false);
      final card = find.byWidgetPredicate(
        (w) => w is IqBriefCard && w.kind == IqBriefCardKind.feature,
      );
      await tester.ensureVisible(card.first);
      await tester.pumpAndSettle();
      final title = tester.widget<IqBriefCard>(card.first).title;
      await tester.tap(card.first);
      final page = await _firstFrameOf(tester, BriefDetailScreen);
      for (final text in [title, 'Start your submission']) {
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
    final card = find.text('A tagline for a solar kiosk network').first;
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
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

  testWidgets('Filters: "Show N briefs" rolls its count when a pick changes '
      'it (spec 6.21)', (tester) async {
    await pumpApp(tester, Routes.filters, reducedMotion: false, settle: false);
    await tester.pump(_ms * 600);
    String label() => tester
        .widget<IqButton>(
          find
              .descendant(
                of: find.byType(FiltersSheet),
                matching: find.byType(IqButton),
              )
              .first,
        )
        .label;
    final before = label();
    expect(before, startsWith('Show '));

    await tester.tap(find.text('Tier'));
    await tester.pump();
    await tester.pump(_ms * 400);
    await tester.tap(find.text('Advanced'));
    String? after;
    for (var i = 0; i < 40 && after == null; i++) {
      await tester.pump(_ms * 16);
      if (label() != before) after = label();
    }
    expect(after, isNotNull);
    await tester.pump(_ms * 64);
    expect(find.text(before), findsOneWidget);
    expect(find.text(after!), findsWidgets);
    await tester.pump(_ms * 120);
    expect(find.text(before), findsNothing);
    expect(find.text(after), findsOneWidget);
  });

  group('the figure of the empty feed arrives (spec 6.24, 5.29)', () {
    final figure = find.byType(IqFigure);

    Future<void> rises(WidgetTester tester, IqFigures kind) async {
      for (var i = 0; i < 40; i++) {
        await tester.pump(_ms * 16);
        if (figure.evaluate().isNotEmpty) break;
      }
      expect(figure, findsOneWidget);
      final shown = tester.widget<IqFigure>(figure);
      expect(shown.figure, kind);
      expect(shown.arrive, isTrue);
      await tester.pumpAndSettle();
    }

    testWidgets('no briefs', (tester) async {
      await pumpApp(
        tester,
        Routes.home,
        repository: ScriptedRepository([BriefsCall.empty]),
        reducedMotion: false,
        settle: false,
      );
      expect(figure, findsNothing);
      await rises(tester, IqFigures.writer);
      expect(find.text('No open briefs right now'), findsOneWidget);
    });

    testWidgets('no briefs match the filters', (tester) async {
      final container = await pumpApp(
        tester,
        Routes.home,
        reducedMotion: false,
        settle: false,
      );
      await tester.pump(_ms * 600);
      container
          .read(discoverFiltersProvider.notifier)
          .apply(
            const DiscoverFilters(
              tier: Tier.advanced,
              category: Category.technology,
            ),
          );
      await rises(tester, IqFigures.shrug);
      expect(find.text('No briefs match these filters'), findsOneWidget);
    });

    testWidgets('a failed load shows the Thinker', (tester) async {
      await pumpApp(
        tester,
        Routes.home,
        repository: ScriptedRepository([BriefsCall.fail]),
        reducedMotion: false,
        settle: false,
      );
      await rises(tester, IqFigures.thinker);
      expect(find.text('Couldn’t load briefs'), findsOneWidget);
    });
  });

  testWidgets('the first tip waits for the feed to land and arrive (227:11321 '
      'shows it over a loaded feed)', (tester) async {
    final repository = _Controlled(holdFirst: true);
    await pumpApp(
      tester,
      Routes.home,
      repository: repository,
      prefs: signedInPrefs(firstTipSeen: false),
      reducedMotion: false,
      settle: false,
    );
    const frame = Duration(microseconds: 16667);
    var now = Duration.zero;
    Duration? landed;
    Duration? tip;
    while (now < const Duration(seconds: 3)) {
      // The prototype's 1.2 s first load.
      if (now >= _ms * 1200 && !repository.first.isCompleted) {
        repository.first.complete(repository.data.briefs);
      }
      await tester.pump(frame);
      now += frame;
      if (landed == null && find.text('Briefs').evaluate().isNotEmpty) {
        landed = now;
      }
      if (tip == null && _tipScrim(tester) > 0) {
        tip = now;
        expect(_skeletons, findsNothing);
        expect(_arriving(tester), isFalse);
      }
    }
    expect(landed, isNotNull);
    expect(tip, isNotNull);
    expect(tip! - landed!, greaterThanOrEqualTo(IqDurations.tipWait));
    expect(find.byType(IqTipCard), findsOneWidget);
  });

  testWidgets('reduced motion: the tip still waits for the feed', (
    tester,
  ) async {
    final repository = _Controlled(holdFirst: true);
    await pumpApp(
      tester,
      Routes.home,
      repository: repository,
      prefs: signedInPrefs(firstTipSeen: false),
      settle: false,
    );
    await tester.pump(_ms * 300);
    await tester.pump(_ms * 600);
    expect(_skeletons, findsWidgets);
    expect(find.byType(IqTipCard), findsNothing);
    repository.first.complete(repository.data.briefs);
    await tester.pumpAndSettle();
    expect(_skeletons, findsNothing);
    expect(find.byType(IqTipCard), findsOneWidget);
  });

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
