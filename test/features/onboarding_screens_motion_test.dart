import 'dart:convert';

import 'package:flutter/material.dart';
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
import 'package:iqly_mobile/features/onboarding/where_you_live_screen.dart';
import 'package:iqly_mobile/features/onboarding/where_you_studied_screen.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/button.dart';
import 'package:iqly_mobile/ui/chip.dart';
import 'package:iqly_mobile/ui/brief_card.dart';
import 'package:iqly_mobile/ui/illustration.dart';
import 'package:iqly_mobile/ui/option_row.dart';
import 'package:iqly_mobile/ui/step_mark.dart';
import 'package:iqly_mobile/ui/top_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'entry_harness.dart';

const _ms = Duration(milliseconds: 1);
const _light = 'HapticFeedbackType.lightImpact';
const _select = 'HapticFeedbackType.lightImpact';
const _success = 'HapticFeedbackType.successNotification';
const _commit = 'HapticFeedbackType.heavyImpact';
const _error = 'HapticFeedbackType.heavyImpact';
const _keyboard = 336.0;

double _eo(double t) => IqCurves.easeOut.transform(t);
double _ei(double t) => IqCurves.easeIn.transform(t);

class _NoSave implements OnboardingService {
  @override
  Future<void> saveProfile(
    OnboardingProfile profile, {
    bool skipped = false,
  }) async {}
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

const _aboutYou = {
  'occupation': 'student',
  'dateOfBirth': '2004-03-12T00:00:00.000',
};

final _primary = find.byWidgetPredicate(
  (w) => w is IqButton && w.kind == IqButtonKind.primary,
);

const _studied = {
  ..._aboutYou,
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
      'About you to Where you study: back, the step mark, Continue and Skip '
      'hold, the question rides the push, the control trails',
      (tester) async {
        final haptics = recordHaptics(tester);
        await _open(
          tester,
          Routes.onboardingAboutYou,
          draft: {..._aboutYou, 'lastStep': 'aboutYou'},
        );
        await tester.pumpAndSettle();
        final back = tester.getTopLeft(find.byType(IqTopBar));
        final mark = tester.getTopLeft(find.byType(IqStepMark));
        final skip = tester.getTopLeft(find.text('Skip for now'));
        final next = tester.getTopLeft(_primary);
        final question = tester.getTopLeft(find.text('What do you do?')).dx;

        await tester.tap(_primary);
        await _playTo(tester, _ms * 150);
        expect(tester.getTopLeft(find.byType(IqTopBar).last), back);
        expect(tester.getTopLeft(find.byType(IqStepMark).last), mark);
        expect(tester.getTopLeft(find.text('Skip for now').last), skip);
        expect(tester.getTopLeft(_primary.last), next);
        expect(
          tester.getTopLeft(find.text('What do you do?')).dx,
          closeTo(question - 24 * _ei(0.5), 0.5),
        );
        final title = find.text('Where do you study?');
        expect(
          tester.getTopLeft(title).dx,
          closeTo(question + 24 * (1 - _eo(0.5)), 0.5),
        );
        final control = find.text('Select…');
        double trail() =>
            tester.getTopLeft(control).dx - tester.getTopLeft(title).dx;
        final midTrail = trail();

        await tester.pumpAndSettle();
        expect(find.byType(WhereYouStudiedScreen), findsOneWidget);
        expect(find.byType(AboutYouScreen), findsNothing);
        expect(
          tester.widget<IqStepMark>(find.byType(IqStepMark)).step,
          IqStepMarkStep.twoOfThree,
        );
        const lag = 40 / 300;
        final own = _eo((0.5 - lag) / (1 - lag));
        expect(midTrail - trail(), closeTo(24 * (_eo(0.5) - own), 0.5));
        expect(haptics, [_commit]);
      },
    );

    testWidgets('back mirrors it: the earlier step comes in from the left '
        'over 240', (tester) async {
      await _open(
        tester,
        Routes.onboardingWhereYouStudied,
        draft: {..._aboutYou, 'lastStep': 'whereYouStudied'},
      );
      await tester.pumpAndSettle();
      final question = tester.getTopLeft(find.text('Where do you study?')).dx;
      await tester.tap(find.bySemanticsLabel('Back'));
      await _playTo(tester, _ms * 120);
      expect(
        tester.getTopLeft(find.text('What do you do?')).dx,
        closeTo(question - 24 * (1 - _eo(0.5)), 0.5),
      );
      expect(
        tester.getTopLeft(find.text('Where do you study?')).dx,
        closeTo(question + 24 * _ei(0.5), 0.5),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AboutYouScreen), findsOneWidget);
      expect(
        tester.widget<IqStepMark>(find.byType(IqStepMark)).step,
        IqStepMarkStep.oneOfThree,
      );
    });

    testWidgets('reduced motion: the next step crossfades in place, its mark '
        'already set', (tester) async {
      await _open(
        tester,
        Routes.onboardingAboutYou,
        draft: {..._aboutYou, 'lastStep': 'aboutYou'},
        reduced: true,
      );
      await tester.pumpAndSettle();
      final question = tester.getTopLeft(find.text('What do you do?')).dx;
      await tester.tap(_primary);
      await _playTo(tester, _ms * 75);
      final title = find.text('Where do you study?');
      expect(tester.getTopLeft(title).dx, question);
      expect(_opacity(tester, title), closeTo(_eo(0.5), 0.02));
      final mark = find.byType(IqStepMark).last;
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
      expect(haptics, [_light, _select]);
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
      expect(find.byType(WhereYouLiveScreen), findsNothing);
      expect(_opacity(tester, landed.last), greaterThan(0.5));

      await tester.pump(_ms * 171);
      await tester.pump();
      expect(find.byType(WhereYouLiveScreen), findsOneWidget);
      await tester.pumpAndSettle();
      expect(haptics, [_light, _select, _commit]);
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
      expect(find.byType(WhereYouLiveScreen), findsOneWidget);
    });

    testWidgets('Education takes the full 724, Use this at its foot', (
      tester,
    ) async {
      await _open(tester, Routes.onboardingWhereYouStudied, draft: _studied);
      await tester.pumpAndSettle();
      await tester.tap(find.text('HND / BSc'));
      await tester.pumpAndSettle();
      final sheet = tester.getRect(find.byType(OptionSheet));
      expect(sheet.top, 120);
      expect(sheet.height, 724);
      expect(
        find.descendant(
          of: find.byType(OptionSheet),
          matching: find.byType(IqOptionRow),
        ),
        findsNWidgets(5),
      );
      expect(_top(tester, 'Use this'), 844 - 34 - 52);
      await tester.tap(find.text('Postgraduate'));
      await tester.pumpAndSettle();
      expect(find.byType(OptionSheet), findsOneWidget);
      await tester.tap(find.text('Use this'));
      await tester.pumpAndSettle();
      expect(find.byType(OptionSheet), findsNothing);
      expect(find.text('Postgraduate'), findsOneWidget);
    });

    testWidgets('SSCE / WAEC folds University away and drops the one '
        'picked (1284:90545)', (tester) async {
      await _open(
        tester,
        Routes.onboardingWhereYouStudied,
        draft: {..._studied, 'university': 'University of Lagos'},
      );
      await tester.pumpAndSettle();
      expect(find.text('University of Lagos'), findsOneWidget);

      await tester.tap(find.text('HND / BSc'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SSCE / WAEC'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use this'));
      await tester.pumpAndSettle();
      expect(find.text('SSCE / WAEC'), findsOneWidget);
      expect(find.text('University'), findsNothing);
      expect(find.text('University of Lagos'), findsNothing);

      await tester.tap(find.text('SSCE / WAEC'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ND / NCE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use this'));
      await tester.pumpAndSettle();
      expect(find.text('Search universities'), findsOneWidget);
    });

    testWidgets('State of residence takes the full 724', (tester) async {
      await _open(
        tester,
        Routes.onboardingWhereYouLive,
        draft: {..._aboutYou, 'lastStep': 'whereYouLive'},
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
      draft: {..._aboutYou, 'state': 'Lagos', 'lastStep': 'whereYouLive'},
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select city'));
    await tester.pumpAndSettle();
    expect(find.byType(CitySheet), findsOneWidget);
    expect(_on(tester, 'Add my city'), isFalse);
    expect(_top(tester, 'Use this'), _useThis);

    await tester.enterText(find.byType(EditableText).last, 'Yaba');
    await tester.pumpAndSettle();
    expect(_on(tester, 'Add my city'), isFalse);

    await tester.enterText(find.byType(EditableText).last, 'Atlantis');
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
    testWidgets('the off Finish shakes "Pick 2 or 3" with no haptic; '
        'chips select; Finish lands the onboarding with success, which '
        'takes over the press haptic', (tester) async {
      final haptics = recordHaptics(tester);
      await _open(
        tester,
        Routes.onboardingWhatYouLike,
        draft: {..._aboutYou, 'lastStep': 'whatYouLike'},
      );
      await tester.pumpAndSettle();
      final caption = find.text('Pick 2 or 3');
      final rest = tester.getTopLeft(caption).dx;

      await tester.tap(_primary);
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
      await tester.tap(_primary);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(DoneScreen), findsOneWidget);
      expect(haptics, [_select, _select, _success]);
    });

    testWidgets('a 4th pick is refused: the chip shakes and flashes red, the '
        'error haptic plays and the toast says why; the 3 stay (1284:90206)', (
      tester,
    ) async {
      final haptics = recordHaptics(tester);
      await _open(
        tester,
        Routes.onboardingWhatYouLike,
        draft: {
          ..._aboutYou,
          'interests': ['tech_gadgets', 'education', 'health_wellness'],
          'lastStep': 'whatYouLike',
        },
      );
      await tester.pumpAndSettle();
      final chip = find.widgetWithText(IqChip, 'Business');
      final rest = tester.getTopLeft(chip).dx;

      await tester.tap(chip);
      await tester.pump();
      expect(tester.widget<IqChip>(chip).refused, isTrue);
      expect(find.text('Max 3 interests. Unselect one first.'), findsOneWidget);
      var furthest = 0.0;
      for (var i = 0; i < 12; i++) {
        await tester.pump(_ms * 20);
        final away = (tester.getTopLeft(chip).dx - rest).abs();
        if (away > furthest) furthest = away;
      }
      expect(furthest, inInclusiveRange(1, 2));
      await tester.pump(IqDurations.refused);
      expect(tester.widget<IqChip>(chip).refused, isFalse);
      expect(tester.widget<IqChip>(chip).state, IqChipState.standard);
      expect(haptics, [_error]);
      await tester.pumpAndSettle();
      expect(find.text('Max 3 interests. Unselect one first.'), findsNothing);

      await tester.tap(find.text('Education'));
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(tester.widget<IqChip>(chip).state, IqChipState.selected);
      expect(haptics, [_error, _select, _select]);
    });

    testWidgets('reduced motion: the refused chip holds still, its flash and '
        'the toast keep their time', (tester) async {
      await _open(
        tester,
        Routes.onboardingWhatYouLike,
        draft: {
          ..._aboutYou,
          'interests': ['tech_gadgets', 'education', 'health_wellness'],
          'lastStep': 'whatYouLike',
        },
        reduced: true,
      );
      await tester.pumpAndSettle();
      final chip = find.widgetWithText(IqChip, 'Business');
      final rest = tester.getTopLeft(chip).dx;
      await tester.tap(chip);
      await tester.pump();
      await tester.pump(_ms * 120);
      expect(tester.getTopLeft(chip).dx, rest);
      await tester.pump(IqDurations.refused - _ms * 140);
      expect(tester.widget<IqChip>(chip).refused, isTrue);
      await tester.pump(_ms * 40);
      expect(tester.widget<IqChip>(chip).refused, isFalse);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Max 3 interests. Unselect one first.'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('Other opens a field for its words, and Finish waits for them '
        '(1284:90430)', (tester) async {
      await _open(
        tester,
        Routes.onboardingWhatYouLike,
        draft: {
          ..._aboutYou,
          'interests': ['tech_gadgets'],
          'lastStep': 'whatYouLike',
        },
      );
      await tester.pumpAndSettle();
      expect(find.text('Other interest'), findsNothing);

      final other = find.text('Other');
      await tester.ensureVisible(other);
      await tester.pumpAndSettle();
      await tester.tap(other);
      await tester.pumpAndSettle();
      expect(find.text('Other interest'), findsOneWidget);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(_on(tester, 'Finish'), isFalse);

      tester.testTextInput.enterText('Real estate');
      await tester.pumpAndSettle();
      expect(_on(tester, 'Finish'), isTrue);

      await tester.ensureVisible(other);
      await tester.pumpAndSettle();
      await tester.tap(other);
      await tester.pumpAndSettle();
      expect(find.text('Other interest'), findsNothing);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(_on(tester, 'Finish'), isFalse);
    });

    testWidgets('Finish peels at the second pick, as Next does on the other '
        'steps (spec 5.3)', (tester) async {
      await _open(
        tester,
        Routes.onboardingWhatYouLike,
        draft: {'occupation': 'student', 'lastStep': 'whatYouLike'},
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Technology'));
      await tester.pumpAndSettle();
      Color disc() =>
          (tester
                      .widget<DecoratedBox>(
                        find.descendant(
                          of: find.descendant(
                            of: _primary,
                            matching: find.byType(AnimatedContainer),
                          ),
                          matching: find.byType(DecoratedBox),
                        ),
                      )
                      .decoration
                  as BoxDecoration)
              .color!;
      double sticker() => tester
          .widget<Opacity>(
            find.descendant(of: _primary, matching: find.byType(Opacity)).first,
          )
          .opacity;
      expect(disc(), IqColors.panel);
      expect(sticker(), 0);

      await tester.tap(find.text('Business'));
      final discs = <Color>[];
      final stickers = <double>[];
      for (var at = 0; at <= 240; at += 16) {
        await tester.pump(const Duration(milliseconds: 16));
        discs.add(disc());
        stickers.add(sticker());
      }
      bool between(Color c) => c != IqColors.panel && c != IqColors.brand;
      expect(discs.where(between).length, greaterThanOrEqualTo(5));
      expect(stickers.where((s) => s > 0 && s < 1).length, greaterThan(5));
      expect(discs.last, IqColors.brand);
      expect(stickers.last, 1);
    });
  });

  group('moments', () {
    testWidgets('Done: title at +120, Start here at +200, the first card at '
        '+240; the Cheer figure is clipped to the 128 pt hero', (tester) async {
      await _open(
        tester,
        Routes.onboardingDone,
        draft: {..._aboutYou, 'lastStep': 'whatYouLike'},
      );
      await tester.pump();
      final title = find.textContaining('Nice one');
      final start = find.text('Start here');
      expect(_opacity(tester, title), 0);
      await tester.pump(_ms * 200);
      expect(_opacity(tester, title), closeTo(_eo(80 / 220), 0.02));
      expect(_opacity(tester, start), 0);
      final card = find.byType(IqBriefCard).first;
      expect(_opacity(tester, card), 0);
      await tester.pump(_ms * 100);
      expect(_opacity(tester, card), closeTo(_eo(60 / 260), 0.02));
      await tester.pump(const Duration(seconds: 2));
      for (final finder in [title, start]) {
        expect(_opacity(tester, finder), 1);
      }
      final hero = find.ancestor(
        of: find.byType(IqFigure),
        matching: find.byType(ClipRect),
      );
      expect(tester.getRect(hero.first), const Rect.fromLTWH(16, 78, 358, 128));
    });

    testWidgets('Done: the confetti falls past the Cheer figure, each piece '
        'at its own pace, and starts where Figma draws it', (tester) async {
      await _open(
        tester,
        Routes.onboardingDone,
        draft: {..._aboutYou, 'lastStep': 'whatYouLike'},
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      Matrix4 at(int i) => tester
          .widget<Transform>(
            find.descendant(
              of: find.byKey(ValueKey('confetti-$i')),
              matching: find.byType(Transform),
            ),
          )
          .transform;
      expect(find.byKey(const ValueKey('confetti-0')), findsOneWidget);
      final start = [for (var i = 0; i < 12; i++) at(i).getTranslation().y];
      await tester.pump(const Duration(seconds: 1));
      final later = [for (var i = 0; i < 12; i++) at(i).getTranslation().y];
      for (var i = 0; i < 12; i++) {
        expect(later[i], greaterThan(start[i]));
      }
      expect(later.toSet().length, greaterThan(1));
    });

    testWidgets('reduced motion: Done fades in together over 150', (
      tester,
    ) async {
      await _open(
        tester,
        Routes.onboardingDone,
        draft: {..._aboutYou, 'lastStep': 'whatYouLike'},
        reduced: true,
      );
      await tester.pump();
      await tester.pump(_ms * 75);
      final title = _opacity(tester, find.textContaining('Nice one'));
      expect(title, closeTo(_eo(0.5), 0.02));
      expect(_opacity(tester, find.text('Start here')), title);
      await tester.pump(_ms * 80);
      await tester.pump();
      expect(_opacity(tester, find.text('Start here')), 1);
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
