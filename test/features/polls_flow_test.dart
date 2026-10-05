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

const _select = 'HapticFeedbackType.selectionClick';
const _error = 'HapticFeedbackType.mediumImpact';

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
  testWidgets('B2: See all, Orchid Foods, two votes, done, back to Discover', (
    tester,
  ) async {
    final haptics = recordHaptics(tester);
    final container = await pumpApp(
      tester,
      Routes.home,
      overrides: pollsLane(),
    );
    expect(find.text('Quick polls'), findsOneWidget);
    expect(_tile(tester, _flavour).meta, '2 questions');
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
      find.text('1 poll · 2 questions · about 10 seconds'),
      findsOneWidget,
    );
    expect(find.text('Pick one'), findsNWidgets(2));
    expect(find.text('Closes in 2 days'), findsOneWidget);
    expect(find.text('Closes in 5 days'), findsOneWidget);
    expect(_card(tester, _flavour).state, IqPollCardState.open);

    await _tap(tester, find.text('Zobo and ginger'));
    expect(haptics, [_select]);
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
    expect(_card(tester, _size).state, IqPollCardState.open);
    expect(find.text('Quick polls'), findsWidgets);

    await _tap(tester, find.text('1 litre bottle'));
    expect(find.text('You’re done'), findsOneWidget);
    expect(
      find.text(
        '2 answers sent. Orchid Foods shares the results in about a week.',
      ),
      findsOneWidget,
    );
    expect(find.text('You voted · 198 votes'), findsOneWidget);
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
    expect(haptics, [_select, _error]);
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
