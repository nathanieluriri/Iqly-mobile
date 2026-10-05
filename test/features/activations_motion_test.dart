import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iqly_mobile/core/transitions.dart';
import 'package:iqly_mobile/data/activations_service.dart';
import 'package:iqly_mobile/features/activations/activations_routes.dart';
import 'package:iqly_mobile/features/activations/activations_state.dart';
import 'package:iqly_mobile/features/activations/activations_widgets.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/icon.dart';
import 'package:iqly_mobile/ui/pressable.dart';
import 'package:iqly_mobile/ui/proof_tile.dart';
import 'package:iqly_mobile/ui/step_row.dart';
import 'package:iqly_mobile/ui/top_bar.dart';
import 'package:iqly_mobile/ui/video_preview.dart';

import '../golden/golden.dart' show loadAppFonts;
import '../golden/screens/activations_harness.dart';
import 'entry_harness.dart' show recordHaptics;

const _success = 'HapticFeedbackType.successNotification';
const _commit = 'HapticFeedbackType.lightImpact';

/// Pumps [ms] of frames 10 ms apart, as a device draws them, calling [each]
/// after every frame with the time since the first.
Future<void> _run(
  WidgetTester tester,
  int ms, [
  void Function(int at)? each,
]) async {
  for (var at = 10; at <= ms; at += 10) {
    await tester.pump(const Duration(milliseconds: 10));
    each?.call(at);
  }
}

Finder _button(String label) =>
    find.byWidgetPredicate((w) => w is IqPressable && w.semanticLabel == label);

Finder _card(String id) => find.byKey(ValueKey(id), skipOffstage: false);

/// The card's arrival in its list: the Stagger fade, then its rise.
double _cardOpacity(WidgetTester tester, String id) => tester
    .widget<FadeTransition>(
      find.ancestor(of: _card(id), matching: find.byType(FadeTransition)).first,
    )
    .opacity
    .value;

/// A StateDissolve layer, keyed by its state ('_Layout.credited', 'tile').
Finder _layerOf(String key) => find.byWidgetPredicate(
  (w) =>
      w is FadeTransition &&
      w.key is ValueKey &&
      '${(w.key! as ValueKey).value}' == key,
);

double _layer(WidgetTester tester, String key) =>
    tester.widget<FadeTransition>(_layerOf(key)).opacity.value;

List<IqStepRowState> _steps(WidgetTester tester) => [
  for (final row in tester.widgetList<IqStepRow>(find.byType(IqStepRow)))
    row.state,
];

/// [title] on a Page top bar, not the same words in the content.
Finder _barTitle(String title) =>
    find.descendant(of: find.byType(IqTopBar), matching: find.text(title));

bool _between(double value) => value > 0 && value < 1;

DemoActivationsService _stuck() => instantActivations(
  now: Figma.friday,
  seed: Figma.world(Figma.friday, kudiBox: Figma.step1),
);

/// From the stuck activation to its proof page, a recording picked and
/// ready to send.
Future<void> _readyToSend(WidgetTester tester) async {
  await pumpActivations(
    tester,
    activationPath('a2'),
    now: Figma.friday,
    service: _stuck(),
    reducedMotion: false,
    settle: false,
  );
  await tester.pump(const Duration(milliseconds: 600));
  await tester.tap(find.text('Upload proof of step 2'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.tap(find.byType(IqProofTile));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// Every fade above [element] multiplied together.
double _fadeOf(Element element) {
  var opacity = 1.0;
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is FadeTransition) opacity *= widget.opacity.value;
    if (widget is Opacity) opacity *= widget.opacity;
    return true;
  });
  return opacity;
}

Rect _rectOf(Element element) {
  final box = element.renderObject! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// Where each widget [finder] finds is drawn, and how strongly.
List<(Rect, double)> _drawn(Finder finder) => [
  for (final element in finder.evaluate()) (_rectOf(element), _fadeOf(element)),
];

Finder _icon(IqIcons icon) =>
    find.byWidgetPredicate((w) => w is IqIcon && w.icon == icon);

void main() {
  setUpAll(loadAppFonts);

  final thursday = Figma.thursday;
  final friday = Figma.friday;

  group('the list', () {
    testWidgets('waits 300 ms on paper, then holds the skeleton 600', (
      tester,
    ) async {
      await pumpActivations(
        tester,
        Routes.activations,
        now: thursday,
        reducedMotion: false,
        settle: false,
        service: DemoActivationsService(
          seed: Figma.world(thursday),
          clock: () => thursday,
          load: const Duration(milliseconds: 500),
          delay: Duration.zero,
          step: null,
        ),
      );
      const card = 'Rate 3 recipes in the Orchid Foods app';
      await tester.pump(const Duration(milliseconds: 290));
      expect(find.byType(ActivationsLoading), findsNothing);
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.byType(ActivationsLoading), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ActivationsLoading), findsOneWidget, reason: '600');
      expect(find.text(card), findsNothing);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.text(card), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(ActivationsLoading), findsNothing);
    });

    testWidgets('data inside 300 ms comes straight in; cards arrive 40 ms '
        'apart, closing soonest first', (tester) async {
      await pumpActivations(
        tester,
        Routes.activations,
        now: thursday,
        reducedMotion: false,
        settle: false,
      );
      expect(find.byType(ActivationsLoading), findsNothing);
      final starts = <String, int>{};
      await _run(tester, 600, (at) {
        for (final id in ['a1', 'a2', 'a3']) {
          if (_cardOpacity(tester, id) > 0) starts.putIfAbsent(id, () => at);
        }
      });
      expect(starts['a2']! - starts['a1']!, 40);
      expect(starts['a3']! - starts['a2']!, 40);
      for (final id in ['a1', 'a2', 'a3']) {
        expect(_cardOpacity(tester, id), 1);
      }
    });
  });

  group('one activation', () {
    testWidgets('Start dissolves the offer into just started over 300 ms', (
      tester,
    ) async {
      final haptics = recordHaptics(tester);
      await pumpActivations(
        tester,
        activationPath('a2'),
        now: thursday,
        reducedMotion: false,
      );
      await tester.tap(find.text('Start activation'));
      await tester.pump();
      expect(haptics, [_commit]);
      await _run(tester, 150);
      expect(_between(_layer(tester, '_Layout.offer')), isTrue);
      expect(_between(_layer(tester, '_Layout.steps')), isTrue);
      await _run(tester, 200);
      expect(find.text('Start activation'), findsNothing);
      expect(_layer(tester, '_Layout.steps'), 1);
    });

    testWidgets('a confirmed step pops to Done, the next goes Active 120 ms '
        'later; paid, the reward dissolves in with the success haptic at '
        '+120', (tester) async {
      final haptics = recordHaptics(tester);
      await pumpActivations(
        tester,
        activationPath('a2'),
        now: thursday,
        reducedMotion: false,
        service: instantActivations(
          now: thursday,
          step: const Duration(seconds: 4),
        ),
      );
      await tester.tap(find.text('Start activation'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_steps(tester), [
        IqStepRowState.todo,
        IqStepRowState.todo,
        IqStepRowState.todo,
      ]);

      await tester.pump(const Duration(milliseconds: 3600));
      expect(_steps(tester), [
        IqStepRowState.done,
        IqStepRowState.todo,
        IqStepRowState.todo,
      ]);
      expect(find.text('Step 1 of 3 confirmed'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 130));
      expect(_steps(tester), [
        IqStepRowState.done,
        IqStepRowState.active,
        IqStepRowState.todo,
      ]);
      expect(haptics, [_commit], reason: 'confirmations are passive');

      await tester.pump(const Duration(milliseconds: 3870));
      expect(find.text('Your reward'), findsOneWidget);
      await _run(tester, 60);
      expect(haptics, [_commit]);
      expect(_between(_layer(tester, '_Layout.credited')), isTrue);

      await _run(tester, 100);
      expect(haptics, [_commit, _success]);

      await _run(tester, 300);
      expect(_layer(tester, '_Layout.credited'), 1);
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('paid while another page covers it: no moment and no haptic; '
        'back on it, the reward is already in place', (tester) async {
      final haptics = recordHaptics(tester);
      final container = await pumpActivations(
        tester,
        activationPath('a2'),
        now: friday,
        reducedMotion: false,
        settle: false,
        service: instantActivations(
          now: friday,
          seed: Figma.world(friday, kudiBox: Figma.proofSent),
        ),
      );
      const proof = 'Not credited yet?';
      await tester.pump(const Duration(milliseconds: 600));
      await tester.scrollUntilVisible(
        find.text('Ask for help'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text('Ask for help'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text(proof), findsNothing);

      container.read(activationsProvider.notifier).refresh('a2');
      await _run(tester, 1000);
      expect(haptics, isNot(contains(_success)));

      await tester.tap(_button('Back'));
      await tester.pump();
      await _run(tester, 20, (at) {
        expect(find.text(proof), findsNothing, reason: 'at $at ms');
        expect(_layer(tester, '_Layout.credited'), 1, reason: 'at $at ms');
      });
      await _run(tester, 400);
      expect(find.text('Your reward'), findsOneWidget);
      expect(haptics, isNot(contains(_success)));
    });

    testWidgets('reduced motion: a 150 ms crossfade to the reward', (
      tester,
    ) async {
      final haptics = recordHaptics(tester);
      await pumpActivations(
        tester,
        activationPath('a2'),
        now: thursday,
        service: instantActivations(
          now: thursday,
          seed: Figma.world(thursday, kudiBox: Figma.step1),
        ),
      );
      await tester.tap(find.text('Verify your BVN in the app'));
      await tester.pump();
      final layer = <double>[];
      await _run(tester, 600, (at) {
        if (_layerOf('_Layout.credited').evaluate().isEmpty) return;
        layer.add(_layer(tester, '_Layout.credited'));
      });
      final fading = layer.where(_between).length;
      expect(fading, inInclusiveRange(13, 16), reason: '150 ms of frames');
      expect(layer.last, 1);
      expect(find.text('Verify your BVN in the app'), findsNothing);
      expect(haptics, [_success]);
    });
  });

  group('proof', () {
    testWidgets('a pick morphs the tile into the polaroid over 320 ms', (
      tester,
    ) async {
      await pumpActivations(
        tester,
        proofPath('a2'),
        now: friday,
        service: _stuck(),
        reducedMotion: false,
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 500));
      final tile = tester.getSize(find.byType(IqProofTile)).height;
      await tester.tap(find.byType(IqProofTile));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));
      expect(find.byType(IqProofTile), findsOneWidget);
      expect(find.byType(IqVideoPreview), findsOneWidget);
      final slot = find.ancestor(
        of: find.byType(IqVideoPreview),
        matching: find.byType(AnimatedSize),
      );
      final preview = tester.getSize(find.byType(IqVideoPreview)).height;
      expect(tester.getSize(slot).height, inExclusiveRange(tile, preview));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(IqProofTile), findsNothing);
      expect(tester.getSize(slot).height, closeTo(preview, 0.5));
    });

    testWidgets('Remove recording tilts the polaroid 3° as it fades, then '
        'the tile rises in', (tester) async {
      await pumpActivations(
        tester,
        proofPath('a2'),
        now: friday,
        service: _stuck(),
        reducedMotion: false,
        settle: false,
      );
      await tester.tap(find.byType(IqProofTile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(_button('Remove'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Remove recording'));
      final tilts = <double>[];
      final tiles = <(double, double)>[];
      await _run(tester, 600, (at) {
        final polaroid = find.ancestor(
          of: find.byType(IqVideoPreview),
          matching: find.byType(Transform),
        );
        if (polaroid.evaluate().isNotEmpty) {
          final turn = tester.widget<Transform>(polaroid.first).transform;
          tilts.add(
            math.atan2(turn.entry(1, 0), turn.entry(0, 0)) * 180 / math.pi,
          );
        }
        final tile = find.byType(IqProofTile);
        if (tile.evaluate().isEmpty) return;
        tiles.add((
          tester
              .widget<FadeTransition>(
                find
                    .ancestor(of: tile, matching: find.byType(FadeTransition))
                    .first,
              )
              .opacity
              .value,
          tester
              .widget<Transform>(
                find.ancestor(of: tile, matching: find.byType(Transform)).first,
              )
              .transform
              .getTranslation()
              .y,
        ));
      });
      expect(tilts.where((d) => d > 0 && d < 3), isNotEmpty);
      expect(tilts.every((d) => d >= 0 && d <= 3), isTrue);
      expect(find.byType(IqVideoPreview), findsNothing);
      expect(tiles.first.$1, 0, reason: 'the tile waits for the polaroid');
      final rising = tiles.where((t) => _between(t.$1));
      expect(rising, isNotEmpty);
      for (final (opacity, rise) in rising) {
        expect(rise, closeTo(8 * (1 - opacity), 0.01));
      }
      expect(tiles.last, (1.0, 0.0));
    });

    testWidgets('reduced motion: the tile and the polaroid crossfade in '
        'place over 150 ms, nothing morphs, tilts or rises', (tester) async {
      await pumpActivations(
        tester,
        proofPath('a2'),
        now: friday,
        service: _stuck(),
      );
      await tester.tap(find.byType(IqProofTile));
      await tester.pump();
      final preview = <double>[];
      await _run(tester, 300, (at) {
        if (_layerOf('preview').evaluate().isEmpty) return;
        preview.add(_layer(tester, 'preview'));
        expect(
          find.ancestor(
            of: find.byType(IqVideoPreview),
            matching: find.byType(AnimatedSize),
          ),
          findsNothing,
        );
      });
      expect(preview.where(_between).length, inInclusiveRange(13, 16));
      expect(preview.last, 1);
      expect(find.byType(IqProofTile), findsNothing);

      await tester.tap(_button('Remove'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove recording'));
      final tile = <double>[];
      await _run(tester, 600, (at) {
        expect(
          find.ancestor(
            of: find.byType(IqVideoPreview),
            matching: find.byWidgetPredicate(
              (w) => w is Transform && w.transform.entry(1, 0) != 0,
            ),
          ),
          findsNothing,
        );
        expect(
          find.ancestor(
            of: find.byType(IqProofTile),
            matching: find.byWidgetPredicate(
              (w) => w is Transform && w.transform.getTranslation().y != 0,
            ),
          ),
          findsNothing,
        );
        if (_layerOf('tile').evaluate().isNotEmpty) {
          tile.add(_layer(tester, 'tile'));
        }
      });
      expect(tile.where(_between), isNotEmpty);
      expect(tile.last, 1);
      expect(find.byType(IqVideoPreview), findsNothing);
      expect(find.byType(IqProofTile), findsOneWidget);
    });

    testWidgets('sent: Your proof is already in place under the leaving '
        'page', (tester) async {
      final haptics = recordHaptics(tester);
      await pumpActivations(
        tester,
        proofPath('a2'),
        now: friday,
        service: _stuck(),
        reducedMotion: false,
        settle: false,
      );
      await tester.tap(find.byType(IqProofTile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      haptics.clear();
      await tester.tap(find.text('Send proof'));
      await tester.pump();
      await tester.pump();
      expect(haptics, [_success]);
      await _run(tester, 100);
      expect(find.text('Upload proof of step 2'), findsNothing);
      expect(find.text('Not credited yet?'), findsOneWidget);
      await _run(tester, 500);
      expect(find.text('Upload proof'), findsNothing);
    });

    testWidgets('sent from the activation: it is Your proof from the pop’s '
        'first frame, so only the pop and the recording’s flight move', (
      tester,
    ) async {
      await pumpActivations(
        tester,
        activationPath('a2'),
        now: friday,
        service: _stuck(),
        reducedMotion: false,
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text('Upload proof of step 2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.byType(IqProofTile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      final from = tester.getTopLeft(find.byType(ProofFrame)).dy;

      await tester.tap(find.text('Send proof'));
      final flight = <double>[];
      for (var at = 16; at <= 400; at += 16) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(_layerOf('_Layout.steps'), findsNothing, reason: 'at $at ms');
        if (_layerOf('_Layout.proof').evaluate().isNotEmpty) {
          expect(_layer(tester, '_Layout.proof'), 1, reason: 'at $at ms');
        }
        flight.addAll([
          for (final frame in tester.renderObjectList<RenderBox>(
            find.byType(ProofFrame),
          ))
            frame.localToGlobal(Offset.zero).dy,
        ]);
      }
      expect(find.text('Upload proof'), findsNothing);
      expect(find.text('Not credited yet?'), findsOneWidget);
      final to = tester.getTopLeft(find.byType(ProofFrame)).dy;
      expect(flight.where((y) => y > from + 1 && y < to - 1), isNotEmpty);
    });

    testWidgets('sent: the back button holds still while Upload proof '
        'crosses into Your proof (spec 4.3)', (tester) async {
      await _readyToSend(tester);
      final back = tester.getTopLeft(_button('Back'));
      final titles = {'Upload proof': <(Rect, double)>[], 'Your proof': []};

      await tester.tap(find.text('Send proof'));
      for (var at = 16; at <= 400; at += 16) {
        await tester.pump(const Duration(milliseconds: 16));
        for (final (rect, seen) in _drawn(_button('Back'))) {
          if (seen < 0.01) continue;
          expect(
            rect.topLeft,
            offsetMoreOrLessEquals(back, epsilon: 0.5),
            reason: 'a back button at ${rect.topLeft} at $at ms',
          );
        }
        for (final MapEntry(:key, :value) in titles.entries) {
          value.addAll(_drawn(_barTitle(key)).where((d) => d.$2 > 0.01));
        }
      }
      await tester.pump(const Duration(milliseconds: 500));
      final upload = titles['Upload proof']!;
      final yours = titles['Your proof']!;
      final rest = tester.getTopLeft(_barTitle('Your proof'));
      expect(
        yours.map((d) => d.$1.topLeft),
        everyElement(offsetMoreOrLessEquals(rest, epsilon: 0.5)),
      );
      expect(
        upload.map((d) => d.$1.topLeft.dy),
        everyElement(closeTo(rest.dy, 0.5)),
      );
      expect(upload.map((d) => d.$1.left).toSet(), hasLength(1));
      expect(yours.where((d) => d.$2 < 0.99), isNotEmpty);
      expect(upload.where((d) => d.$2 < 0.99), isNotEmpty);
    });

    testWidgets('sent: the play sticker and the remove X go with the '
        'recording and never blink as it flies', (tester) async {
      await _readyToSend(tester);
      final flying = find.byElementPredicate(
        (e) =>
            e.widget is ProofFrame &&
            e.findAncestorWidgetOfExactType<Hero>() == null,
      );
      double seen(IqIcons icon) {
        final flight = flying.evaluate().map(_rectOf).firstOrNull;
        var strongest = 0.0;
        for (final element in _icon(icon).evaluate()) {
          final onPage = element.findAncestorWidgetOfExactType<Scaffold>();
          final under =
              onPage != null &&
              flight != null &&
              flight.contains(_rectOf(element).center);
          strongest = math.max(strongest, under ? 0 : _fadeOf(element));
        }
        return strongest;
      }

      expect(seen(IqIcons.close), 1);
      expect(seen(IqIcons.play), 1);
      await tester.tap(find.text('Send proof'));
      final remove = <double>[];
      final play = <double>[];
      var flew = false;
      for (var at = 16; at <= 400; at += 16) {
        await tester.pump(const Duration(milliseconds: 16));
        flew |= flying.evaluate().isNotEmpty;
        remove.add(seen(IqIcons.close));
        play.add(seen(IqIcons.play));
      }
      expect(flew, isTrue);
      for (var i = 1; i < remove.length; i++) {
        expect(remove[i], lessThanOrEqualTo(remove[i - 1] + 0.01));
      }
      expect(remove.where((o) => o > 0.05 && o < 0.95), isNotEmpty);
      expect(remove.last, 0);
      expect(play, everyElement(greaterThan(0.99)));
    });

    testWidgets('play: the frame flies from the thumbnail to the player', (
      tester,
    ) async {
      await pumpActivations(
        tester,
        activationPath('a2'),
        now: friday,
        reducedMotion: false,
        settle: false,
        service: instantActivations(
          now: friday,
          seed: Figma.world(friday, kudiBox: Figma.proofSent),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(_button('Play'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      final heights = [
        for (final box in tester.renderObjectList<RenderBox>(
          find.byType(ProofFrame),
        ))
          box.size.height,
      ];
      expect(
        heights.any((h) => h > 201 && h < 560),
        isTrue,
        reason: '$heights',
      );
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('reduced motion: the player crossfades in, no flight', (
      tester,
    ) async {
      await pumpActivations(
        tester,
        activationPath('a2'),
        now: friday,
        service: instantActivations(
          now: friday,
          seed: Figma.world(friday, kudiBox: Figma.proofSent),
        ),
      );
      await tester.tap(_button('Play'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 75));
      final heights = [
        for (final box in tester.renderObjectList<RenderBox>(
          find.byType(ProofFrame, skipOffstage: false),
        ))
          box.size.height,
      ];
      expect(heights.where((h) => h > 201 && h < 500), isEmpty);
      await tester.pumpAndSettle();
    });
  });

  testWidgets('a push while one state dissolves into the next flies the top '
      'bar of the state that stays', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = ValueNotifier('Activation');
    addTearDown(state.dispose);
    Widget page(Widget bar) => Material(
      color: IqColors.bg,
      child: Column(children: [bar, const Spacer()]),
    );
    IqTopBar bar(String title) =>
        IqTopBar(variant: IqTopBarVariant.page, title: title, onBack: () {});
    final router = GoRouter(
      initialLocation: '/states',
      routes: [
        GoRoute(
          path: '/states',
          pageBuilder: (c, s) => pushPage(
            s,
            ValueListenableBuilder(
              valueListenable: state,
              builder: (context, title, _) => page(
                StateDissolve(
                  fit: StackFit.passthrough,
                  child: KeyedSubtree(key: ValueKey(title), child: bar(title)),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/next',
          pageBuilder: (c, s) => pushPage(s, page(bar('Upload proof'))),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: buildTheme(), routerConfig: router),
    );
    await tester.pumpAndSettle();
    final rest = tester.getTopLeft(_button('Back'));

    state.value = 'Your proof';
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Activation'), findsOneWidget);
    router.push('/next');
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.takeException(), isNull);
    expect(find.text('Your proof'), findsNWidgets(2));
    expect(find.text('Activation'), findsOneWidget);
    final flying = find.text('Your proof').last;
    expect(_fadeOf(tester.element(flying)), inExclusiveRange(0, 1));
    expect(tester.getTopLeft(_button('Back').last), rest);
    await tester.pumpAndSettle();
  });
}
