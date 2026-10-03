import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/core/transitions.dart';
import 'package:iqly_mobile/theme/theme.dart';

const _size = Size(390, 844);
const _sheetHeight = 400.0;

class _Page extends StatelessWidget {
  const _Page(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: IqColors.bg,
      child: SizedBox.expand(
        key: ValueKey(name),
        child: Center(
          child: GestureDetector(
            onTap: () => context.pop(),
            child: Text('back from $name'),
          ),
        ),
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      key: ValueKey('sheet'),
      width: double.infinity,
      height: _sheetHeight,
      child: ColoredBox(color: IqColors.card),
    );
  }
}

GoRouter _router([String initial = '/a']) => GoRouter(
  initialLocation: initial,
  routes: [
    GoRoute(path: '/a', pageBuilder: (c, s) => pushPage(s, const _Page('a'))),
    GoRoute(path: '/b', pageBuilder: (c, s) => pushPage(s, const _Page('b'))),
    GoRoute(
      path: '/h',
      pageBuilder: (c, s) => handoffPage(s, const _Page('h')),
    ),
    GoRoute(
      path: '/lens',
      pageBuilder: (c, s) => lensPage(s, const _Page('lens')),
    ),
    GoRoute(
      path: '/sheet',
      pageBuilder: (c, s) => sheetPage(s, const _Sheet(), scrim: IqScrim.sheet),
    ),
  ],
);

Future<GoRouter> _pump(
  WidgetTester tester, {
  String initial = '/a',
  bool reduced = false,
}) => _pumpWith(tester, _router(initial), reduced: reduced);

Future<GoRouter> _pumpWith(
  WidgetTester tester,
  GoRouter router, {
  bool reduced = false,
}) async {
  tester.view.physicalSize = _size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  if (reduced) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(theme: buildTheme(), routerConfig: router),
  );
  await tester.pumpAndSettle();
  return router;
}

double _dx(WidgetTester tester, String page) =>
    tester.getTopLeft(find.byKey(ValueKey(page))).dx;

double _dy(WidgetTester tester, String page) =>
    tester.getTopLeft(find.byKey(ValueKey(page))).dy;

/// The product of every fade above [page].
double _opacity(WidgetTester tester, String page) {
  var opacity = 1.0;
  for (final widget in tester.widgetList(
    find.ancestor(
      of: find.byKey(ValueKey(page)),
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

double _eo(double t) => IqCurves.easeOut.transform(t);
double _ei(double t) => IqCurves.easeIn.transform(t);

const _ms = Duration(milliseconds: 1);

void main() {
  group('push', () {
    testWidgets('slides 24 in as it fades, the page beneath slides away', (
      tester,
    ) async {
      final router = await _pump(tester);
      router.push('/b');
      await tester.pump();
      await tester.pump();
      expect(_dx(tester, 'b'), closeTo(24, 0.01));
      expect(_opacity(tester, 'b'), closeTo(0, 0.01));
      expect(_dx(tester, 'a'), closeTo(0, 0.01));

      await tester.pump(_ms * 150);
      expect(_dx(tester, 'b'), closeTo(24 * (1 - _eo(0.5)), 0.5));
      expect(_opacity(tester, 'b'), closeTo(_eo(0.5 / 0.6), 0.01));
      expect(_dx(tester, 'a'), closeTo(-24 * _ei(0.5), 0.5));
      expect(_opacity(tester, 'a'), closeTo(0, 0.01));

      await tester.pump(_ms * 150);
      expect(_dx(tester, 'b'), 0);
      expect(_opacity(tester, 'b'), 1);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('a')), findsNothing);
    });

    testWidgets('pops back over 240', (tester) async {
      final router = await _pump(tester);
      router.push('/b');
      await tester.pumpAndSettle();
      router.pop();
      await tester.pump();
      expect(_dx(tester, 'b'), closeTo(0, 0.01));

      await tester.pump(_ms * 120);
      expect(_dx(tester, 'b'), closeTo(24 * (1 - _eo(0.5)), 0.5));
      expect(_dx(tester, 'a'), closeTo(-24 * _ei(0.5), 0.5));

      await tester.pump(_ms * 120);
      expect(_dx(tester, 'a'), 0);
      expect(_opacity(tester, 'a'), 1);
      await tester.pump(_ms);
      await tester.pump();
      expect(find.byKey(const ValueKey('b')), findsNothing);
    });

    testWidgets('a go marked back mirrors the push', (tester) async {
      final router = await _pump(tester, initial: '/b');
      router.go('/a', extra: NavDirection.back);
      await tester.pump();
      await tester.pump();
      await tester.pump(_ms * 120);
      expect(_dx(tester, 'a'), closeTo(-24 * (1 - _eo(0.5)), 0.5));
      expect(_dx(tester, 'b'), closeTo(24 * _ei(0.5), 0.5));
      await tester.pumpAndSettle();
      expect(_dx(tester, 'a'), 0);
      expect(find.byKey(const ValueKey('b')), findsNothing);
    });

    testWidgets('a back tap halfway through a push pops it', (tester) async {
      final router = await _pump(tester);
      router.push('/b');
      await tester.pump();
      await tester.pump(_ms * 150);
      await tester.tap(find.text('back from b'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/a');
      expect(find.byKey(const ValueKey('b')), findsNothing);
      expect(_dx(tester, 'a'), 0);
      expect(_opacity(tester, 'a'), 1);
    });

    testWidgets('reduced motion: a 150 ms crossfade and nothing slides', (
      tester,
    ) async {
      final router = await _pump(tester, reduced: true);
      router.push('/b');
      await tester.pump();
      await tester.pump();
      expect(_dx(tester, 'b'), 0);
      await tester.pump(_ms * 75);
      expect(_dx(tester, 'b'), 0);
      expect(_dx(tester, 'a'), 0);
      expect(_opacity(tester, 'a'), 1);
      expect(_opacity(tester, 'b'), closeTo(_eo(0.5), 0.01));
      await tester.pump(_ms * 75);
      expect(_opacity(tester, 'b'), 1);
      await tester.pump(_ms);
      expect(tester.hasRunningAnimations, isFalse);

      router.pop();
      await tester.pump();
      await tester.pump(_ms * 75);
      expect(_dx(tester, 'b'), 0);
      await tester.pump(_ms * 75);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('b')), findsNothing);
    });

    testWidgets('iOS: the edge swipe follows the finger and pops', (
      tester,
    ) async {
      final router = await _pump(tester);
      router.push('/b');
      await tester.pumpAndSettle();

      final swipe = await tester.startGesture(const Offset(5, 400));
      await swipe.moveBy(const Offset(20, 0));
      await tester.pump();
      final caught = _dx(tester, 'b');
      await swipe.moveBy(const Offset(100, 0));
      await tester.pump();
      final dragged = _dx(tester, 'b');
      expect(dragged - caught, closeTo(100, 0.5));
      expect(_opacity(tester, 'b'), 1);
      expect(_opacity(tester, 'a'), 1);
      expect(_dx(tester, 'a'), closeTo(-24 * (1 - dragged / 390), 0.5));

      await swipe.moveBy(const Offset(150, 0));
      await swipe.up();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('b')), findsNothing);
      expect(_dx(tester, 'a'), 0);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('iOS: a short swipe settles back', (tester) async {
      final router = await _pump(tester);
      router.push('/b');
      await tester.pumpAndSettle();

      final swipe = await tester.startGesture(const Offset(5, 400));
      await swipe.moveBy(const Offset(20, 0));
      await tester.pump();
      final caught = _dx(tester, 'b');
      await swipe.moveBy(const Offset(40, 0));
      await tester.pump();
      expect(_dx(tester, 'b') - caught, closeTo(40, 0.5));
      await swipe.up();
      await tester.pumpAndSettle();
      expect(_dx(tester, 'b'), 0);
      expect(router.state.uri.path, '/b');
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  group('hand-off', () {
    testWidgets('fades in over a page that stays still, 300 ms', (
      tester,
    ) async {
      final router = await _pump(tester);
      router.go('/h');
      await tester.pump();
      await tester.pump();
      await tester.pump(_ms * 150);
      expect(_opacity(tester, 'h'), closeTo(_eo(0.5), 0.01));
      expect(_dx(tester, 'h'), 0);
      expect(_dx(tester, 'a'), 0);
      expect(_opacity(tester, 'a'), 1);
      await tester.pump(_ms * 150);
      expect(_opacity(tester, 'h'), 1);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('a')), findsNothing);
    });

    testWidgets('from the splash it takes 400', (tester) async {
      final router = await _pump(tester);
      router.go('/h', extra: Arrival.splash);
      await tester.pump();
      await tester.pump();
      await tester.pump(_ms * 200);
      expect(_opacity(tester, 'h'), closeTo(_eo(0.5), 0.01));
      await tester.pump(_ms * 200);
      expect(_opacity(tester, 'h'), 1);
    });

    testWidgets('reduced motion: 150', (tester) async {
      final router = await _pump(tester, reduced: true);
      router.go('/h', extra: Arrival.splash);
      await tester.pump();
      await tester.pump();
      await tester.pump(_ms * 75);
      expect(_opacity(tester, 'h'), closeTo(_eo(0.5), 0.01));
      await tester.pump(_ms * 75);
      expect(_opacity(tester, 'h'), 1);
    });
  });

  group('lens', () {
    testWidgets('fades in place over 200 ms', (tester) async {
      final router = await _pump(tester);
      router.push('/lens');
      await tester.pump();
      await tester.pump();
      await tester.pump(_ms * 100);
      expect(_opacity(tester, 'lens'), closeTo(_eo(0.5), 0.01));
      expect(_dx(tester, 'lens'), 0);
      expect(_dx(tester, 'a'), 0);
      expect(_opacity(tester, 'a'), 1);
      await tester.pump(_ms * 100);
      expect(_opacity(tester, 'lens'), 1);
    });

    testWidgets('reduced motion: a cut', (tester) async {
      final router = await _pump(tester, reduced: true);
      router.push('/lens');
      await tester.pump();
      await tester.pump();
      expect(_opacity(tester, 'lens'), 1);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('sheet', () {
    double scrim(WidgetTester tester) => tester
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

    testWidgets('rises 300 over its scrim and drops 200', (tester) async {
      final router = await _pump(tester);
      router.push('/sheet');
      await tester.pump();
      await tester.pump();
      const top = 844 - _sheetHeight;
      expect(_dy(tester, 'sheet'), closeTo(844, 0.5));

      await tester.pump(_ms * 150);
      expect(
        _dy(tester, 'sheet'),
        closeTo(top + _sheetHeight * (1 - _eo(0.5)), 0.5),
      );
      expect(scrim(tester), closeTo(IqOpacity.sheetScrim * _eo(0.5), 0.01));
      expect(_dx(tester, 'a'), 0);
      expect(_opacity(tester, 'a'), 1);

      await tester.pump(_ms * 150);
      expect(_dy(tester, 'sheet'), closeTo(top, 0.5));
      expect(scrim(tester), closeTo(IqOpacity.sheetScrim, 0.01));

      router.pop();
      await tester.pump();
      await tester.pump(_ms * 100);
      expect(
        _dy(tester, 'sheet'),
        closeTo(top + _sheetHeight * (1 - _eo(0.5)), 0.5),
      );
      await tester.pump(_ms * 100);
      await tester.pumpAndSettle();
      expect(find.byType(_Sheet), findsNothing);
    });

    testWidgets('follows a drag down and closes past half its height', (
      tester,
    ) async {
      final router = await _pump(tester);
      router.push('/sheet');
      await tester.pumpAndSettle();
      const top = 844 - _sheetHeight;

      final drag = await tester.startGesture(const Offset(195, top + 40));
      await drag.moveBy(const Offset(0, 20));
      await drag.moveBy(const Offset(0, 80));
      await tester.pump();
      expect(_dy(tester, 'sheet'), closeTo(top + 100, 1));
      await drag.up();
      await tester.pumpAndSettle();
      expect(_dy(tester, 'sheet'), closeTo(top, 0.5));
      expect(router.state.uri.path, '/sheet');

      final close = await tester.startGesture(const Offset(195, top + 40));
      await close.moveBy(const Offset(0, 20));
      await close.moveBy(const Offset(0, 240));
      await tester.pump();
      await close.up();
      await tester.pumpAndSettle();
      expect(find.byType(_Sheet), findsNothing);
      expect(router.state.uri.path, '/a');
    });

    testWidgets('reduced motion: fades in place over 150', (tester) async {
      final router = await _pump(tester, reduced: true);
      router.push('/sheet');
      await tester.pump();
      await tester.pump();
      await tester.pump(_ms * 75);
      expect(_dy(tester, 'sheet'), closeTo(844 - _sheetHeight, 0.5));
      expect(_opacity(tester, 'sheet'), closeTo(_eo(0.5), 0.01));
      await tester.pump(_ms * 75);
      expect(_opacity(tester, 'sheet'), 1);
      await tester.pump(_ms);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('showIqSheet resolves with what the sheet pops', (
      tester,
    ) async {
      String? picked;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => picked = await showIqSheet<String>(
                context,
                (context) => TextButton(
                  onPressed: () => Navigator.of(context).pop('lagos'),
                  child: const Text('pick'),
                ),
                scrim: IqScrim.picker,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('pick'));
      await tester.pumpAndSettle();
      expect(picked, 'lagos');
      expect(find.text('pick'), findsNothing);
    });
  });

  group('tabs', () {
    Future<GoRouter> shell(WidgetTester tester, {bool reduced = false}) async {
      tester.view.physicalSize = _size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      if (reduced) {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
      }
      final router = GoRouter(
        initialLocation: '/one',
        routes: [
          StatefulShellRoute(
            pageBuilder: (context, state, shell) => handoffPage(state, shell),
            navigatorContainerBuilder: FadeThroughBranches.builder,
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/one',
                    pageBuilder: (c, s) => pushPage(s, const _Page('one')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/two',
                    pageBuilder: (c, s) => pushPage(s, const _Page('two')),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      return router;
    }

    testWidgets('cross with the 200 ms fade-through, nothing moves', (
      tester,
    ) async {
      final router = await shell(tester);
      router.go('/two');
      await tester.pump();
      await tester.pump(_ms * 50);
      expect(
        _opacity(tester, 'one'),
        closeTo(1 - FadeThroughCurves.outgoing.transform(0.25), 0.01),
      );
      expect(
        _opacity(tester, 'two'),
        closeTo(FadeThroughCurves.incoming.transform(0.25), 0.01),
      );
      expect(_dx(tester, 'two'), 0);
      await tester.pump(_ms * 50);
      expect(_opacity(tester, 'one'), 0);
      await tester.pump(_ms * 100);
      expect(_opacity(tester, 'two'), 1);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('one')), findsNothing);
    });

    testWidgets('reduced motion: a cut', (tester) async {
      final router = await shell(tester, reduced: true);
      router.go('/two');
      await tester.pump();
      expect(find.byKey(const ValueKey('one')), findsNothing);
      expect(_opacity(tester, 'two'), 1);
    });
  });

  group('dissolve', () {
    Widget state(String name, {bool reduced = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Dissolve(
          child: KeyedSubtree(key: ValueKey('$name state'), child: _Page(name)),
        ),
      ),
    );

    testWidgets('the new state crosses over the old, 300 ms', (tester) async {
      await tester.pumpWidget(state('old'));
      await tester.pumpWidget(state('new'));
      await tester.pump(_ms * 150);
      expect(_opacity(tester, 'new'), closeTo(_eo(0.5), 0.01));
      expect(_opacity(tester, 'old'), closeTo(_eo(0.5), 0.01));
      await tester.pump(_ms * 150);
      expect(_opacity(tester, 'new'), 1);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('old')), findsNothing);
    });

    testWidgets('reduced motion: 150', (tester) async {
      await tester.pumpWidget(state('old', reduced: true));
      await tester.pumpWidget(state('new', reduced: true));
      await tester.pump(_ms * 75);
      expect(_opacity(tester, 'new'), closeTo(_eo(0.5), 0.01));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('old')), findsNothing);
    });
  });

  group('overlay', () {
    Widget overlay({required bool shown, bool reduced = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: _size, disableAnimations: reduced),
        child: IqOverlay(
          shown: shown,
          scrim: IqScrim.tip,
          delay: IqDurations.tipWait,
          top: (constraints) => 280,
          card: const SizedBox(key: ValueKey('card'), width: 300, height: 200),
        ),
      ),
    );

    testWidgets('waits for Home, then the scrim and the card arrive', (
      tester,
    ) async {
      await tester.pumpWidget(overlay(shown: true));
      await tester.pump(_ms * 600);
      expect(_opacity(tester, 'card'), 0);
      await tester.pump(_ms * 120);
      expect(_opacity(tester, 'card'), closeTo(_eo(60 / 280), 0.01));
      await tester.pump(_ms * 220);
      expect(_opacity(tester, 'card'), 1);
      expect(_dy(tester, 'card'), 280);

      await tester.pumpWidget(overlay(shown: false));
      await tester.pump(_ms * 80);
      expect(_opacity(tester, 'card'), closeTo(1 - _ei(0.5), 0.01));
      expect(_dy(tester, 'card'), greaterThan(280));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('card')), findsNothing);
    });

    testWidgets('reduced motion: both fade in place, 150', (tester) async {
      await tester.pumpWidget(overlay(shown: true, reduced: true));
      await tester.pump(_ms * 75);
      expect(_opacity(tester, 'card'), closeTo(_eo(0.5), 0.01));
      expect(_dy(tester, 'card'), 280);
      await tester.pump(_ms * 75);
      expect(_opacity(tester, 'card'), 1);
      await tester.pump(_ms);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('heroes', () {
    Widget page(String name, Alignment at) => ColoredBox(
      color: IqColors.bg,
      child: Align(
        alignment: at,
        child: Hero(
          tag: 'mark',
          child: SizedBox(key: ValueKey('mark-$name'), width: 40, height: 40),
        ),
      ),
    );

    Future<GoRouter> heroes(WidgetTester tester, {required bool reduced}) =>
        _pumpWith(
          tester,
          GoRouter(
            initialLocation: '/one',
            routes: [
              GoRoute(
                path: '/one',
                pageBuilder: (c, s) =>
                    pushPage(s, page('one', Alignment.topLeft)),
              ),
              GoRoute(
                path: '/two',
                pageBuilder: (c, s) =>
                    pushPage(s, page('two', Alignment.bottomRight)),
              ),
            ],
          ),
          reduced: reduced,
        );

    bool flying(WidgetTester tester) =>
        find.byKey(const ValueKey('mark-two')).evaluate().isNotEmpty &&
        tester.getTopLeft(find.byKey(const ValueKey('mark-two'))) !=
            const Offset(350, 804);

    testWidgets('a shared element flies with the push', (tester) async {
      final router = await heroes(tester, reduced: false);
      router.push('/two');
      await tester.pump();
      await tester.pump();
      await tester.pump(_ms * 100);
      expect(flying(tester), isTrue);
      await tester.pumpAndSettle();
    });

    testWidgets('reduced motion: no flight, the element waits in place', (
      tester,
    ) async {
      final router = await heroes(tester, reduced: true);
      router.push('/two');
      await tester.pump();
      await tester.pump();
      await tester.pump(_ms * 75);
      expect(flying(tester), isFalse);
      await tester.pumpAndSettle();
    });
  });
}
