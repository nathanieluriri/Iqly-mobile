import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/deadline.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/notifications_service.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/features/notifications/notifications_screen.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/highlight.dart';
import 'package:iqly_mobile/ui/notification.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../golden/screens/app_harness.dart';
import '../golden/screens/polls_notifications_help_harness.dart';
import '../golden/screens/wallet_harness.dart';

void _reduce(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

/// The feed alone at 390 x 844, motion on unless the test reduces it.
Future<ProviderContainer> _pumpFeed(
  WidgetTester tester, {
  NotificationsService? notifications,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(signedInPrefs());
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: <Override>[
      sharedPreferencesProvider.overrideWithValue(prefs),
      repositoryProvider.overrideWithValue(ScriptedRepository()),
      clockProvider.overrideWithValue(() => figmaNow),
      ...laneOverrides(notifications: notifications),
      ...walletOverrides(),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildTheme(),
        home: const NotificationsScreen(),
      ),
    ),
  );
  return container;
}

Finder _row(String id) => find.byKey(ValueKey(id));

double _rowOpacity(WidgetTester tester, String id) => tester
    .widget<FadeTransition>(
      find.ancestor(of: _row(id), matching: find.byType(FadeTransition)).first,
    )
    .opacity
    .value;

double _wiped(WidgetTester tester, String headline) {
  final clip = tester.widget<ClipRect>(
    find
        .descendant(
          of: find.byWidgetPredicate(
            (w) => w is IqHighlight && w.text == headline,
          ),
          matching: find.byType(ClipRect),
        )
        .first,
  );
  return clip.clipper!.getClip(const Size(100, 20)).width / 100;
}

void main() {
  testWidgets('rows arrive 40 ms apart on the first visit only', (
    tester,
  ) async {
    final container = await _pumpFeed(tester);
    await tester.pump();
    await tester.pump();
    expect(_rowOpacity(tester, 'n2'), 0);
    await tester.pump(const Duration(milliseconds: 170));
    expect(_rowOpacity(tester, 'n2'), inExclusiveRange(0, 1));
    expect(_rowOpacity(tester, 'n2'), greaterThan(_rowOpacity(tester, 'n3')));
    await tester.pumpAndSettle();
    expect(_rowOpacity(tester, 'n2'), 1);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildTheme(),
          home: const NotificationsScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(_rowOpacity(tester, 'n2'), 1);
    await tester.pumpAndSettle();
  });

  testWidgets('the feed arrives top first: the rows after the sixth slot, all '
      'on screen, arrive with it', (tester) async {
    await _pumpFeed(tester);
    await tester.pump();
    await tester.pump();
    final rows = tester.widgetList<IqNotification>(find.byType(IqNotification));
    expect(rows.length, greaterThan(5));
    final last = (rows.last.key! as ValueKey<String>).value;
    expect(_rowOpacity(tester, last), 0);
    await tester.pump(const Duration(milliseconds: 190));
    expect(_rowOpacity(tester, last), 0);
    await tester.pump(const Duration(milliseconds: 140));
    expect(_rowOpacity(tester, last), inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(_rowOpacity(tester, last), 1);
  });

  testWidgets('each headline wipes 120 ms into its row', (tester) async {
    await _pumpFeed(tester);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(_wiped(tester, 'Closes in 6h'), 0);
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_wiped(tester, 'Closes in 6h'), inExclusiveRange(0, 1));
    expect(_wiped(tester, '₦10,000.00 requested'), lessThan(1));
    await tester.pumpAndSettle();
    expect(_wiped(tester, 'Closes in 6h'), 1);
    expect(_wiped(tester, '₦10,000.00 requested'), 1);
  });

  testWidgets('reduced motion: rows fade in together, no wipe', (tester) async {
    _reduce(tester);
    await _pumpFeed(tester);
    await tester.pump();
    await tester.pump();
    expect(_wiped(tester, 'Closes in 6h'), 1);
    await tester.pump(const Duration(milliseconds: 75));
    final first = _rowOpacity(tester, 'n2');
    expect(first, inExclusiveRange(0, 1));
    expect(_rowOpacity(tester, 'n4'), first);
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  group('the unread dot', () {
    Widget row(bool unread) => MaterialApp(
      home: Scaffold(
        body: IqNotification(unread: unread, highlightDelay: Duration.zero),
      ),
    );

    double scale(WidgetTester tester) =>
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

    double shown(WidgetTester tester) => tester
        .widget<ScaleTransition>(
          find.descendant(
            of: find.byType(AnimatedScale),
            matching: find.byType(ScaleTransition),
          ),
        )
        .scale
        .value;

    testWidgets('shrinks away over 120 ms ease-in once read', (tester) async {
      await tester.pumpWidget(row(true));
      await tester.pumpAndSettle();
      await tester.pumpWidget(row(false));
      expect(scale(tester), 0);
      await tester.pump(const Duration(milliseconds: 60));
      expect(shown(tester), inExclusiveRange(0.5, 1));
      await tester.pump(const Duration(milliseconds: 60));
      expect(shown(tester), 0);
    });

    testWidgets('reduced motion: gone at once', (tester) async {
      _reduce(tester);
      await tester.pumpWidget(row(true));
      await tester.pumpWidget(row(false));
      await tester.pump();
      expect(shown(tester), 0);
    });
  });

  group('the empty bell', () {
    testWidgets('swings once from +200, pivot at its top', (tester) async {
      await _pumpFeed(tester, notifications: EmptyNotificationsService());
      await tester.pump();
      await tester.pump();
      expect(find.text('Nothing yet'), findsOneWidget);
      final swings = <double>[];
      for (var t = 0; t < 34; t++) {
        swings.add(_bellAngle(tester));
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(swings.take(10).every((a) => a == 0), isTrue);
      expect(swings.reduce((a, b) => a < b ? a : b), lessThan(-0.05));
      expect(swings.reduce((a, b) => a > b ? a : b), greaterThan(0.03));
      await tester.pumpAndSettle();
      expect(_bellAngle(tester), closeTo(0, 0.001));
    });

    testWidgets('reduced motion: no swing, everything fades together', (
      tester,
    ) async {
      _reduce(tester);
      await _pumpFeed(tester, notifications: EmptyNotificationsService());
      await tester.pump();
      await tester.pump();
      for (var t = 0; t < 8; t++) {
        expect(_bellAngle(tester), 0);
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}

/// The bell's rotation in radians: the Transform.rotate pinned at its top.
double _bellAngle(WidgetTester tester) {
  final rotate = tester.widget<Transform>(
    find.byWidgetPredicate(
      (w) => w is Transform && w.alignment == Alignment.topCenter,
    ),
  );
  return math.atan2(rotate.transform.entry(1, 0), rotate.transform.entry(0, 0));
}
