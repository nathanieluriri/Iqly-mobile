import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/features/entry/landing_screen.dart';
import 'package:iqly_mobile/features/entry/line_art_loop.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/box_field.dart';
import 'package:iqly_mobile/ui/brand_logo.dart';
import 'package:iqly_mobile/ui/provider_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../golden/golden.dart';

const _ms = Duration(milliseconds: 1);
const _keyboard = 336.0;

double _eo(double t) => IqCurves.easeOut.transform(t);
double _ei(double t) => IqCurves.easeIn.transform(t);

/// The landing at [size] with the OS insets, its entrance played out.
Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double top = 54,
  double bottom = 34,
  bool reduced = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
  tester.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
  addTearDown(tester.view.reset);
  if (reduced) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(theme: buildTheme(), home: const LandingScreen()),
    ),
  );
  await tester.pump(_ms * 700);
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

Rect _rect(WidgetTester tester, Finder finder) => tester.getRect(finder);

final _apple = find.text('Continue with Apple');
final _appleButton = find.byType(IqProviderButton).first;
final _continue = find.text('Continue');
final _link = find.text('Already with us?');

double _drawingScale(WidgetTester tester) => tester
    .widget<Transform>(
      find
          .ancestor(
            of: find.byType(LineArtLoop),
            matching: find.byType(Transform),
          )
          .first,
    )
    .transform
    .storage[0];

/// The keyboard rises 336 over 20 frames, as the OS animates it.
Future<List<Object>> _raiseKeyboard(
  WidgetTester tester, {
  required double top,
  required double bottom,
}) async {
  final errors = <Object>[];
  for (var i = 1; i <= 20; i++) {
    final k = _keyboard * IqCurves.easeOut.transform(i / 20);
    tester.view.viewInsets = FakeViewPadding(bottom: k);
    tester.view.padding = FakeViewPadding(
      top: top,
      bottom: (bottom - k).clamp(0, bottom),
    );
    await tester.pump(_ms * 16);
    final error = tester.takeException();
    if (error != null) errors.add(error);
  }
  return errors;
}

void main() {
  setUpAll(loadAppFonts);

  group('focus (spec 4.2)', () {
    testWidgets('the providers fade in 90 as their slot closes over 300', (
      tester,
    ) async {
      await _pump(tester);
      final rest =
          _rect(tester, find.byType(IqBoxField)).top -
          _rect(tester, _appleButton).top;
      expect(rest, closeTo(166, 0.5));

      await tester.tap(find.byType(IqBoxField));
      await tester.pump();
      await tester.pump(_ms * 45);
      expect(_opacity(tester, _apple), closeTo(1 - _ei(0.5), 0.02));
      await tester.pump(_ms * 45);
      expect(_opacity(tester, _apple), closeTo(0, 0.01));

      await tester.pump(_ms * 60);
      final slot =
          _rect(tester, find.byType(IqBoxField)).top -
          _rect(tester, _appleButton).top;
      expect(slot, closeTo(166 * (1 - _eo(0.5)), 0.6));
      expect(
        _drawingScale(tester),
        closeTo((220 - 100 * _eo(0.5)) / 220, 0.002),
      );
      expect(
        _opacity(tester, _continue),
        closeTo(_eo((150 - 120) / 180), 0.02),
      );

      await tester.pump(_ms * 150);
      await tester.pump(_ms * 20);
      expect(_apple, findsNothing);
      expect(_link, findsNothing);
      expect(_opacity(tester, _continue), 1);
      expect(_drawingScale(tester), closeTo(120 / 220, 0.001));
      expect(
        _rect(tester, find.byType(IqBrandLogo)).top,
        closeTo(54 + IqSpace.s2, 0.01),
      );
    });

    for (final reduced in [false, true]) {
      testWidgets('the box keeps its keyboard through the focus'
          '${reduced ? ' (reduced motion)' : ''}', (tester) async {
        await _pump(tester, reduced: reduced);
        await tester.tap(find.byType(IqBoxField));
        await tester.pump();
        final field = tester.state<EditableTextState>(
          find.byType(EditableText),
        );
        for (var i = 0; i < 40; i++) {
          await tester.pump(_ms * 16);
          expect(tester.testTextInput.isVisible, isTrue);
          expect(tester.state(find.byType(EditableText)), same(field));
        }
        expect(_apple, findsNothing);
        await tester.enterText(find.byType(EditableText), 'adaeze@');
        expect(find.text('adaeze@'), findsOneWidget);
      });
    }

    testWidgets('unfocus: Continue fades in 90, the rows come back over 120', (
      tester,
    ) async {
      await _pump(tester);
      await tester.tap(find.byType(IqBoxField));
      await tester.pump();
      await tester.pump(_ms * 400);

      await tester.tap(find.text('The arena for bold African thinkers.'));
      await tester.pump();
      await tester.pump(_ms * 45);
      expect(_opacity(tester, _continue), closeTo(_eo(0.5), 0.03));
      await tester.pump(_ms * 50);
      expect(_opacity(tester, _continue), closeTo(0, 0.01));
      expect(_opacity(tester, _apple), closeTo(0, 0.01));
      await tester.pump(_ms * 85);
      expect(_opacity(tester, _apple), closeTo(_eo(0.5), 0.03));
      await tester.pump(_ms * 70);
      await tester.pump(_ms * 100);
      expect(_opacity(tester, _apple), 1);
      expect(_continue, findsNothing);
      expect(_drawingScale(tester), 1);
      expect(
        _rect(tester, find.byType(IqBrandLogo)).top,
        closeTo(54 + LandingScreen.logoTop, 0.01),
      );
    });

    testWidgets('reduced motion: the focused layout at once, Continue fades', (
      tester,
    ) async {
      await _pump(tester, reduced: true);
      await tester.tap(find.byType(IqBoxField));
      await tester.pump();
      expect(_apple, findsNothing);
      expect(_drawingScale(tester), closeTo(120 / 220, 0.001));
      expect(_opacity(tester, _continue), closeTo(0, 0.01));
      await tester.pump(_ms * 75);
      expect(_opacity(tester, _continue), closeTo(_eo(0.5), 0.02));
      await tester.pump(_ms * 80);
      expect(_opacity(tester, _continue), 1);
    });

    for (final (name, size, top, bottom) in [
      ('390 x 844', const Size(390, 844), 54.0, 34.0),
      ('375 x 667', const Size(375, 667), 20.0, 0.0),
    ]) {
      testWidgets(
        '$name: no overflow as a 336 keyboard rises, box and Continue above it',
        (tester) async {
          await _pump(tester, size: size, top: top, bottom: bottom);
          await tester.ensureVisible(find.byType(IqBoxField));
          await tester.pump();
          await tester.tap(find.byType(IqBoxField));
          final errors = await _raiseKeyboard(tester, top: top, bottom: bottom);
          expect(errors, isEmpty);
          await tester.pump(_ms * 500);
          expect(tester.takeException(), isNull);
          final keyboardTop = size.height - _keyboard;
          expect(_rect(tester, find.byType(IqBoxField)).top, greaterThan(top));
          expect(
            _rect(tester, _continue).bottom,
            lessThanOrEqualTo(keyboardTop),
          );
        },
      );
    }
  });

  group('entrance (spec 6.2)', () {
    testWidgets('the headline at +60, then the rows 40 apart from +120', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(theme: buildTheme(), home: const LandingScreen()),
        ),
      );
      final headline = find.text('The arena for bold African thinkers.');
      final legal = find.textContaining('By continuing');
      expect(_opacity(tester, find.byType(IqBrandLogo)), 1);
      await tester.pump(_ms * 50);
      expect(_opacity(tester, headline), 0);
      await tester.pump(_ms * 120);
      expect(_opacity(tester, headline), closeTo(_eo(110 / 220), 0.02));
      expect(_opacity(tester, _apple), closeTo(_eo(50 / 260), 0.02));
      expect(_opacity(tester, legal), 0);
      await tester.pump(_ms * 410);
      expect(_opacity(tester, legal), 1);
      expect(_opacity(tester, _apple), 1);
    });

    testWidgets('reduced motion: it all fades in together over 150', (
      tester,
    ) async {
      await _pump(tester, reduced: true);
      expect(_opacity(tester, _apple), 1);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
