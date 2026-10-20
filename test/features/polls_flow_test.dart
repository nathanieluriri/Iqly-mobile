import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/polls/poll_sheet.dart';
import 'package:iqly_mobile/features/polls/polls_routes.dart';
import 'package:iqly_mobile/features/polls/polls_screen.dart';
import 'package:iqly_mobile/features/polls/polls_state.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/poll_card.dart';
import 'package:iqly_mobile/ui/poll_option.dart';
import 'package:iqly_mobile/ui/poll_tile.dart';
import 'package:iqly_mobile/ui/pressable.dart';

import '../golden/screens/app_harness.dart';
import '../golden/screens/discover_harness.dart';
import '../golden/screens/polls_notifications_help_harness.dart';
import 'entry_harness.dart' show recordHaptics;

const _light = 'HapticFeedbackType.lightImpact';
const _select = 'HapticFeedbackType.lightImpact';
const _error = 'HapticFeedbackType.heavyImpact';

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _labelled(String label) =>
    find.byWidgetPredicate((w) => w is IqPressable && w.semanticLabel == label);

IqPollTile _tile(WidgetTester tester, String question) =>
    tester.widget<IqPollTile>(
      find.byWidgetPredicate((w) => w is IqPollTile && w.question == question),
    );

IqPollCard _card(WidgetTester tester, String question) =>
    tester.widget<IqPollCard>(
      find.byWidgetPredicate((w) => w is IqPollCard && w.question == question),
    );

const _flavour = 'Which flavour should we launch first?';
const _size = 'Which can size should the first run use?';
const _books = 'Where do you buy your course books?';
const _kiosk = 'When should a kiosk open in the morning?';

void main() {
  testWidgets('B2: See all, Orchid Foods, three questions one at a time, '
      'done, back to Discover', (tester) async {
    final haptics = recordHaptics(tester);
    final container = await pumpApp(
      tester,
      Routes.home,
      overrides: pollsLane(),
    );
    expect(find.text('Quick polls'), findsOneWidget);
    expect(_tile(tester, _flavour).meta, '3 questions');
    expect(_tile(tester, _flavour).state, IqPollTileState.open);
    expect(_tile(tester, _books).meta, '1 question');
    expect(_tile(tester, _kiosk).state, IqPollTileState.answered);

    await _tap(tester, _labelled('See all').first);
    expect(find.byType(PollsScreen), findsOneWidget);
    expect(find.byType(PollSheet), findsNothing);
    expect(find.text('Open polls'), findsOneWidget);

    await _tap(tester, find.text(_flavour));
    expect(find.byType(PollSheet), findsOneWidget);
    expect(
      find.text('1 poll · 3 questions · about 15 seconds'),
      findsOneWidget,
    );
    expect(find.text('QUESTION 1 OF 3'), findsOneWidget);
    expect(find.text('Pick one'), findsOneWidget);
    expect(find.text('Back'), findsNothing);
    expect(find.text(_size), findsNothing);
    expect(_card(tester, _flavour).state, IqPollCardState.open);

    await _tap(tester, find.text('Zobo and ginger'));
    expect(haptics, [_light, _light, _select]);
    expect(_card(tester, _flavour).state, IqPollCardState.voted);
    expect(find.text('You voted · 214 votes'), findsOneWidget);
    expect(find.text('45%'), findsOneWidget);
    expect(find.text('33%'), findsOneWidget);
    expect(find.text('22%'), findsOneWidget);
    final chosen = tester.widget<IqPollOption>(
      find.byWidgetPredicate(
        (w) => w is IqPollOption && w.label == 'Zobo and ginger',
      ),
    );
    expect(chosen.state, IqPollOptionState.chosen);

    await _tap(tester, find.text('Next question'));
    expect(find.text('QUESTION 2 OF 3'), findsOneWidget);
    expect(find.text('Because you picked Zobo and ginger'), findsOneWidget);
    await _tap(tester, find.text('Back'));
    expect(find.text('QUESTION 1 OF 3'), findsOneWidget);
    expect(_card(tester, _flavour).state, IqPollCardState.voted);
    await _tap(tester, find.text('Next question'));

    await _tap(tester, find.text('A little'));
    expect(find.text('You voted · 96 votes'), findsOneWidget);
    await _tap(tester, find.text('Next question'));
    expect(find.text('QUESTION 3 OF 3'), findsOneWidget);

    await _tap(tester, find.text('1 litre bottle'));
    expect(find.text('You voted · 198 votes'), findsOneWidget);
    expect(find.text('Quick polls'), findsWidgets);
    await _tap(tester, find.text('Done'));
    expect(find.text('You’re done'), findsOneWidget);
    expect(
      find.text(
        '3 answers sent. Orchid Foods shares the results in about a week.',
      ),
      findsOneWidget,
    );
    expect(find.text('Pick one'), findsNothing);
    expect(
      container
          .read(pollsProvider)
          .value!
          .firstWhere((b) => b.id == 'orchid-foods')
          .allAnswered,
      isTrue,
    );

    await _tap(tester, _labelled('Close'));
    expect(find.byType(PollSheet), findsNothing);
    expect(find.byType(PollsScreen), findsOneWidget);
    expect(_tile(tester, _flavour).state, IqPollTileState.answered);

    await _tap(tester, _labelled('Back'));
    expect(find.byType(PollsScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(_tile(tester, _flavour).state, IqPollTileState.answered);
    expect(_tile(tester, _books).state, IqPollTileState.open);
  });

  testWidgets('B2: Tiger nut skips the ginger question to the last one', (
    tester,
  ) async {
    await pumpApp(tester, pollsOf('orchid-foods'), overrides: pollsLane());
    await _tap(tester, find.text('Tiger nut'));
    await _tap(tester, find.text('Next question'));
    expect(find.text('LAST QUESTION'), findsOneWidget);
    expect(find.text('How much ginger should it have?'), findsNothing);
    expect(find.text(_size), findsOneWidget);
    await _tap(tester, find.text('50cl can'));
    await _tap(tester, find.text('Done'));
    expect(
      find.text(
        '2 answers sent. Orchid Foods shares the results in about a week.',
      ),
      findsOneWidget,
    );
    await _tap(tester, _labelled('Close'));
  });

  testWidgets('B2: a tile raises its business over the Quick polls page', (
    tester,
  ) async {
    await pumpApp(tester, Routes.home, overrides: pollsLane());
    await _tap(tester, find.text(_books));
    expect(find.byType(PollsScreen), findsOneWidget);
    expect(find.byType(PollSheet), findsOneWidget);
    expect(find.text('1 poll · 1 question · about 5 seconds'), findsOneWidget);

    await _tap(tester, _labelled('Close'));
    expect(find.byType(PollSheet), findsNothing);
    expect(find.byType(PollsScreen), findsOneWidget);
    await _tap(tester, _labelled('Back'));
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('B2: dragging the sheet up opens the polls as a page', (
    tester,
  ) async {
    await pumpApp(tester, pollsOf('orchid-foods'), overrides: pollsLane());
    await tester.fling(
      find.text('Quick polls').last,
      const Offset(0, -300),
      2000,
    );
    await tester.pumpAndSettle();
    expect(find.byType(PollSheet), findsNothing);
    expect(find.byType(PollPage), findsOneWidget);
    await _tap(tester, find.text('Zobo and ginger'));
    expect(find.text('You voted · 214 votes'), findsOneWidget);
  });

  group('B2: the sheet dragged up', () {
    /// The product of every fade above [finder].
    double shown(WidgetTester tester, Finder finder) {
      var opacity = 1.0;
      for (final widget in tester.widgetList(
        find.ancestor(
          of: finder,
          matching: find.byWidgetPredicate(
            (w) => w is FadeTransition || w is Opacity,
          ),
        ),
      )) {
        opacity *= switch (widget) {
          FadeTransition(:final opacity) => opacity.value,
          _ => (widget as Opacity).opacity,
        };
      }
      return opacity;
    }

    /// The copies of [text] on the sheet and the page that show at all.
    int copies(WidgetTester tester, String text) {
      final finder = find.descendant(
        of: find.byWidgetPredicate((w) => w is PollSheet || w is PollPage),
        matching: find.text(text),
      );
      var count = 0;
      for (var i = 0; i < finder.evaluate().length; i++) {
        if (shown(tester, finder.at(i)) > 0.01) count++;
      }
      return count;
    }

    testWidgets('follows the finger, and short of half way settles back', (
      tester,
    ) async {
      await pumpApp(
        tester,
        pollsOf('orchid-foods'),
        overrides: pollsLane(),
        reducedMotion: false,
      );
      final title = find.text('Quick polls').last;
      final top = tester.getTopLeft(title).dy;
      final gesture = await tester.startGesture(tester.getCenter(title));
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump(const Duration(milliseconds: 100));
      final before = tester.getTopLeft(title).dy;
      expect(before, lessThan(top));
      await gesture.moveBy(const Offset(0, 8));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getTopLeft(title).dy, moreOrLessEquals(before + 8));
      expect(tester.getTopLeft(title).dy, lessThan(top));
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(PollSheet), findsOneWidget);
      expect(find.byType(PollPage), findsNothing);
      expect(tester.getTopLeft(title).dy, top);
    });

    testWidgets('hands over to the page with one copy on screen', (
      tester,
    ) async {
      await pumpApp(
        tester,
        pollsOf('orchid-foods'),
        overrides: pollsLane(),
        reducedMotion: false,
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Quick polls').last),
      );
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(0, -15));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      for (var frame = 0; frame < 60; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          copies(tester, _flavour),
          lessThanOrEqualTo(1),
          reason: '$frame',
        );
        expect(copies(tester, 'Orchid Foods'), lessThanOrEqualTo(1));
      }
      await tester.pumpAndSettle();
      expect(find.byType(PollSheet), findsNothing);
      expect(find.byType(PollPage), findsOneWidget);
      expect(copies(tester, _flavour), 1);
    });
  });

  testWidgets('B2: Sunline is already answered and cannot be voted again', (
    tester,
  ) async {
    await pumpApp(tester, Routes.polls, overrides: pollsLane());
    await _tap(tester, find.text(_kiosk));
    expect(find.text('You’re done'), findsOneWidget);
    expect(find.text('You voted · 176 votes'), findsOneWidget);
    expect(find.text('Closes in 1 day'), findsOneWidget);
    await _tap(tester, find.text('6 am'));
    expect(find.text('You voted · 176 votes'), findsOneWidget);
  });

  testWidgets('B2: a closed poll dims its tile and takes no taps', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Routes.polls,
      overrides: pollsLane(),
      clock: () => figmaNow.add(const Duration(days: 1, minutes: 1)),
    );
    expect(_tile(tester, _kiosk).onTap, isNull);
    expect(_tile(tester, _flavour).onTap, isNotNull);
  });

  testWidgets('B2: a vote that does not count clears the pick', (tester) async {
    final haptics = recordHaptics(tester);
    await pumpApp(
      tester,
      Routes.polls,
      overrides: pollsLane(polls: FailingPollsService()),
    );
    await _tap(tester, find.text(_books));
    await _tap(tester, find.text('WhatsApp sellers'));
    expect(haptics, [_light, _select, _error]);
    expect(find.text('Couldn’t send. Check your connection.'), findsOneWidget);
    expect(_card(tester, _books).state, IqPollCardState.open);
    expect(find.text('Quick polls'), findsWidgets);
  });

  testWidgets('B2: the pick holds while the vote goes in', (tester) async {
    final polls = HeldPollsService();
    await pumpApp(tester, Routes.polls, overrides: pollsLane(polls: polls));
    await _tap(tester, find.text(_books));
    await _tap(tester, find.text('Online'));
    final card = _card(tester, _books);
    expect(card.state, IqPollCardState.open);
    expect(card.selected, 2);
    expect(card.onVote, isNull);

    polls.release();
    await tester.pumpAndSettle();
    expect(_card(tester, _books).state, IqPollCardState.voted);
    expect(find.text('You voted · 98 votes'), findsOneWidget);
    expect(find.text('You’re done'), findsOneWidget);
  });
}
