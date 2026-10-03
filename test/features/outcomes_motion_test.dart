import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/deadline.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/outcomes_data.dart';
import 'package:iqly_mobile/features/outcomes/outcomes_routes.dart';
import 'package:iqly_mobile/features/outcomes/outcomes_state.dart';
import 'package:iqly_mobile/features/outcomes/result_screen.dart';
import 'package:iqly_mobile/features/submissions/submissions_routes.dart';
import 'package:iqly_mobile/features/submissions/submissions_state.dart';
import 'package:iqly_mobile/ui/leaderboard_row.dart';
import 'package:iqly_mobile/ui/share_card.dart';
import 'package:iqly_mobile/ui/share_target.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../golden/golden.dart';
import '../golden/screens/app_harness.dart';
import 'entry_harness.dart' show recordHaptics;

const _success = 'HapticFeedbackType.successNotification';

void _reduce(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

ResultData _result(String id) {
  final data = DemoData(now: figmaNow);
  final submission = data.submissions.firstWhere((s) => s.id == id);
  final brief = data.briefs.firstWhere((b) => b.id == submission.briefId);
  final award = data.ledger.where((l) => l.submissionId == id).firstOrNull;
  return ResultData(
    item: SubmissionItem(
      submission: submission,
      brief: brief,
      awardKobo: award?.amountKobo,
    ),
    outcome: OutcomesDemo.of(id, figmaNow),
    name: DemoData.user.name,
    next: data.briefs.firstWhere((b) => b.id == 'c12'),
  );
}

Future<void> _view(
  WidgetTester tester,
  Widget view, {
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final shared = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(shared),
        clockProvider.overrideWithValue(() => figmaNow),
      ],
      child: MaterialApp(home: Scaffold(body: view)),
    ),
  );
}

/// The share card's arrival: the fade and rise around its pressable.
(double, double) _card(WidgetTester tester) {
  final fade = find
      .ancestor(of: find.byType(WinnerCard), matching: find.byType(Opacity))
      .first;
  final rise = tester
      .widget<Transform>(
        find.descendant(of: fade, matching: find.byType(Transform)).first,
      )
      .transform
      .getTranslation()
      .y;
  return (tester.widget<Opacity>(fade).opacity, rise);
}

IqShareCard _shareCard(WidgetTester tester) =>
    tester.widget<IqShareCard>(find.byType(IqShareCard));

void main() {
  setUpAll(loadAppFonts);

  group('Winner celebration (MOTION-SPEC §5.33)', () {
    testWidgets('the card rises 24 from +120, the marker wipes from +440 with '
        'the success haptic, the trophy sweep from +560', (tester) async {
      final haptics = recordHaptics(tester);
      await _view(tester, WinnerView(data: _result('s2')));
      expect(_card(tester), (0.0, IqTravel.screen));

      await tester.pump(const Duration(milliseconds: 119));
      expect(_card(tester).$1, 0);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 160));
      final (opacity, rise) = _card(tester);
      expect(opacity, inExclusiveRange(0, 1));
      expect(rise, inExclusiveRange(0, IqTravel.screen));

      await tester.pump(const Duration(milliseconds: 150));
      expect(haptics, isEmpty);
      expect(_shareCard(tester).markerReveal!.value, 0);
      await tester.pump(const Duration(milliseconds: 20));
      expect(haptics, [_success]);
      expect(_card(tester), (1.0, 0.0));

      await tester.pump(const Duration(milliseconds: 100));
      expect(_shareCard(tester).markerReveal!.value, inExclusiveRange(0, 1));
      expect(_shareCard(tester).accentReveal!.value, 0);
      await tester.pump(const Duration(milliseconds: 130));
      expect(_shareCard(tester).markerReveal!.value, 1);
      expect(_shareCard(tester).accentReveal!.value, inExclusiveRange(0, 1));

      await tester.pumpAndSettle();
      expect(_shareCard(tester).accentReveal!.value, 1);
      expect(haptics, [_success]);
    });

    testWidgets('a second visit plays it without the haptic', (tester) async {
      final haptics = recordHaptics(tester);
      await _view(
        tester,
        WinnerView(data: _result('s2')),
        prefs: {
          'outcomes.celebrated': ['s2'],
        },
      );
      await tester.pumpAndSettle();
      expect(haptics, isEmpty);
    });

    testWidgets('reduced motion: the card fades in place, the haptic plays', (
      tester,
    ) async {
      _reduce(tester);
      final haptics = recordHaptics(tester);
      await _view(tester, WinnerView(data: _result('s2')));
      expect(haptics, [_success]);
      expect(_shareCard(tester).markerReveal, isNull);
      expect(_shareCard(tester).accentReveal, isNull);
      await tester.pump(const Duration(milliseconds: 75));
      expect(_card(tester).$1, inExclusiveRange(0, 1));
      expect(_card(tester).$2, 0);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_card(tester), (1.0, 0.0));
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('Not selected', () {
    testWidgets('the note bubble arrives at +200, growing from .96 at its '
        'corner', (tester) async {
      await _view(tester, NotSelectedView(data: _result('s5')));
      Transform scale() => tester.widget<Transform>(
        find
            .ancestor(
              of: find.text(
                'Good idea. The winners put every quick job on one counter.',
              ),
              matching: find.byType(Transform),
            )
            .first,
      );
      double opacity() => tester
          .widget<Opacity>(
            find
                .ancestor(
                  of: find.byWidget(scale()),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity;

      expect(scale().transform.storage[0], closeTo(IqScale.soft, .001));
      await tester.pump(const Duration(milliseconds: 199));
      expect(opacity(), 0);
      await tester.pump(const Duration(milliseconds: 111));
      expect(opacity(), inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(opacity(), 1);
      expect(scale().transform.storage[0], 1);
    });

    testWidgets('reduced motion: everything fades in, nothing moves', (
      tester,
    ) async {
      _reduce(tester);
      await _view(tester, NotSelectedView(data: _result('s5')));
      await tester.pump(const Duration(milliseconds: 160));
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.text('Not this time'), findsOneWidget);
    });
  });

  group('Leaderboard', () {
    testWidgets("the contributor's rank disc pops at its row's arrival + 120", (
      tester,
    ) async {
      await pumpApp(tester, leaderboardPath('s2'), reducedMotion: false);
      final you = tester.widget<IqLeaderboardRow>(
        find.byWidgetPredicate(
          (w) => w is IqLeaderboardRow && w.state == IqLeaderboardRowState.you,
        ),
      );
      expect(you.rankDelay, IqDurations.stagger * 4 + IqDurations.chain);
      for (final row in tester.widgetList<IqLeaderboardRow>(
        find.byType(IqLeaderboardRow),
      )) {
        if (row.state == IqLeaderboardRowState.standard) {
          expect(row.rankDelay, isNull);
        }
      }
    });

    testWidgets('a disc with a delay pops in once it is up', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: SizedBox(
              width: 358,
              child: IqLeaderboardRow(
                state: IqLeaderboardRowState.you,
                rankDelay: Duration(milliseconds: 280),
              ),
            ),
          ),
        ),
      );
      double disc() => tester
          .widget<FadeTransition>(
            find.descendant(
              of: find.byType(Pop),
              matching: find.byType(FadeTransition),
            ),
          )
          .opacity
          .value;
      await tester.pump(const Duration(milliseconds: 279));
      expect(disc(), 0);
      await tester.pump(const Duration(milliseconds: 111));
      expect(disc(), inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(disc(), 1);
    });
  });

  group('Share sheet', () {
    testWidgets('the card flies from the Winner into the 0.62 preview and the '
        'targets pop in 40 apart', (tester) async {
      await pumpApp(tester, resultPath('s2'), reducedMotion: false);
      expect(tester.getRect(find.byType(IqShareCard)).width, closeTo(358, .5));

      await tester.tap(find.text('Share your win'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      final flying = tester.getRect(find.byType(IqShareCard).last).width;
      expect(flying, inExclusiveRange(222, 358));
      double pop(int i) => tester
          .widget<FadeTransition>(
            find
                .descendant(
                  of: find.ancestor(
                    of: find.byType(IqShareTarget).at(i),
                    matching: find.byType(Pop),
                  ),
                  matching: find.byType(FadeTransition),
                )
                .first,
          )
          .opacity
          .value;
      expect(pop(0), 0);

      await tester.pump(const Duration(milliseconds: 150));
      expect(pop(0), inExclusiveRange(0, 1));
      expect(pop(4), 0);
      await tester.pumpAndSettle();
      expect(pop(4), 1);
      final preview = find.byType(IqShareCard).last;
      expect(tester.getRect(preview).width, closeTo(222, .5));

      await tester.tapAt(const Offset(195, 120));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.getRect(find.byType(IqShareCard).last).width,
        inExclusiveRange(222, 358),
      );
      await tester.pumpAndSettle();
      expect(find.byType(IqShareCard), findsOneWidget);
      expect(tester.getRect(find.byType(IqShareCard)).width, closeTo(358, .5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the card flies in the app’s text style, both ways', (
      tester,
    ) async {
      await pumpApp(tester, resultPath('s2'), reducedMotion: false);
      Finder flying() => find.byType(IqShareCard).last;
      List<TextDecoration?> decorations() => [
        for (final text in tester.renderObjectList<RenderParagraph>(
          find.descendant(of: flying(), matching: find.byType(RichText)),
        ))
          text.text.style?.decoration,
      ];

      await tester.tap(find.text('Share your win'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.getRect(flying()).width, inExclusiveRange(222, 358));
      expect(decorations(), isNotEmpty);
      expect(decorations(), everyElement(isNull));

      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(195, 120));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getRect(flying()).width, inExclusiveRange(222, 358));
      expect(decorations(), isNotEmpty);
      expect(decorations(), everyElement(isNull));
      await tester.pumpAndSettle();
    });

    testWidgets('the card flies into the sheet ease-in-out (spec 4.4)', (
      tester,
    ) async {
      await pumpApp(tester, resultPath('s2'), reducedMotion: false);
      await tester.tap(find.text('Share your win'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      // Halfway through the 300 ms rise an ease-in-out flight is halfway
      // between the 358 card and the 222 preview.
      expect(
        tester.getRect(find.byType(IqShareCard).last).width,
        closeTo(290, 15),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('reduced motion: no flight, the sheet fades in place', (
      tester,
    ) async {
      await pumpApp(tester, resultPath('s2'));
      await tester.tap(find.text('Share your win'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 75));
      for (final card in find.byType(IqShareCard).evaluate()) {
        final width = tester.getRect(find.byWidget(card.widget)).width;
        expect(width, anyOf(closeTo(358, .5), closeTo(222, .5)));
      }
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  test('the leaderboards foot to the brief pools and the ledger awards', () {
    final data = DemoData(now: figmaNow);
    for (final id in ['s2', 's5']) {
      final result = _result(id);
      final board = Leaderboard.of(result)!;
      final paid = [
        for (final item in board.items)
          if (item is BoardRow && item.entry.amountKobo != null)
            item.entry.amountKobo!,
      ];
      final brief = data.briefs.firstWhere(
        (b) => b.id == result.item.submission.briefId,
      );
      expect(paid.fold(0, (a, b) => a + b), brief.rewardPoolKobo, reason: id);
      expect(board.paid, paid.length);
      final cutoff = board.items.whereType<BoardCutoff>().single;
      expect(cutoff.poolKobo, brief.rewardPoolKobo);
    }
    final winner = Leaderboard.of(_result('s2'))!;
    final you = winner.items.whereType<BoardRow>().singleWhere((r) => r.you);
    final award = data.ledger.singleWhere((l) => l.submissionId == 's2');
    expect(you.entry.amountKobo, award.amountKobo);
    expect(you.entry.rank, 5);
    expect(winner.title, 'Top 5 of 48 entries');

    final missed = Leaderboard.of(_result('s5'))!;
    expect(missed.items.whereType<BoardGap>(), hasLength(1));
    final mine = missed.items.whereType<BoardRow>().singleWhere((r) => r.you);
    expect(mine.entry.amountKobo, isNull);
    expect(mine.entry.entry, 'One counter for quick jobs');
    expect(
      OutcomesDemo.of('s5', figmaNow)!.note!.business,
      data.briefs.firstWhere((b) => b.id == 'c7').businessName,
    );
    expect(Leaderboard.of(_result('s3')), isNull);
  });

  test('ordinals and note times read as the frames do', () {
    expect([1, 2, 3, 4, 5, 9, 11, 12, 13, 21, 22, 23, 111].map(ordinal), [
      '1st',
      '2nd',
      '3rd',
      '4th',
      '5th',
      '9th',
      '11th',
      '12th',
      '13th',
      '21st',
      '22nd',
      '23rd',
      '111th',
    ]);
    final note = OutcomesDemo.of('s5', figmaNow)!.note!;
    expect(noteTime(note.sentAt, figmaNow), 'FRI, 11:20 AM');
    expect(
      noteTime(figmaNow.subtract(const Duration(days: 20)), figmaNow),
      '13 SEP, 9:41 AM',
    );
  });
}
