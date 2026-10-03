import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/box_field.dart';
import 'package:iqly_mobile/ui/button.dart';
import 'package:iqly_mobile/ui/chip.dart';
import 'package:iqly_mobile/ui/field.dart';
import 'package:iqly_mobile/ui/icon.dart';
import 'package:iqly_mobile/ui/illustration.dart';
import 'package:iqly_mobile/ui/next_fab.dart';
import 'package:iqly_mobile/ui/option_row.dart';
import 'package:iqly_mobile/ui/setting_row.dart';
import 'package:iqly_mobile/ui/step_mark.dart';
import 'package:iqly_mobile/ui/sticker.dart';
import 'package:iqly_mobile/ui/switch.dart';

const _ms = Duration(milliseconds: 1);

double _eo(double t) => IqCurves.easeOut.transform(t);
double _eio(double t) => IqCurves.easeInOut.transform(t);

void _reduce(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: buildTheme(),
    home: Scaffold(
      body: Align(alignment: Alignment.topLeft, child: child),
    ),
  ),
);

/// The product of every opacity above [finder].
double _opacity(WidgetTester tester, Finder finder) {
  var opacity = 1.0;
  for (final widget in tester.widgetList(
    find.ancestor(
      of: finder,
      matching: find.byWidgetPredicate(
        (w) => w is FadeTransition || w is Opacity || w is AnimatedOpacity,
      ),
    ),
  )) {
    opacity *= switch (widget) {
      FadeTransition(:final opacity) => opacity.value,
      Opacity(:final opacity) => opacity,
      _ => 1,
    };
  }
  return opacity;
}

List<String> _recordHaptics(WidgetTester tester) {
  final haptics = <String>[];
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'HapticFeedback.vibrate') {
      haptics.add(call.arguments as String);
    }
    return null;
  });
  addTearDown(
    () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return haptics;
}

void main() {
  group('NextFab', () {
    Widget fab(
      IqNextFabState state, {
      bool loading = false,
      VoidCallback? onTap,
      VoidCallback? onTapDisabled,
    }) => IqNextFab(
      state: state,
      loading: loading,
      onTap: onTap ?? () {},
      onTapDisabled: onTapDisabled,
    );

    double discScale(WidgetTester tester) => tester
        .widget<ScaleTransition>(
          find.descendant(
            of: find.byType(Sticker),
            matching: find.byType(ScaleTransition),
          ),
        )
        .scale
        .value;

    Color disc(WidgetTester tester) =>
        ((tester
                    .widget<AnimatedContainer>(
                      find.descendant(
                        of: find.byType(IqNextFab),
                        matching: find.byType(AnimatedContainer),
                      ),
                    )
                    .decoration
                as BoxDecoration?)
            ?.color) ??
        IqColors.line;

    testWidgets('peels as it turns on: the disc grows from .92 over 200', (
      tester,
    ) async {
      await _pump(tester, fab(IqNextFabState.disabled));
      await _pump(tester, fab(IqNextFabState.enabled));
      expect(discScale(tester), closeTo(IqScale.peel, 0.001));
      await tester.pump(_ms * 100);
      expect(
        discScale(tester),
        closeTo(IqScale.peel + (1 - IqScale.peel) * _eo(0.5), 0.002),
      );
      await tester.pump(_ms * 100);
      expect(discScale(tester), 1);
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('reduced motion: on at once, the disc never shrinks', (
      tester,
    ) async {
      _reduce(tester);
      await _pump(tester, fab(IqNextFabState.disabled));
      await _pump(tester, fab(IqNextFabState.enabled));
      expect(discScale(tester), 1);
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('a press drops onto the sticker in brand-dark', (tester) async {
      await _pump(tester, fab(IqNextFabState.enabled));
      final press = await tester.startGesture(
        tester.getCenter(find.byType(IqNextFab)),
      );
      await tester.pumpAndSettle();
      expect(disc(tester), IqColors.brandDark);
      await press.up();
      await tester.pumpAndSettle();
      expect(disc(tester), IqColors.brand);
    });

    testWidgets('working: the chevron crossfades to a spinner, taps ignored', (
      tester,
    ) async {
      var taps = 0;
      await _pump(tester, fab(IqNextFabState.enabled, onTap: () => taps++));
      await _pump(
        tester,
        fab(IqNextFabState.enabled, loading: true, onTap: () => taps++),
      );
      await tester.pump(_ms * 75);
      final spinner = find.descendant(
        of: find.byType(IqNextFab),
        matching: find.byType(RotationTransition),
      );
      expect(spinner, findsOneWidget);
      expect(_opacity(tester, spinner), closeTo(_eo(0.5), 0.02));
      await tester.pump(_ms * 80);
      expect(find.byType(IqIcon), findsNothing);
      await tester.tap(find.byType(IqNextFab));
      await tester.pump(_ms * 200);
      expect(taps, 0);
      expect(tester.hasRunningAnimations, isTrue);
      await _pump(tester, fab(IqNextFabState.enabled, onTap: () => taps++));
      await tester.pumpAndSettle();
      expect(find.byType(IqIcon), findsOneWidget);
    });

    testWidgets('reduced motion: the spinner stands still', (tester) async {
      _reduce(tester);
      await _pump(tester, fab(IqNextFabState.enabled, loading: true));
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(IqNextFab),
          matching: find.byType(RotationTransition),
        ),
        findsOneWidget,
      );
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('a tap while off reaches onTapDisabled, with no haptic', (
      tester,
    ) async {
      final haptics = _recordHaptics(tester);
      var missing = 0;
      await _pump(
        tester,
        fab(IqNextFabState.disabled, onTapDisabled: () => missing++),
      );
      await tester.tap(find.byType(IqNextFab));
      await tester.pumpAndSettle();
      expect(missing, 1);
      expect(haptics, isEmpty);
    });

    testWidgets('a tap while on gives the commit haptic', (tester) async {
      final haptics = _recordHaptics(tester);
      await _pump(tester, fab(IqNextFabState.enabled));
      await tester.tap(find.byType(IqNextFab));
      await tester.pumpAndSettle();
      expect(haptics, ['HapticFeedbackType.lightImpact']);
    });
  });

  group('StepMark', () {
    List<double> slots(WidgetTester tester) {
      final row = tester.renderObject<RenderFlex>(
        find.descendant(
          of: find.byType(IqStepMark),
          matching: find.byType(Row),
        ),
      );
      final widths = <double>[];
      var child = row.firstChild;
      while (child != null) {
        if (child.size.height == IqStepMark.ring) widths.add(child.size.width);
        child = (child.parentData! as FlexParentData).nextSibling;
      }
      return widths;
    }

    testWidgets('a new step morphs over 300: 80 wide throughout', (
      tester,
    ) async {
      await _pump(tester, const IqStepMark(step: IqStepMarkStep.oneOfThree));
      expect(slots(tester), [44, 6, 6]);
      await _pump(tester, const IqStepMark(step: IqStepMarkStep.twoOfThree));
      await tester.pump(_ms * 150);
      final grown = 6 + 38 * _eio(0.5);
      final mid = slots(tester);
      expect(mid[0], closeTo(44 - 38 * _eio(0.5), 0.01));
      expect(mid[1], closeTo(grown, 0.01));
      expect(mid[2], 6);
      expect(tester.getSize(find.byType(IqStepMark)).width, closeTo(80, 0.01));
      await tester.pump(_ms * 150);
      expect(slots(tester), [6, 44, 6]);
      await tester.pumpAndSettle();
      expect(slots(tester), [6, 44, 6]);
    });

    testWidgets('the old icon leaves in 120, the new one pops from +80', (
      tester,
    ) async {
      await _pump(
        tester,
        const IqStepMark(step: IqStepMarkStep.twoOfThree, icon: IqIcons.pin),
      );
      await _pump(
        tester,
        const IqStepMark(step: IqStepMarkStep.twoOfThree, icon: IqIcons.bank),
      );
      await tester.pump(_ms * 60);
      expect(find.byType(IqIcon), findsNWidgets(2));
      await tester.pump(_ms * 70);
      expect(find.byType(IqIcon), findsOneWidget);
      await tester.pumpAndSettle();
      final icon = tester.widget<IqIcon>(find.byType(IqIcon));
      expect(icon.icon, IqIcons.bank);
    });

    testWidgets('reduced motion: the new step at once', (tester) async {
      _reduce(tester);
      await _pump(tester, const IqStepMark(step: IqStepMarkStep.oneOfThree));
      await _pump(tester, const IqStepMark(step: IqStepMarkStep.twoOfThree));
      expect(slots(tester), [6, 44, 6]);
      expect(tester.hasRunningAnimations, isFalse);
    });

    double turn(WidgetTester tester) {
      final rotations = tester.widgetList<Transform>(
        find.descendant(
          of: find.byType(IqStepMark),
          matching: find.byType(Transform),
        ),
      );
      for (final t in rotations) {
        final m = t.transform;
        final angle = math.atan2(m.entry(1, 0), m.entry(0, 0));
        if (angle.abs() > 1e-6) return angle;
      }
      return 0;
    }

    testWidgets('the bell swings once from +200 for 480', (tester) async {
      await _pump(
        tester,
        const IqStepMark(
          step: IqStepMarkStep.single,
          icon: IqIcons.bell,
          swingIcon: true,
        ),
      );
      await tester.pump(_ms * 150);
      expect(turn(tester), 0);
      await tester.pump(_ms * 100);
      expect(turn(tester), lessThan(0));
      await tester.pumpAndSettle();
      expect(turn(tester), 0);
    });

    testWidgets('reduced motion: the bell does not swing', (tester) async {
      _reduce(tester);
      await _pump(
        tester,
        const IqStepMark(
          step: IqStepMarkStep.single,
          icon: IqIcons.bell,
          swingIcon: true,
        ),
      );
      await tester.pump(_ms * 300);
      expect(turn(tester), 0);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('Chip', () {
    Widget chips(Set<int> selected) => Wrap(
      spacing: IqSpace.s2,
      children: [
        for (var i = 0; i < 2; i++)
          IqChip(
            key: ValueKey(i),
            label: 'Chip $i',
            state: selected.contains(i)
                ? IqChipState.selected
                : IqChipState.standard,
            onChanged: (_) {},
          ),
      ],
    );

    double width(WidgetTester tester, int i) =>
        tester.getSize(find.byKey(ValueKey(i))).width;

    testWidgets(
      'selecting opens the tick slot over 120: the next chip glides',
      (tester) async {
        await _pump(tester, chips({}));
        final rest = width(tester, 0);
        final next = tester.getTopLeft(find.byKey(const ValueKey(1))).dx;
        await _pump(tester, chips({0}));
        await tester.pump(_ms * 60);
        final open = 16 * _eo(0.5);
        expect(width(tester, 0), closeTo(rest + open, 0.6));
        expect(
          tester.getTopLeft(find.byKey(const ValueKey(1))).dx,
          closeTo(next + open, 0.6),
        );
        await tester.pump(_ms * 60);
        expect(width(tester, 0), closeTo(rest + 16, 0.01));
        await _pump(tester, chips({}));
        await tester.pump(_ms * 120);
        expect(width(tester, 0), closeTo(rest, 0.01));
      },
    );

    testWidgets('a press scales it to .96', (tester) async {
      await _pump(tester, chips({}));
      final press = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey(0))),
      );
      await tester.pumpAndSettle();
      final scale = tester.widget<AnimatedScale>(
        find.descendant(
          of: find.byKey(const ValueKey(0)),
          matching: find.byType(AnimatedScale),
        ),
      );
      expect(scale.scale, IqScale.chipPress);
      await press.up();
      await tester.pumpAndSettle();
    });

    testWidgets('reduced motion: the width cuts', (tester) async {
      _reduce(tester);
      await _pump(tester, chips({}));
      final rest = width(tester, 0);
      await _pump(tester, chips({0}));
      expect(width(tester, 0), closeTo(rest + 16, 0.01));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('OptionRow', () {
    Widget row(
      IqOptionRowState state, {
      String label = 'Lagos',
      bool note = false,
    }) => SizedBox(
      width: 358,
      child: IqOptionRow(
        label: label,
        note: 'Ikorodu, Lagos',
        showNote: note,
        state: state,
        onTap: () {},
      ),
    );

    double reveal(WidgetTester tester) {
      final clip = tester.widget<ClipRect>(
        find.descendant(
          of: find.byType(IqOptionRow),
          matching: find.byType(ClipRect),
        ),
      );
      return clip.clipper!.getClip(const Size(16, 11.5)).right;
    }

    testWidgets('a pick floods tint and draws its check from +40', (
      tester,
    ) async {
      await _pump(tester, row(IqOptionRowState.standard));
      await _pump(tester, row(IqOptionRowState.selected));
      await tester.pump(_ms * 30);
      expect(reveal(tester), closeTo(0, 0.01));
      await tester.pump(_ms * 90);
      expect(reveal(tester), closeTo(16 * _eo(0.5), 0.05));
      await tester.pump(_ms * 80);
      expect(reveal(tester), greaterThan(16));
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('a cleared pick fades its check over 120', (tester) async {
      await _pump(tester, row(IqOptionRowState.selected));
      await _pump(tester, row(IqOptionRowState.standard));
      await tester.pump(_ms * 60);
      final check = find.byType(ClipRect);
      expect(_opacity(tester, check), inExclusiveRange(0, 1));
      await tester.pump(_ms * 70);
      expect(check, findsNothing);
    });

    testWidgets('reduced motion: the check at once', (tester) async {
      _reduce(tester);
      await _pump(tester, row(IqOptionRowState.standard));
      await _pump(tester, row(IqOptionRowState.selected));
      expect(reveal(tester), greaterThan(16));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('a long name wraps to two lines and the row grows', (
      tester,
    ) async {
      await _pump(tester, row(IqOptionRowState.standard, note: true));
      expect(tester.getSize(find.byType(IqOptionRow)).height, 56);
      await _pump(
        tester,
        row(
          IqOptionRowState.standard,
          label: 'Lagos State University of Science and Technology',
          note: true,
        ),
      );
      expect(tester.getSize(find.byType(IqOptionRow)).height, greaterThan(56));
    });
  });

  group('Field', () {
    Widget field(IqFieldState? state, {String help = 'Check the number.'}) =>
        SizedBox(
          width: 358,
          child: IqField(
            label: 'Phone number',
            value: '',
            state: state,
            help: help,
            showNote: false,
          ),
        );

    testWidgets('the help line opens its slot as it rises in, 160', (
      tester,
    ) async {
      await _pump(tester, field(IqFieldState.error));
      await tester.pumpAndSettle();
      final open = tester.getSize(find.byType(IqField)).height;
      await _pump(tester, field(null));
      await tester.pumpAndSettle();
      final rest = tester.getSize(find.byType(IqField)).height;
      expect(open - rest, greaterThan(20));
      await _pump(tester, field(IqFieldState.error));
      await tester.pump();
      expect(tester.getSize(find.byType(IqField)).height, closeTo(rest, 0.5));
      await tester.pump(_ms * 80);
      expect(
        tester.getSize(find.byType(IqField)).height,
        closeTo(rest + (open - rest) * _eo(0.5), 0.6),
      );
      await tester.pump(_ms * 80);
      expect(tester.getSize(find.byType(IqField)).height, open);
    });

    testWidgets('an error that clears fades and folds in 150', (tester) async {
      await _pump(tester, field(IqFieldState.error));
      await tester.pumpAndSettle();
      await _pump(tester, field(null));
      await tester.pump(_ms * 75);
      expect(find.text('Check the number.'), findsOneWidget);
      await tester.pump(_ms * 80);
      expect(find.text('Check the number.'), findsNothing);
    });

    testWidgets('reduced motion: the help line crossfades in, cuts out', (
      tester,
    ) async {
      _reduce(tester);
      await _pump(tester, field(null));
      final rest = tester.getSize(find.byType(IqField)).height;
      await _pump(tester, field(IqFieldState.error));
      await tester.pump();
      expect(tester.getSize(find.byType(IqField)).height, greaterThan(rest));
      await tester.pump(_ms * 75);
      expect(
        _opacity(tester, find.text('Check the number.')),
        closeTo(_eo(0.5), 0.02),
      );
      await tester.pump(_ms * 80);
      await _pump(tester, field(null));
      expect(find.text('Check the number.'), findsNothing);
    });

    testWidgets('turning Valid pops the success icon from .6', (tester) async {
      await _pump(tester, field(IqFieldState.active));
      await _pump(tester, field(IqFieldState.valid));
      await tester.pump(_ms * 110);
      final icon = find.byWidgetPredicate(
        (w) => w is IqIcon && w.icon == IqIcons.success,
      );
      final scale = tester
          .widgetList<Transform>(
            find.ancestor(of: icon, matching: find.byType(Transform)),
          )
          .map((t) => t.transform.storage[0])
          .reduce((a, b) => a * b);
      expect(scale, closeTo(IqScale.pop + (1 - IqScale.pop) * _eo(0.5), 0.02));
      await tester.pumpAndSettle();
    });

    testWidgets(
      'every field is one node at least 44 tall, carrying its label',
      (tester) async {
        final semantics = tester.ensureSemantics();
        for (final size in IqFieldSize.values) {
          for (final kind in IqFieldKind.values) {
            for (final state in IqFieldState.values) {
              await _pump(
                tester,
                SizedBox(
                  width: 358,
                  child: IqField(
                    kind: kind,
                    size: size,
                    state: state,
                    label: 'Phone number',
                    pickerLabel: 'Bank',
                  ),
                ),
              );
              await tester.pumpAndSettle();
              final label = kind == IqFieldKind.text ? 'Phone number' : 'Bank';
              final node = tester.getSemantics(
                find.descendant(
                  of: find.byType(IqField),
                  matching: find.bySemanticsLabel(RegExp(label)),
                ),
              );
              expect(
                node.rect.height,
                greaterThanOrEqualTo(44),
                reason: '$kind $size $state',
              );
              if (kind == IqFieldKind.text) {
                final data = node.getSemanticsData();
                expect(data.label, startsWith(label));
                expect(data.flagsCollection.isTextField, isTrue);
              }
            }
          }
        }
        semantics.dispose();
      },
    );
  });

  group('BoxField', () {
    testWidgets('the outline crosses to the accent over 160', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await _pump(tester, IqBoxField(focusNode: focus));
      focus.requestFocus();
      await tester.pump();
      await tester.pump(_ms * 80);
      final border =
          (tester
                      .widget<AnimatedContainer>(
                        find.descendant(
                          of: find.byType(IqBoxField),
                          matching: find.byType(AnimatedContainer),
                        ),
                      )
                      .decoration!
                  as BoxDecoration)
              .border!
              .top;
      expect(border.color, IqColors.accent);
      final painted = tester.renderObject<RenderDecoratedBox>(
        find.descendant(
          of: find.byType(IqBoxField),
          matching: find.byType(DecoratedBox),
        ),
      );
      final side = (painted.decoration as BoxDecoration).border!.top;
      expect(side.width, closeTo(1.5 + 0.5 * _eo(0.5), 0.01));
    });

    testWidgets('the help line grows its slot with the reveal', (tester) async {
      Widget box(IqBoxFieldState? state) =>
          IqBoxField(state: state, help: 'Check for typos.');
      await _pump(tester, box(IqBoxFieldState.error));
      await tester.pumpAndSettle();
      final open = tester.getSize(find.byType(IqBoxField)).height;
      await _pump(tester, box(null));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(IqBoxField)).height, 56);
      await _pump(tester, box(IqBoxFieldState.error));
      await tester.pump(_ms * 80);
      expect(
        tester.getSize(find.byType(IqBoxField)).height,
        closeTo(56 + (open - 56) * _eo(0.5), 0.6),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(IqBoxField)).height, open);
    });
  });

  group('SettingRow and Switch', () {
    testWidgets('the row fills panel while pressed', (tester) async {
      await _pump(
        tester,
        SizedBox(
          width: 358,
          child: IqSettingRow(state: IqSwitchState.off, onChanged: (_) {}),
        ),
      );
      Color fill() =>
          (tester
                      .widget<AnimatedContainer>(
                        find
                            .descendant(
                              of: find.byType(IqSettingRow),
                              matching: find.byType(AnimatedContainer),
                            )
                            .first,
                      )
                      .decoration
                  as BoxDecoration?)
              ?.color ??
          IqColors.card;
      final press = await tester.startGesture(const Offset(40, 30));
      await tester.pump(_ms * 150);
      expect(fill(), IqColors.panel);
      await press.up();
      await tester.pumpAndSettle();
      expect(fill(), IqColors.card);
    });

    testWidgets('toggling gives the select haptic', (tester) async {
      final haptics = _recordHaptics(tester);
      await _pump(
        tester,
        SizedBox(
          width: 358,
          child: IqSettingRow(state: IqSwitchState.off, onChanged: (_) {}),
        ),
      );
      await tester.tap(find.byType(IqSettingRow));
      await tester.pumpAndSettle();
      expect(haptics, ['HapticFeedbackType.selectionClick']);
    });
  });

  group('Danger button', () {
    testWidgets('peels its err-soft sticker as it turns on', (tester) async {
      Widget danger(bool disabled) => IqButton(
        label: 'Delete my account',
        kind: IqButtonKind.danger,
        disabled: disabled,
        onTap: () {},
      );
      double sticker() => _opacity(
        tester,
        find
            .descendant(
              of: find.byType(Sticker),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );

      await _pump(tester, danger(true));
      expect(sticker(), 0);
      await _pump(tester, danger(false));
      await tester.pump(_ms * 100);
      expect(sticker(), closeTo(_eo(0.5), 0.02));
      await tester.pumpAndSettle();
      expect(sticker(), 1);
    });
  });

  group('Button label', () {
    Widget button(String label, {bool roll = true}) =>
        IqButton(label: label, width: 300, rollLabel: roll, onTap: () {});

    testWidgets('with rollLabel, a new count rolls in over 160 while the '
        'words around it hold', (tester) async {
      await _pump(tester, button('Show 11 briefs'));
      expect(tester.hasRunningAnimations, isFalse);
      await _pump(tester, button('Show 9 briefs'));
      await tester.pump(_ms * 80);
      expect(find.text('Show 11 briefs'), findsOneWidget);
      expect(find.text('Show 9 briefs'), findsWidgets);
      final leaving = tester.widget<Transform>(
        find
            .ancestor(
              of: find.text('Show 11 briefs'),
              matching: find.byType(Transform),
            )
            .first,
      );
      expect(
        leaving.transform.getTranslation().y,
        closeTo(-IqTravel.tick * _eo(0.5), 0.01),
      );
      await tester.pump(_ms * 81);
      await tester.pump();
      expect(find.text('Show 11 briefs'), findsNothing);
      expect(find.text('Show 9 briefs'), findsOneWidget);
    });

    testWidgets('reduced motion: the new label cuts in', (tester) async {
      _reduce(tester);
      await _pump(tester, button('Show 11 briefs'));
      await _pump(tester, button('Show 9 briefs'));
      expect(find.text('Show 11 briefs'), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('without it, a new label cuts in as before', (tester) async {
      await _pump(tester, button('Save changes', roll: false));
      await _pump(tester, button('Saving', roll: false));
      expect(find.text('Save changes'), findsNothing);
      expect(find.text('Saving'), findsOneWidget);
    });
  });

  group('Illustration', () {
    double inkOpacity(WidgetTester tester) => _opacity(
      tester,
      find
          .descendant(
            of: find.byType(IqIllustration),
            matching: find.byWidgetPredicate(
              (w) => w.runtimeType.toString() == 'SvgPicture',
            ),
          )
          .at(1),
    );

    testWidgets('the ink rises in over 320, then the whole takes over', (
      tester,
    ) async {
      await _pump(
        tester,
        const IqIllustration(
          IqIllustrations.sprout,
          entrance: IqIllustrationEntrance.rise,
        ),
      );
      await tester.pump(_ms * 160);
      expect(inkOpacity(tester), closeTo(_eo(0.5), 0.02));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(IqIllustration),
          matching: find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == 'SvgPicture',
          ),
        ),
        findsOneWidget,
      );
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('reduced motion: it fades in over 150, no layers', (
      tester,
    ) async {
      _reduce(tester);
      await _pump(
        tester,
        const IqIllustration(
          IqIllustrations.rocket,
          entrance: IqIllustrationEntrance.rise,
        ),
      );
      await tester.pump(_ms * 75);
      final whole = find.descendant(
        of: find.byType(IqIllustration),
        matching: find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == 'SvgPicture',
        ),
      );
      expect(whole, findsOneWidget);
      expect(_opacity(tester, whole), closeTo(_eo(0.5), 0.02));
      await tester.pump(_ms * 80);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('the rocket lifts 4 and settles from +320', (tester) async {
      await _pump(
        tester,
        const IqIllustration(
          IqIllustrations.rocket,
          entrance: IqIllustrationEntrance.rise,
        ),
      );
      double lift() => tester
          .widget<Transform>(
            find
                .descendant(
                  of: find.byType(IqIllustration),
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform
          .getTranslation()
          .y;
      await tester.pump(_ms * 300);
      expect(lift(), 0);
      await tester.pump(_ms * 140);
      expect(lift(), closeTo(-IqTravel.nudge, 0.3));
      await tester.pumpAndSettle();
      expect(lift(), 0);
    });
  });
}
