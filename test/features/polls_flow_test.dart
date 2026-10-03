import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/polls/poll_sheet.dart';
import 'package:iqly_mobile/features/polls/polls_screen.dart';
import 'package:iqly_mobile/features/polls/polls_state.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/brand_bubble.dart';
import 'package:iqly_mobile/ui/poll_card.dart';
import 'package:iqly_mobile/ui/poll_option.dart';
import 'package:iqly_mobile/ui/pressable.dart';

import '../golden/screens/app_harness.dart';
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

IqBrandBubble _bubble(WidgetTester tester, String name) =>
    tester.widget<IqBrandBubble>(
      find.byWidgetPredicate((w) => w is IqBrandBubble && w.name == name),
    );

IqPollCard _card(WidgetTester tester, String question) =>
    tester.widget<IqPollCard>(
      find.byWidgetPredicate((w) => w is IqPollCard && w.question == question),
    );

const _flavour = 'Which flavour should we launch first?';
const _size = 'Which can size should the first run use?';

void main() {
  testWidgets('B2: See all, Orchid Foods, two votes, back to Discover', (
    tester,
  ) async {
    final haptics = recordHaptics(tester);
    final container = await pumpApp(
      tester,
      Routes.home,
      overrides: laneOverrides(),
    );
    expect(find.text('Open polls'), findsOneWidget);
    expect(_bubble(tester, 'Orchid Foods').count, '2');
    expect(_bubble(tester, 'Orchid Foods').state, IqBrandBubbleState.newPolls);
    expect(_bubble(tester, 'Unibooks').count, '1');
    expect(_bubble(tester, 'Sunline').state, IqBrandBubbleState.done);

    await _tap(tester, _labelled('See all').first);
    expect(find.byType(PollsScreen), findsOneWidget);
    expect(find.byType(PollSheet), findsNothing);
    expect(find.text('Vote, then see results.'), findsOneWidget);
    expect(find.text('Businesses with open polls'), findsOneWidget);
    expect(find.text('2 open polls'), findsOneWidget);
    expect(find.text('1 open poll'), findsOneWidget);
    expect(find.text('You voted · results in 1 day'), findsOneWidget);

    await _tap(tester, find.text('Orchid Foods'));
    expect(find.byType(PollSheet), findsOneWidget);
    expect(find.text('2 OPEN POLLS'), findsOneWidget);
    expect(find.text('Pick one'), findsNWidgets(2));
    expect(find.text('2 days left'), findsOneWidget);
    expect(find.text('5 days left'), findsOneWidget);
    expect(_card(tester, _flavour).state, IqPollCardState.open);

    await _tap(tester, find.text('Zobo and ginger'));
    expect(haptics, [_select]);
    expect(_card(tester, _flavour).state, IqPollCardState.voted);
    expect(find.text('You voted · 214 votes'), findsOneWidget);
    expect(find.text('45%'), findsOneWidget);
    expect(find.text('33%'), findsOneWidget);
    expect(find.text('22%'), findsOneWidget);
    expect(find.text('1 OF 2 ANSWERED'), findsOneWidget);
    final chosen = tester.widget<IqPollOption>(
      find.byWidgetPredicate(
        (w) => w is IqPollOption && w.label == 'Zobo and ginger',
      ),
    );
    expect(chosen.state, IqPollOptionState.chosen);
    expect(_card(tester, _size).state, IqPollCardState.open);

    await _tap(tester, find.text('1 litre bottle'));
    expect(find.text('2 OF 2 ANSWERED'), findsOneWidget);
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
    expect(find.text('You voted · results in 2 days'), findsOneWidget);
    expect(find.text('1 open poll'), findsOneWidget);

    await _tap(tester, _labelled('Back'));
    expect(find.byType(PollsScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(_bubble(tester, 'Orchid Foods').state, IqBrandBubbleState.done);
    expect(_bubble(tester, 'Unibooks').count, '1');
  });

  testWidgets('B2: a bubble raises its business over the Polls page', (
    tester,
  ) async {
    await pumpApp(tester, Routes.home, overrides: laneOverrides());
    await _tap(tester, find.text('Unibooks'));
    expect(find.byType(PollsScreen), findsOneWidget);
    expect(find.byType(PollSheet), findsOneWidget);
    expect(find.text('Where should we take orders first?'), findsOneWidget);
    expect(find.text('1 OPEN POLL'), findsOneWidget);

    await _tap(tester, _labelled('Close'));
    expect(find.byType(PollSheet), findsNothing);
    expect(find.byType(PollsScreen), findsOneWidget);
    await _tap(tester, _labelled('Back'));
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('B2: Sunline is already answered and cannot be voted again', (
    tester,
  ) async {
    await pumpApp(tester, Routes.polls, overrides: laneOverrides());
    await _tap(tester, find.text('Sunline'));
    expect(find.text('1 OF 1 ANSWERED'), findsOneWidget);
    expect(find.text('You voted · 176 votes'), findsOneWidget);
    expect(find.text('1 day left'), findsOneWidget);
    await _tap(tester, find.text('Cold drinks'));
    expect(find.text('You voted · 176 votes'), findsOneWidget);
  });

  testWidgets('B2: a vote that does not count clears the pick', (tester) async {
    final haptics = recordHaptics(tester);
    await pumpApp(
      tester,
      Routes.polls,
      overrides: laneOverrides(polls: FailingPollsService()),
    );
    await _tap(tester, find.text('Unibooks'));
    await _tap(tester, find.text('Instagram'));
    expect(haptics, [_select, _error]);
    expect(find.text('Couldn’t send. Check your connection.'), findsOneWidget);
    expect(
      _card(tester, 'Where should we take orders first?').state,
      IqPollCardState.open,
    );
    expect(find.text('1 OPEN POLL'), findsOneWidget);
  });

  testWidgets('B2: the pick holds while the vote goes in', (tester) async {
    final polls = HeldPollsService();
    await pumpApp(tester, Routes.polls, overrides: laneOverrides(polls: polls));
    await _tap(tester, find.text('Unibooks'));
    await _tap(tester, find.text('Our own app'));
    final card = _card(tester, 'Where should we take orders first?');
    expect(card.state, IqPollCardState.open);
    expect(card.selected, 2);
    expect(card.onVote, isNull);

    polls.release();
    await tester.pumpAndSettle();
    expect(
      _card(tester, 'Where should we take orders first?').state,
      IqPollCardState.voted,
    );
    expect(find.text('You voted · 98 votes'), findsOneWidget);
    expect(find.text('1 OF 1 ANSWERED'), findsOneWidget);
  });
}
