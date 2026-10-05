import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/app.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/features/entry/landing_screen.dart';
import 'package:iqly_mobile/features/onboarding/done_screen.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/box_field.dart';
import 'package:iqly_mobile/ui/icon.dart';
import 'package:iqly_mobile/ui/step_mark.dart';
import 'package:iqly_mobile/ui/step_mark_ring.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden.dart';
import 'screens/onboarding_harness.dart';

/// Key frames of the choreographies, pumped to fixed times with no settle
/// (spec 8.2). Names carry the time in ms from the start of the move.
String _at(int ms) => ms.toString().padLeft(3, '0');

/// Moves [ms] on at 60 fps, as a phone draws, so parts that start when they
/// are first seen start on time.
Future<void> _frames(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 16) {
    await tester.pump(Duration(milliseconds: ms - t < 16 ? ms - t : 16));
  }
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 54, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 54, bottom: 34);
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(loadAppFonts);
  setUp(() => EditableText.debugDeterministicCursor = true);
  tearDown(() => EditableText.debugDeterministicCursor = false);

  for (final ms in [0, 150, 300]) {
    testWidgets('the landing focus at $ms', (tester) async {
      _phone(tester);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            theme: buildTheme(),
            debugShowCheckedModeBanner: false,
            home: const LandingScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await tester.tap(find.byType(IqBoxField));
      await tester.pump();
      // The keyboard rises with the layout, as the OS animates it.
      final keyboard = 336 * IqCurves.easeOut.transform(ms / 300);
      tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
      tester.view.padding = FakeViewPadding(
        top: 54,
        bottom: math.max(0, 34 - keyboard),
      );
      await _frames(tester, ms);
      await expectMatchesGolden(
        find.byType(MaterialApp),
        'goldens/motion_landing_focus_${_at(ms)}.png',
      );
    });

    testWidgets('the step mark morph at $ms', (tester) async {
      tester.view.physicalSize = const Size(112, 76);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Widget mark(IqStepMarkStep step, IqIcons icon) => MaterialApp(
        theme: buildTheme(),
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: IqColors.bg,
          body: Padding(
            padding: const EdgeInsets.all(IqSpace.s4),
            child: Align(
              alignment: Alignment.topLeft,
              child: IqStepMarkRing(step: step, icon: icon),
            ),
          ),
        ),
      );
      await tester.pumpWidget(mark(IqStepMarkStep.oneOfThree, IqIcons.profile));
      await tester.pumpWidget(mark(IqStepMarkStep.twoOfThree, IqIcons.pin));
      await _frames(tester, ms);
      await expectMatchesGolden(
        find.byType(MaterialApp),
        'goldens/motion_step_mark_${_at(ms)}.png',
      );
    });

    testWidgets('Done at $ms', (tester) async {
      _phone(tester);
      final prefs = await onboardingPrefs(draft: sampleWhatYouLike);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          debugShowCheckedModeBanner: false,
          home: onboardingFrame(prefs, const DoneScreen()),
        ),
      );
      await tester.pump();
      await _frames(tester, ms);
      await expectMatchesGolden(
        find.byType(MaterialApp),
        'goldens/motion_done_${_at(ms)}.png',
      );
      await tester.pump(const Duration(seconds: 1));
    });
  }

  for (final ms in [550, 1550, 2750, 3800]) {
    testWidgets('the first launch splash at $ms', (tester) async {
      _phone(tester);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            repositoryProvider.overrideWithValue(DemoRepository(DemoData())),
          ],
          child: const IqlyApp(),
        ),
      );
      await tester.pump();
      await _frames(tester, ms);
      await expectMatchesGolden(
        find.byType(MaterialApp),
        'goldens/motion_splash_${_at(ms)}.png',
      );
    });
  }
}
