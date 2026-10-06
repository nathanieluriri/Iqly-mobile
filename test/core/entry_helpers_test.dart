import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/core/transitions.dart';
import 'package:iqly_mobile/theme/theme.dart';

const _ms = Duration(milliseconds: 1);

double _eo(double t) => IqCurves.easeOut.transform(t);

void _reduce(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

double _opacity(WidgetTester tester, Finder finder) {
  var opacity = 1.0;
  for (final widget in tester.widgetList(
    find.ancestor(
      of: finder,
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

double _dy(WidgetTester tester, Finder finder) => tester.getTopLeft(finder).dy;

Widget _app(Widget child) => MaterialApp(
  theme: buildTheme(),
  home: Scaffold(
    body: Align(alignment: Alignment.topLeft, child: child),
  ),
);

class _Page extends StatelessWidget {
  const _Page(this.name, {this.chrome, this.content});

  final String name;
  final Widget? chrome;
  final Widget? content;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: IqColors.bg,
      child: SizedBox.expand(
        key: ValueKey(name),
        child: Stack(
          children: [
            if (chrome case final chrome?)
              Positioned(left: 100, top: 100, child: chrome),
            if (content case final content?)
              Positioned(left: 0, top: 300, child: content),
            Positioned(
              left: 0,
              top: 600,
              child: Text('direction ${arrivalOf(context).name}'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Look extends StatelessWidget {
  const _Look(this.lit);

  final bool lit;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 40,
    child: ColoredBox(
      key: ValueKey(lit ? 'lit' : 'unlit'),
      color: lit ? IqColors.brand : IqColors.line,
    ),
  );
}

GoRouter _router(Widget Function(String name) page) => GoRouter(
  initialLocation: '/a',
  routes: [
    for (final name in ['a', 'b'])
      GoRoute(path: '/$name', pageBuilder: (c, s) => pushPage(s, page(name))),
    GoRoute(
      path: '/land',
      pageBuilder: (c, s) => handoffPage(s, const _Page('land')),
    ),
  ],
);

Future<GoRouter> _pumpRouter(
  WidgetTester tester,
  Widget Function(String name) page,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = _router(page);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(theme: buildTheme(), routerConfig: router),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  group('RevealSlot', () {
    Widget slot(bool shown, [String text = 'Help']) => SizedBox(
      width: 200,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RevealSlot(
            shown: shown,
            child: SizedBox(key: ValueKey(text), height: 20, child: Text(text)),
          ),
          const SizedBox(key: ValueKey('below'), height: 10),
        ],
      ),
    );

    testWidgets('the slot grows with the line over 160, ease-out', (
      tester,
    ) async {
      await tester.pumpWidget(_app(slot(false)));
      expect(find.text('Help'), findsNothing);
      await tester.pumpWidget(_app(slot(true)));
      await tester.pump(_ms * 80);
      final below = find.byKey(const ValueKey('below'));
      expect(_dy(tester, below), closeTo(20 * _eo(0.5), 0.5));
      expect(_opacity(tester, find.text('Help')), closeTo(_eo(0.5), 0.01));
      await tester.pump(_ms * 80);
      expect(_dy(tester, below), 20);
    });

    testWidgets('it folds and fades in 150, then leaves the tree', (
      tester,
    ) async {
      await tester.pumpWidget(_app(slot(true)));
      await tester.pumpWidget(_app(slot(false)));
      await tester.pump(_ms * 75);
      expect(find.text('Help'), findsOneWidget);
      expect(_opacity(tester, find.text('Help')), lessThan(1));
      await tester.pump(_ms * 80);
      expect(find.text('Help'), findsNothing);
      expect(_dy(tester, find.byKey(const ValueKey('below'))), 0);
    });

    testWidgets('reduced motion: open at once and crossfading; gone at once', (
      tester,
    ) async {
      _reduce(tester);
      await tester.pumpWidget(_app(slot(false)));
      await tester.pumpWidget(_app(slot(true)));
      await tester.pump();
      expect(_dy(tester, find.byKey(const ValueKey('below'))), 20);
      await tester.pump(_ms * 75);
      expect(_opacity(tester, find.text('Help')), closeTo(_eo(0.5), 0.02));
      await tester.pump(_ms * 80);
      await tester.pumpWidget(_app(slot(false)));
      expect(find.text('Help'), findsNothing);
    });
  });

  group('Sequence', () {
    Widget sequence({bool play = true}) => Sequence(
      length: const Duration(milliseconds: 380),
      play: play,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Beat(child: SizedBox(key: ValueKey('first'), height: 20)),
          Beat(
            at: Duration(milliseconds: 160),
            child: SizedBox(key: ValueKey('late'), height: 20),
          ),
        ],
      ),
    );

    testWidgets('each beat plays its move from its own offset', (tester) async {
      await tester.pumpWidget(_app(sequence()));
      final late = find.byKey(const ValueKey('late'));
      await tester.pump(_ms * 150);
      expect(_opacity(tester, late), 0);
      await tester.pump(_ms * 120);
      expect(_opacity(tester, late), closeTo(_eo(110 / 220), 0.01));
      expect(_dy(tester, late), closeTo(20 + 8 * (1 - _eo(110 / 220)), 0.5));
      await tester.pumpAndSettle();
      expect(_opacity(tester, late), 1);
      expect(_dy(tester, late), 20);
    });

    testWidgets('not played: everything in place', (tester) async {
      await tester.pumpWidget(_app(sequence(play: false)));
      expect(_opacity(tester, find.byKey(const ValueKey('late'))), 1);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('reduced motion: the beats fade in together over 150', (
      tester,
    ) async {
      _reduce(tester);
      await tester.pumpWidget(_app(sequence()));
      await tester.pump(_ms * 75);
      final first = _opacity(tester, find.byKey(const ValueKey('first')));
      expect(first, closeTo(_eo(0.5), 0.02));
      expect(_opacity(tester, find.byKey(const ValueKey('late'))), first);
      expect(_dy(tester, find.byKey(const ValueKey('late'))), 20);
      await tester.pump(_ms * 80);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('ChromeHero', () {
    Widget page(String name) => _Page(
      name,
      chrome: ChromeHero(
        tag: 'chrome',
        shuttle: ChromeHero.crossfade((look) => (look as _Look).lit),
        child: _Look(name == 'a'),
      ),
      content: Text('content $name'),
    );

    testWidgets('holds still while the pages slide, crossfading its look', (
      tester,
    ) async {
      final router = await _pumpRouter(tester, page);
      router.go('/b');
      await tester.pump();
      await tester.pump();
      await tester.pump(_ms * 150);
      final lit = find.byKey(const ValueKey('lit'));
      final unlit = find.byKey(const ValueKey('unlit'));
      expect(tester.getTopLeft(unlit.last), const Offset(100, 100));
      expect(tester.getTopLeft(lit.last), const Offset(100, 100));
      expect(
        tester.getTopLeft(find.text('content b')).dx,
        closeTo(24 * (1 - _eo(0.5)), 0.5),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(unlit), const Offset(100, 100));
      expect(lit, findsNothing);
    });

    testWidgets('a tap on the arriving chrome mid-flight still lands', (
      tester,
    ) async {
      var taps = 0;
      final router = await _pumpRouter(
        tester,
        (name) => _Page(
          name,
          chrome: ChromeHero(
            tag: 'button',
            child: GestureDetector(
              onTap: () => taps++,
              child: const SizedBox.square(
                dimension: 44,
                child: ColoredBox(color: IqColors.brand),
              ),
            ),
          ),
        ),
      );
      router.go('/b');
      await tester.pump();
      await tester.pump();
      await tester.pump(_ms * 150);
      await tester.tapAt(const Offset(122, 122));
      expect(taps, 1);
      await tester.pumpAndSettle();
    });
  });

  group('PushTrail and arrivalOf', () {
    Widget page(String name) =>
        _Page(name, content: PushTrail(child: Text('control $name')));

    testWidgets('the control trails its page by 40 ms', (tester) async {
      final router = await _pumpRouter(tester, page);
      router.go('/b');
      await tester.pump();
      await tester.pump();
      await tester.pump(_ms * 100);
      const lag = 40 / 300;
      final own = _eo(((100 / 300) - lag) / (1 - lag));
      expect(
        tester.getTopLeft(find.text('control b')).dx,
        closeTo(24 * (1 - own), 0.5),
      );
      expect(find.text('direction forward'), findsWidgets);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('control b')).dx, 0);
    });

    testWidgets('a page brought back mirrors it and knows it came back', (
      tester,
    ) async {
      final router = await _pumpRouter(tester, page);
      router.go('/b', extra: NavDirection.back);
      await tester.pump();
      await tester.pump();
      await tester.pump(_ms * 100);
      const lag = 40 / 240;
      final own = _eo(((100 / 240) - lag) / (1 - lag));
      expect(
        tester.getTopLeft(find.text('control b')).dx,
        closeTo(-24 * (1 - own), 0.5),
      );
      await tester.pumpAndSettle();
      expect(find.text('direction back'), findsOneWidget);
    });
  });

  testWidgets('the lockup arrival takes over with no transition', (
    tester,
  ) async {
    final router = await _pumpRouter(tester, (name) => _Page(name));
    router.go('/land', extra: Arrival.lockup);
    await tester.pump();
    await tester.pump();
    expect(_opacity(tester, find.byKey(const ValueKey('land'))), 1);
    await tester.pump();
    expect(find.byKey(const ValueKey('a')), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
