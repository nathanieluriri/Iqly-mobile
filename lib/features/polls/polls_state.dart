import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../../data/api_client.dart';
import '../../data/polls_data.dart';
import '../../data/polls_service.dart';
import '../../surfaces/surfaces.dart' show republishSurfaces;

/// How a vote went.
enum VoteOutcome {
  counted,

  /// No answer from the API, a throttle (429) or a fault on its side, or
  /// the demo failing as if offline: picking again can send it.
  offline,

  /// The API turned it down: voted before, closed, gone, or not a choice
  /// the poll has. The poll is read again, so it shows as it stands.
  refused,

  /// The account is closing, so it takes no writes.
  closing,
}

/// The businesses with open polls and the person's votes, shared by the
/// Polls screens and Discover's bubbles. No automatic retry: the failed
/// state offers "Try again". An answer that lands once its account is no
/// longer signed in changes nothing.
class PollsNotifier extends AsyncNotifier<List<PollBusiness>> {
  @override
  Future<List<PollBusiness>> build() =>
      ref.watch(pollsServiceProvider).businesses();

  void retry() => ref.invalidateSelf();

  /// A return to Discover: the tiles stay as they are until the new list
  /// lands; a failure keeps them.
  Future<void> refreshQuietly() async {
    if (!state.hasValue) return;
    final scope = ref.read(accountScopeProvider);
    try {
      final businesses = await ref.read(pollsServiceProvider).businesses();
      if (ref.mounted && scope.open) state = AsyncData(businesses);
    } catch (_) {}
  }

  /// Votes [choice] on [pollId]'s question at [question].
  Future<VoteOutcome> vote(
    String pollId,
    int choice, {
    int question = 0,
  }) async {
    final scope = ref.read(accountScopeProvider);
    final Poll poll;
    try {
      poll = await ref
          .read(pollsServiceProvider)
          .vote(pollId, choice, question: question);
    } on ApiRefused catch (refusal) {
      if (unanswered(refusal)) return VoteOutcome.offline;
      if (refusal.code == 'ACCOUNT_CLOSING') return VoteOutcome.closing;
      await bring(pollId);
      return VoteOutcome.refused;
    } catch (_) {
      return VoteOutcome.offline;
    }
    if (!ref.mounted || !scope.open) return VoteOutcome.offline;
    _put(poll);
    republishSurfaces(ref).ignore();
    return VoteOutcome.counted;
  }

  /// Reads [pollId] again and puts it in the list, its business with it
  /// when the list did not have one; a poll that is gone leaves the list.
  /// Answers the business it sits under, or null when it cannot be read.
  Future<String?> bring(String pollId) async {
    final scope = ref.read(accountScopeProvider);
    try {
      final business = await ref.read(pollsServiceProvider).poll(pollId);
      if (!ref.mounted || !scope.open) return null;
      _merge(business);
      return business.id;
    } on ApiRefused catch (refusal) {
      if (refusal.status == 404 && ref.mounted && scope.open) _drop(pollId);
      return null;
    } catch (_) {
      return null;
    }
  }

  /// [business]'s polls in place of the list's own; a business the list
  /// does not have joins its end.
  void _merge(PollBusiness business) {
    final data = state.value;
    if (data == null) return;
    bool holds(PollBusiness b) =>
        b.id == business.id ||
        business.polls.any((p) => b.polls.any((q) => q.id == p.id));
    state = AsyncData([
      for (final b in data)
        holds(b) ? business.polls.fold(b, (into, p) => into.withPoll(p)) : b,
      if (!data.any(holds)) business,
    ]);
  }

  void _put(Poll poll) {
    final data = state.value;
    if (data == null) return;
    state = AsyncData([
      for (final b in data)
        b.polls.any((p) => p.id == poll.id) ? b.withPoll(poll) : b,
    ]);
  }

  void _drop(String pollId) {
    final data = state.value;
    if (data == null) return;
    state = AsyncData([
      for (final b in data)
        if (!b.polls.any((p) => p.id == pollId))
          b
        else if (b.polls.length > 1)
          b.withoutPoll(pollId),
    ]);
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

/// The poll sheet's BrandHeader line: "1 poll · 3 questions · about 15
/// seconds", five seconds a question.
String pollDetail(PollBusiness business) {
  final count = business.questionCount;
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

/// The businesses whose questions the person is walking one at a time
/// this session: from their first vote in the walk until they press Done,
/// the sheet stays on the question rather than turn to "You’re done".
class PollsWalkingNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    ref.watch(accountProvider);
    return const {};
  }

  void walk(String businessId) {
    if (!state.contains(businessId)) state = {...state, businessId};
  }

  void finish(String businessId) => state = {...state}..remove(businessId);
}

final pollsWalkingProvider =
    NotifierProvider<PollsWalkingNotifier, Set<String>>(
      PollsWalkingNotifier.new,
    );

/// "QUESTION 2 OF 3", or "LAST QUESTION" once a branch skipped one so the
/// count would mislead.
String pollStepLabel({
  required int at,
  required int count,
  required bool last,
  required bool skipped,
}) => (last && skipped ? 'Last question' : 'Question ${at + 1} of $count')
    .toUpperCase();
