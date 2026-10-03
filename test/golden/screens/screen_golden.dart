import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../golden.dart';

/// Renders a screen at the Figma frame size with the OS status bar (54) and
/// home indicator (34) as safe-area insets, animations off. [keyboard] raises
/// a system keyboard of that height. [prepare] seeds providers before the
/// first frame; [act] drives the screen into the frame's state. [overrides]
/// replace providers such as the repository or swap services (a zero-delay
/// auth, say).
Future<void> expectScreenGolden(
  WidgetTester tester,
  String name,
  Widget screen, {
  Map<String, Object> prefs = const {},
  List<Override> overrides = const [],
  void Function(ProviderContainer container)? prepare,
  Future<void> Function(WidgetTester tester)? act,
  double keyboard = 0,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  final insets = FakeViewPadding(top: 54, bottom: keyboard > 0 ? 0 : 34);
  tester.view.padding = insets;
  tester.view.viewPadding = const FakeViewPadding(top: 54, bottom: 34);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  SharedPreferences.setMockInitialValues(prefs);
  final shared = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(shared),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  prepare?.call(container);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildTheme(),
        debugShowCheckedModeBanner: false,
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (act != null) {
    await act(tester);
    await tester.pumpAndSettle();
  }
  await expectMatchesGolden(find.byType(MaterialApp), 'goldens/$name.png');
}
