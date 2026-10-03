import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iqly_mobile/core/transitions.dart';
import 'package:iqly_mobile/theme/theme.dart';

const _ms = Duration(milliseconds: 1);

var _asks = 0;

/// A search field that asks for the keyboard once its route has arrived,
/// the way the university and city sheets do.
class _Search extends StatefulWidget {
  const _Search();

  @override
  State<_Search> createState() => _SearchState();
}

class _SearchState extends State<_Search> {
  final _focus = FocusNode();
  bool _asked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_asked) return;
    _asked = true;
    whenArrived(context, () {
      _asks++;
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    child: SizedBox(
      width: double.infinity,
      height: 400,
      child: TextField(focusNode: _focus),
    ),
  );
}

class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) => Material(
    child: Center(
      child: TextButton(
        onPressed: () => showIqSheet<void>(
          context,
          (context) => const _Search(),
          scrim: IqScrim.picker,
        ),
        child: const Text('open'),
      ),
    ),
  );
}

Future<GoRouter> _pump(WidgetTester tester, {bool reduced = false}) async {
  _asks = 0;
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  if (reduced) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/home', pageBuilder: (c, s) => pushPage(s, const _Home())),
      GoRoute(
        path: '/page',
        pageBuilder: (c, s) => pushPage(s, const _Search()),
      ),
      GoRoute(
        path: '/sheet',
        pageBuilder: (c, s) =>
            sheetPage(s, const _Search(), scrim: IqScrim.picker),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(theme: buildTheme(), routerConfig: router),
  );
  await tester.pumpAndSettle();
  return router;
}

bool _keyboard(WidgetTester tester) => tester.testTextInput.isVisible;

/// Plays [open]'s 300 ms arrival and checks the keyboard waits for its end.
Future<void> _waitsFor300(
  WidgetTester tester,
  Future<void> Function() open,
) async {
  await open();
  await tester.pump();
  await tester.pump();
  expect(_keyboard(tester), isFalse, reason: 'on the first frames');
  await tester.pump(_ms * 150);
  expect(_keyboard(tester), isFalse, reason: 'halfway');
  await tester.pump(_ms * 140);
  expect(_keyboard(tester), isFalse, reason: 'just before the end');
  await tester.pump(_ms * 11);
  await tester.pump();
  expect(_keyboard(tester), isTrue, reason: 'once arrived');
  expect(_asks, 1);
}

void main() {
  testWidgets('a sheet page takes the keyboard after its 300 rise', (
    tester,
  ) async {
    final router = await _pump(tester);
    await _waitsFor300(tester, () async {
      router.push('/sheet');
    });
  });

  testWidgets('showIqSheet takes the keyboard after its 300 rise', (
    tester,
  ) async {
    await _pump(tester);
    await _waitsFor300(tester, () => tester.tap(find.text('open')));
  });

  testWidgets('a pushed page takes the keyboard after its 300 push', (
    tester,
  ) async {
    final router = await _pump(tester);
    await _waitsFor300(tester, () async {
      router.push('/page');
    });
  });

  testWidgets('a sheet closed before it has risen never asks', (tester) async {
    final router = await _pump(tester);
    router.push('/sheet');
    await tester.pump();
    await tester.pump();
    await tester.pump(_ms * 100);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(_Search), findsNothing);
    expect(_asks, 0);
    expect(_keyboard(tester), isFalse);
  });

  testWidgets('reduced motion: the field asks at once', (tester) async {
    final router = await _pump(tester, reduced: true);
    router.push('/sheet');
    await tester.pump();
    await tester.pump();
    expect(_keyboard(tester), isTrue);
  });
}
