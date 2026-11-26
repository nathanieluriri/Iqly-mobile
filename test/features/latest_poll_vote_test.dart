import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/polls_data.dart';
import 'package:iqly_mobile/features/polls/latest_poll_vote.dart';
import 'package:iqly_mobile/features/polls/polls_state.dart';

void main() {
  test('changing a counted vote moves the tally, it does not add a second', () {
    final voted = Poll(
      id: 'p',
      question: 'q',
      choices: const ['a', 'b', 'c'],
      votes: const [95, 71, 47],
      closesAt: DateTime(2026),
    ).withChange(0);
    expect(voted.votes, [96, 71, 47]);
    expect(voted.withChange(1).votes, [95, 72, 47]);
    expect(voted.withChange(1).chosen, 1);
    expect(voted.withChange(0).votes, [96, 71, 47]);
  });

  test('three quick picks send only the last one', () async {
    final sent = <int>[];
    final queue = LatestPollVote((choice) async {
      sent.add(choice);
      return VoteOutcome.counted;
    }, delay: const Duration(milliseconds: 20));
    unawaited(queue.enqueue(0));
    unawaited(queue.enqueue(1));
    final last = queue.enqueue(2);
    await last;
    expect(sent, [2]);
  });

  test('a pick during a send waits, then sends only the latest', () async {
    final sent = <int>[];
    final hold = Completer<void>();
    final queue = LatestPollVote((choice) async {
      sent.add(choice);
      if (choice == 0) await hold.future;
      return VoteOutcome.counted;
    }, delay: Duration.zero);
    final first = queue.enqueue(0);
    await Future<void>.delayed(Duration.zero);
    unawaited(queue.enqueue(1));
    unawaited(queue.enqueue(2));
    hold.complete();
    await first;
    await queue.done;
    expect(sent, [0, 2]);
  });
}
