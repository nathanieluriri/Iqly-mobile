import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/app.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/onboarding_service.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/features/onboarding/about_you_screen.dart';
import 'package:iqly_mobile/features/onboarding/done_screen.dart';
import 'package:iqly_mobile/features/onboarding/onboarding_sheets.dart';
import 'package:iqly_mobile/features/onboarding/what_you_like_screen.dart';
import 'package:iqly_mobile/features/onboarding/where_you_live_screen.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/button.dart';
import 'package:iqly_mobile/ui/illustration.dart';
import 'package:iqly_mobile/ui/next_fab.dart';
import 'package:iqly_mobile/ui/option_row.dart';
import 'package:iqly_mobile/ui/step_mark.dart';
import 'package:iqly_mobile/ui/ticket_card.dart';
import 'package:iqly_mobile/ui/top_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'entry_harness.dart';

const _ms = Duration(milliseconds: 1);
const _light = 'HapticFeedbackType.lightImpact';
const _select = 'HapticFeedbackType.selectionClick';
const _success = 'HapticFeedbackType.successNotification';
const _keyboard = 336.0;

double _eo(double t) => IqCurves.easeOut.transform(t);
double _ei(double t) => IqCurves.easeIn.transform(t);
double _eio(double t) => IqCurves.easeInOut.transform(t);

class _NoSave implements OnboardingService {
  @override
  Future<void> saveProfile(OnboardingProfile profile) async {}
}

/// The app opened straight on [route], signed in with [draft] saved.
Future<void> _open(
  WidgetTester tester,
  String route, {
  Map<String, Object?> draft = const {},
  bool reduced = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 54, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 54, bottom: 34);
  addTearDown(tester.view.reset);
  if (reduced) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  SharedPreferences.setMockInitialValues({
    'session.signedIn': true,
    'onboarding.draft': jsonEncode(draft),
  });
  final prefs = await SharedPreferences.getInstance();
  final router = buildRouter(initialLocation: route);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        routerProvider.overrideWithValue(router),
        repositoryProvider.overrideWithValue(DemoRepository(DemoData())),
        onboardingServiceProvider.overrideWithValue(_NoSave()),
      ],
      child: const IqlyApp(),
    ),
  );
}

/// The product of every fade above [finder].
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

final _shuttle = find.byWidgetPredicate(
  (w) => w.runtimeType.toString() == '_Morph',
);

List<double> _slots(WidgetTester tester, Finder mark) {
  final row = tester.renderObject<RenderFlex>(
    find.descendant(of: mark, matching: find.byType(Row)).first,
  );
  final widths = <double>[];
  var child = row.firstChild;
  while (child != null) {
    if (child.size.height == IqStepMark.ring) widths.add(child.size.width);
    child = (child.parentData! as FlexParentData).nextSibling;
  }
  return widths;
}

Future<void> _playTo(WidgetTester tester, Duration at) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(at);
}

/// Where a search sheet's "Use this" sits: Figma 188:8340 draws it at y 720
/// with the ghost at 780, 12 above the bottom edge; on a phone with a home
/// indicator the foot keeps clear of it.
const _useThis = 844 - 34 - 52 - 8 - 52.0;

double _top(WidgetTester tester, String label) =>
    tester.getTopLeft(find.widgetWithText(IqButton, label)).dy;

bool _on(WidgetTester tester, String label) =>
    !tester.widget<IqButton>(find.widgetWithText(IqButton, label)).disabled;

const _studied = {
  'occupation': 'student',
  'state': 'Lagos',
  'city': 'Yaba',
  'education': 'hnd_bsc',
  'lastStep': 'whereYouStudied',
};

void main() {
  setUp(() => EditableText.debugDeterministicCursor = true);
  tearDown(() => EditableText.debugDeterministicCursor = false);

  group('one question per screen (spec 4.1)', () {
    testWidgets(
      'About you to Where you live: back, Skip and the next button hold, '
      'the mark morphs, the question rides the push, the control trails',
      (tester) async {
        final haptics = recordHaptics(tester);
        await _open(
          tester,
          Routes.onboardingAboutYou,
          draft: {'occupation': 'student', 'lastStep': 'aboutYou'},
        );
        await tester.pumpAndSettle();
        final back = tester.getTopLeft(find.byType(IqTopBar));
        final mark = tester.getTopLeft(find.byType(IqStepMark));
        final skip = tester.getTopLeft(find.text('Skip'));
        final next = tester.getTopLeft(find.byType(IqNextFab));
        final question = tester.getTopLeft(find.text('What do you do?')).dx;

        await tester.tap(find.byType(IqNextFab));
        await _playTo(tester, _ms * 150);
        expect(tester.getTopLeft(find.byType(IqTopBar).last), back);
        expect(tester.getTopLeft(_shuttle.last), mark);
        final grown = 6 + 38 * _eio(0.5);
        final slots = _slots(tester, _shuttle.last);
        expect(slots[0], closeTo(50 - grown, 0.01));
        expect(slots[1], closeTo(grown, 0.01));
        expect(slots[2], 6);
        expect(tester.getTopLeft(find.text('Skip').last), skip);
        expect(tester.getTopLeft(find.byType(IqNextFab).last), next);
        expect(
          tester.getTopLeft(find.text('What do you do?')).dx,
          closeTo(question - 24 * _ei(0.5), 0.5),
        );
        final title = find.text('Where do you live?');
        expect(
          tester.getTopLeft(title).dx,
          closeTo(question + 24 * (1 - _eo(0.5)), 0.5),
        );
        final control = find.text('Select state');
        double trail() =>
            tester.getTopLeft(control).dx - tester.getTopLeft(title).dx;
        final midTrail = trail();

        await tester.pumpAndSettle();
        expect(find.byType(WhereYouLiveScreen), findsOneWidget);
        expect(find.byType(AboutYouScreen), findsNothing);
        expect(_slots(tester, find.byType(IqStepMark)), [6, 44, 6]);
        const lag = 40 / 300;
        final own = _eo((0.5 - lag) / (1 - lag));
        expect(midTrail - trail(), closeTo(24 * (_eo(0.5) - own), 0.5));
        expect(haptics, [_light]);
      },
    );

    testWidgets('back mirrors it: the earlier step comes in from the left '
        'over 240, the mark morphing back', (tester) async {
      await _open(
        tester,
        Routes.onboardingWhereYouLive,
        draft: {'occupation': 'student', 'lastStep': 'whereYouLive'},
      );
      await tester.pumpAndSettle();
      final question = tester.getTopLeft(find.text('Where do you live?')).dx;
      await tester.tap(find.bySemanticsLabel('Back'));
      await _playTo(tester, _ms * 120);
      expect(
        tester.getTopLeft(find.text('What do you do?')).dx,
        closeTo(question - 24 * (1 - _eo(0.5)), 0.5),
      );
      expect(
        tester.getTopLeft(find.text('Where do you live?')).dx,
        closeTo(question + 24 * _ei(0.5), 0.5),
      );
      final grown = 6 + 38 * _eio(0.5);
      final slots = _slots(tester, _shuttle.last);
      expect(slots[0], closeTo(grown, 0.01));
      expect(slots[1], closeTo(50 - grown, 0.01));
      await tester.pumpAndSettle();
      expect(find.byType(AboutYouScreen), findsOneWidget);
      expect(_slots(tester, find.byType(IqStepMark)), [44, 6, 6]);
    });

    testWidgets('reduced motion: the next step crossfades in place, its mark '
        'already set', (tester) async {
      await _open(
        tester,
        Routes.onboardingAboutYou,
        draft: {'occupation': 'student', 'lastStep': 'aboutYou'},
        reduced: true,
      );
      await tester.pumpAndSettle();
      final question = tester.getTopLeft(find.text('What do you do?')).dx;
      await tester.tap(find.byType(IqNextFab));
      await _playTo(tester, _ms * 75);
      final title = find.text('Where do you live?');
      expect(tester.getTopLeft(title).dx, question);
      expect(_opacity(tester, title), closeTo(_eo(0.5), 0.02));
      final mark = find.byType(IqStepMark).last;
      expect(_slots(tester, mark), [6, 44, 6]);
      expect(_opacity(tester, mark), closeTo(_eo(0.5), 0.02));
      await tester.pump(_ms * 80);
      expect(_opacity(tester, title), 1);
    });
  });

  group('Where you studied (spec 6.14, 6.15)', () {
    testWidgets(
      'University: the sheet rises 300, then the search takes the keyboard',
      (tester) async {
        await _open(tester, Routes.onboardingWhereYouStudied, draft: _studied);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Search universities'));
        await _playTo(tester, _ms * 150);
        final sheet = find.byType(UniversitySheet);
        expect(
          tester.getTopLeft(sheet).dy,
          closeTo(120 + 724 * (1 - _eo(0.5)), 0.5),
        );
        expect(tester.testTextInput.isVisible, isFalse);
        await tester.pump(_ms * 140);
        expect(tester.testTextInput.isVisible, isFalse);
        await tester.pump(_ms * 11);
        await tester.pump();
        expect(tester.getTopLeft(sheet).dy, 120);
        expect(tester.testTextInput.isVisible, isTrue);
      },
    );

    testWidgets('University: results sit above the keyboard, the foot under '
        'it; a pick puts the keyboard away', (tester) async {
      final haptics = recordHaptics(tester);
      await _open(tester, Routes.onboardingWhereYouStudied, draft: _studied);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Search universities'));
      await tester.pumpAndSettle();
      expect(_top(tester, 'Use this'), _useThis);
      expect(_top(tester, 'Add my university'), _useThis + 60);

      tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
      await tester.pump();
      const keyboardTop = 844 - _keyboard;
      final results = find.descendant(
        of: find.byType(UniversitySheet),
        matching: find.byType(IqOptionRow),
      );
      final above = results.evaluate().where((row) {
        final box = row.renderObject! as RenderBox;
        return box.localToGlobal(box.size.bottomLeft(Offset.zero)).dy <=
            keyboardTop;
      });
      expect(above.length, greaterThanOrEqualTo(3));
      expect(_top(tester, 'Use this'), greaterThanOrEqualTo(keyboardTop));

      await tester.tap(find.text('University of Lagos'));
      await tester.pump();
      expect(tester.testTextInput.isVisible, isFalse);
      expect(haptics, [_select]);
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      expect(_on(tester, 'Use this'), isTrue);
    });

    testWidgets('Use this: the sheet drops, the university lands on the step, '
        'then the step moves on', (tester) async {
      final haptics = recordHaptics(tester);
      await _open(tester, Routes.onboardingWhereYouStudied, draft: _studied);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Search universities'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('University of Lagos'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Use this'));
      await tester.pump();
      await tester.pump(_ms * 100);
      expect(
        tester.getTopLeft(find.byType(UniversitySheet)).dy,
        closeTo(120 + 724 * (1 - _eo(0.5)), 0.5),
      );
      expect(find.text('Search universities'), findsOneWidget);

      await tester.pump(_ms * 101);
      await tester.pump();
      expect(find.byType(UniversitySheet), findsNothing);
      final landed = find.text('University of Lagos');
      expect(landed, findsWidgets);
      await tester.pump(_ms * 170);
      expect(find.byType(WhatYouLikeScreen), findsNothing);
      expect(_opacity(tester, landed.last), greaterThan(0.5));

      await tester.pump(_ms * 171);
      await tester.pump();
      expect(find.byType(WhatYouLikeScreen), findsOneWidget);
      await tester.pumpAndSettle();
      expect(haptics, [_select, _light]);
    });

    testWidgets('reduced motion: Use this lands the university and moves on '
        'at once', (tester) async {
      await _open(
        tester,
        Routes.onboardingWhereYouStudied,
        draft: _studied,
        reduced: true,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Search universities'));
      await tester.pump();
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.pumpAndSettle();
      await tester.tap(find.text('University of Lagos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use this'));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(find.byType(WhatYouLikeScreen), findsOneWidget);
    });

    testWidgets('Education hugs its rows', (tester) async {
      await _open(tester, Routes.onboardingWhereYouStudied, draft: _studied);
      await tester.pumpAndSettle();
      await tester.tap(find.text('HND / BSc'));
      await tester.pumpAndSettle();
      final sheet = tester.getRect(find.byType(OptionSheet));
      final rows = find.descendant(
        of: find.byType(OptionSheet),
        matching: find.byType(IqOptionRow),
      );
      expect(rows, findsNWidgets(5));
      var content = 0.0;
      for (var i = 0; i < 5; i++) {
        content += tester.getSize(rows.at(i)).height;
      }
      expect(sheet.bottom, 844);
      expect(sheet.height, closeTo(76 + 4 + content + 4 * 4 + 16 + 34, 0.5));
      expect(sheet.top, greaterThan(120));
      expect(
        tester.getRect(rows.at(4)).bottom,
        closeTo(sheet.bottom - 16 - 34, 0.5),
      );
    });

    testWidgets('State of residence takes the full 724', (tester) async {
      await _open(
        tester,
        Routes.onboardingWhereYouLive,
        draft: {'occupation': 'student', 'lastStep': 'whereYouLive'},
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select state'));
      await tester.pumpAndSettle();
      final sheet = tester.getRect(find.byType(OptionSheet));
      expect(sheet.top, 120);
      expect(sheet.height, 724);
    });
  });

  testWidgets('City: the foot always offers Add my city, on only for a name '
      'the list lacks; an empty result fades in', (tester) async {
    await _open(
      tester,
      Routes.onboardingWhereYouLive,
      draft: {
        'occupation': 'student',
        'state': 'Lagos',
        'lastStep': 'whereYouLive',
      },
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select city'));
    await tester.pumpAndSettle();
    expect(find.byType(CitySheet), findsOneWidget);
    expect(_on(tester, 'Add my city'), isFalse);
    expect(_top(tester, 'Use this'), _useThis);

    await tester.enterText(find.byType(EditableText), 'Yaba');
    await tester.pumpAndSettle();
    expect(_on(tester, 'Add my city'), isFalse);

    await tester.enterText(find.byType(EditableText), 'Atlantis');
    await tester.pump();
    await tester.pump(_ms * 75);
    final empty = find.text('No city found.');
    expect(_opacity(tester, empty), closeTo(_eo(0.5), 0.05));
    await tester.pumpAndSettle();
    expect(_opacity(tester, empty), 1);
    expect(_on(tester, 'Add my city'), isTrue);
    expect(_top(tester, 'Add my city'), _useThis + 60);
  });

  group('What you like (spec 6.16)', () {
    testWidgets('the off Finish shakes "Pick at least 2" with no haptic; '
        'chips select; Finish plays success', (tester) async {
      final haptics = recordHaptics(tester);
      await _open(
        tester,
        Routes.onboardingWhatYouLike,
        draft: {'occupation': 'student', 'lastStep': 'whatYouLike'},
      );
      await tester.pumpAndSettle();
      final caption = find.text('Pick at least 2');
      final rest = tester.getTopLeft(caption).dx;

      await tester.tap(find.byType(IqNextFab));
      await tester.pump();
      var furthest = 0.0;
      for (var i = 0; i < 12; i++) {
        await tester.pump(_ms * 20);
        final away = (tester.getTopLeft(caption).dx - rest).abs();
        if (away > furthest) furthest = away;
      }
      expect(furthest, inInclusiveRange(1, 2));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(caption).dx, closeTo(rest, 0.01));
      expect(haptics, isEmpty);

      await tester.tap(find.text('Technology'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Business'));
      await tester.pumpAndSettle();
      expect(haptics, [_select, _select]);
      await tester.tap(find.byType(IqNextFab));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(DoneScreen), findsOneWidget);
      expect(haptics, [_select, _select, _light, _success]);
    });
  });

  group('moments', () {
    testWidgets('Done: eyebrow at +80, title at +120, Start here at +200, '
        'the first ticket at +240; the Rocket sits 150 x 120 at (120, 78)', (
      tester,
    ) async {
      await _open(
        tester,
        Routes.onboardingDone,
        draft: {'occupation': 'student', 'lastStep': 'whatYouLike'},
      );
      await tester.pump();
      final eyebrow = find.text('YOU’RE SET');
      final title = find.textContaining('Nice one');
      final start = find.text('Start here');
      expect(_opacity(tester, eyebrow), 0);
      await tester.pump(_ms * 100);
      expect(_opacity(tester, eyebrow), closeTo(_eo(20 / 220), 0.02));
      expect(_opacity(tester, title), 0);
      await tester.pump(_ms * 100);
      expect(_opacity(tester, title), closeTo(_eo(80 / 220), 0.02));
      expect(_opacity(tester, start), 0);
      final ticket = find.byType(IqTicketCard).first;
      expect(_opacity(tester, ticket), 0);
      await tester.pump(_ms * 100);
      expect(_opacity(tester, ticket), closeTo(_eo(60 / 260), 0.02));
      await tester.pumpAndSettle();
      for (final finder in [eyebrow, title, start]) {
        expect(_opacity(tester, finder), 1);
      }
      expect(
        tester.getRect(find.byType(IqIllustration)),
        const Rect.fromLTWH(120, 78, 150, 120),
      );
    });

    testWidgets('reduced motion: Done fades in together over 150', (
      tester,
    ) async {
      await _open(
        tester,
        Routes.onboardingDone,
        draft: {'occupation': 'student', 'lastStep': 'whatYouLike'},
        reduced: true,
      );
      await tester.pump();
      await tester.pump(_ms * 75);
      final eyebrow = _opacity(tester, find.text('YOU’RE SET'));
      expect(eyebrow, closeTo(_eo(0.5), 0.02));
      expect(_opacity(tester, find.text('Start here')), eyebrow);
      await tester.pump(_ms * 80);
      await tester.pump();
      expect(_opacity(tester, find.text('Start here')), 1);
      expect(
        tester.getRect(find.byType(IqIllustration)),
        const Rect.fromLTWH(120, 78, 150, 120),
      );
    });

    testWidgets('Welcome: the three rows arrive 40 apart from +200', (
      tester,
    ) async {
      await _open(tester, Routes.onboarding);
      await tester.pump();
      await tester.pump(_ms * 250);
      final rows = [
        for (final label in [
          'About you',
          'Where you live and study',
          'What you’re into',
        ])
          _opacity(tester, find.text(label)),
      ];
      expect(rows[0], closeTo(_eo(50 / 260), 0.02));
      expect(rows[1], closeTo(_eo(10 / 260), 0.02));
      expect(rows[2], 0);
      await tester.pumpAndSettle();
      expect(_opacity(tester, find.text('What you’re into')), 1);
    });
  });
}
