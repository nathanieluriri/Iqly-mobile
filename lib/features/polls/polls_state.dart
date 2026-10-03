import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/deadline.dart';
import '../../data/polls_data.dart';
import '../../data/polls_service.dart';

/// The businesses with open polls and the person's votes, shared by the
/// Polls screens and Discover's bubbles. No automatic retry: the failed
/// state offers "Try again".
class PollsNotifier extends AsyncNotifier<List<PollBusiness>> {
  @override
  Future<List<PollBusiness>> build() =>
      ref.watch(pollsServiceProvider).businesses();

  void retry() => ref.invalidateSelf();

  /// Votes [choice] on [pollId]; true once the vote has counted.
  Future<bool> vote(String pollId, int choice) async {
    final Poll poll;
    try {
      poll = await ref.read(pollsServiceProvider).vote(pollId, choice);
    } catch (_) {
      return false;
    }
    final data = state.value;
    if (data != null) {
      state = AsyncData([
        for (final b in data)
          b.polls.any((p) => p.id == poll.id) ? b.withPoll(poll) : b,
      ]);
    }
    return true;
  }
}

final pollsProvider = AsyncNotifierProvider<PollsNotifier, List<PollBusiness>>(
  PollsNotifier.new,
  retry: (_, _) => null,
);

/// Whether the Polls list has arrived once this session; later visits show
/// it in place (MOTION-SPEC §2.6).
class PollsArrivedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void arrived() => state = true;
}

final pollsArrivedProvider = NotifierProvider<PollsArrivedNotifier, bool>(
  PollsArrivedNotifier.new,
);

/// "2 days", "1 day", "6h", "12 min": what is left on a poll, rounded down
/// like the brief deadlines so it never promises more time than is left.
String pollTimeLeft(Duration left) {
  if (left.inHours < 1) return '${left.inMinutes} min';
  if (left.inHours < 24) return '${left.inHours}h';
  final days = left.inDays;
  return '$days ${days == 1 ? 'day' : 'days'}';
}

/// The Polls row under a business: "2 open polls", or once all are
/// answered "You voted · results in 1 day".
String businessLine(PollBusiness business, DateTime now) {
  if (business.allAnswered) {
    final left = timeLeft(business.firstClose, now)!;
    return 'You voted · results in ${pollTimeLeft(left)}';
  }
  return openPolls(business.unanswered);
}

String openPolls(int count) => '$count open ${count == 1 ? 'poll' : 'polls'}';

/// The sheet's eyebrow: "2 open polls", then "1 of 2 answered".
String sheetEyebrow(PollBusiness business) => business.answered == 0
    ? openPolls(business.polls.length)
    : '${business.answered} of ${business.polls.length} answered';
