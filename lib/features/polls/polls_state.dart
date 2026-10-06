import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  /// A return to Discover: the tiles stay as they are until the new list
  /// lands; a failure keeps them.
  Future<void> refreshQuietly() async {
    if (!state.hasValue) return;
    try {
      final businesses = await ref.read(pollsServiceProvider).businesses();
      state = AsyncData(businesses);
    } catch (_) {}
  }

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

String questions(int count) => '$count question${count == 1 ? '' : 's'}';

/// The poll sheet's BrandHeader line: "1 poll · 2 questions · about 10
/// seconds", five seconds a question.
String pollDetail(PollBusiness business) {
  final count = business.polls.length;
  return '1 poll · ${questions(count)} · about ${count * 5} seconds';
}

/// Once every question is answered: "2 answers sent. Orchid Foods shares
/// the results in about a week."
String pollDoneDetail(PollBusiness business) {
  final count = business.answered;
  return '$count answer${count == 1 ? '' : 's'} sent. '
      '${business.name} shares the results in about a week.';
}

/// Whether every poll the business runs has closed: its tile dims and
/// stops taking taps (480:22779).
bool pollsClosed(PollBusiness business, DateTime now) =>
    business.polls.every((p) => p.closedAt(now));
