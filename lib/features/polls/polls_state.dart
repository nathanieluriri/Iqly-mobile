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

  /// The poll is closed, so it takes no more answers.
  closed,

  /// The person has used every change.
  recorded,
}

/// The businesses with open polls and the person's votes, shared by the
/// Polls screens and Discover's bubbles. No automatic retry: the failed
/// state offers "Try again". An answer that lands once its account is no
/// longer signed in changes nothing.
class PollsNotifier extends AsyncNotifier<List<PollBusiness>> {
  @override
  Future<List<PollBusiness>> build() async {
    final service = ref.watch(pollsServiceProvider);
    final kept = await service.kept();
    if (kept.isNotEmpty) {
      Future<void>.delayed(Duration.zero, _reload);
      return kept;
    }
    return service.businesses();
  }

  void retry() => ref.invalidateSelf();

  /// A return to Discover, a pull, or a push: the tiles stay as they are
  /// until the new list lands; a failure keeps them. Asks the API so a
  /// poll the person was just told about is not hidden by the kept copy.
  Future<void> refreshQuietly() => _reload();

  Future<void> _reload() async {
    if (!state.hasValue) return;
    final scope = ref.read(accountScopeProvider);
    try {
      final businesses = await ref
          .read(pollsServiceProvider)
          .businesses(fresh: true);
      if (ref.mounted && scope.open) state = AsyncData(businesses);
    } catch (_) {}
  }

  /// Instantly shows [poll] on the card, before the API answers.
  void show(Poll poll) => _put(poll);

  /// Votes [choice] on [pollId]'s one question.
  Future<VoteOutcome> vote(
    String pollId,
    int choice, {
    bool Function()? apply,
  }) => _counting(
    pollId,
    ref.read(pollsServiceProvider).vote(pollId, choice),
    apply: apply,
  );

  /// Sends the walk's [answers] to [pollId] together (contract 14.1).
  Future<VoteOutcome> answer(String pollId, List<PollAnswer> answers) =>
      _counting(pollId, ref.read(pollsServiceProvider).answer(pollId, answers));

  Future<VoteOutcome> _counting(
    String pollId,
    Future<Poll> sent, {
    bool Function()? apply,
  }) async {
    final scope = ref.read(accountScopeProvider);
    final Poll poll;
    try {
      poll = await sent;
    } on ApiRefused catch (refusal) {
      if (unanswered(refusal)) return VoteOutcome.offline;
      if (refusal.code == 'ACCOUNT_CLOSING') return VoteOutcome.closing;
      if (refusal.code == 'POLL_CLOSED') return VoteOutcome.closed;
      if (refusal.code == 'POLL_CHANGE_LIMIT') return VoteOutcome.recorded;
      await bring(pollId);
      return VoteOutcome.refused;
    } catch (_) {
      return VoteOutcome.offline;
    }
    if (!ref.mounted || !scope.open) return VoteOutcome.offline;
    if (apply == null || apply()) _put(poll);
    ref.invalidate(pollHistoryProvider);
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

List<PollBusiness> mergePollBusinesses(
  List<PollBusiness> first,
  List<PollBusiness> second,
) {
  final businesses = <String, PollBusiness>{for (final b in first) b.id: b};
  for (final business in second) {
    var merged = businesses[business.id];
    if (merged == null) {
      businesses[business.id] = business;
      continue;
    }
    for (final poll in business.polls) {
      final previous = merged!.polls.where((p) => p.id == poll.id).firstOrNull;
      if (previous?.voted == true && !poll.voted) continue;
      merged = merged.withPoll(poll);
    }
    businesses[business.id] = merged!;
  }
  return businesses.values.toList();
}

List<PollBusiness> pollTiles(
  List<PollBusiness> businesses, {
  required bool completed,
  required DateTime now,
}) => [
  for (final business in businesses)
    for (final poll in business.polls)
      if (completed
          ? poll.voted && !poll.changeableAt(now)
          : poll.changeableAt(now))
        business.only(poll),
];

class PollHistoryNotifier extends AsyncNotifier<PollHistoryPage> {
  @override
  Future<PollHistoryPage> build() async {
    final account = ref.watch(accountProvider);
    final scope = ref.watch(accountScopeProvider);
    final page = await scope.guard(ref.watch(pollsServiceProvider).history());
    return PollHistoryPage(
      businesses: page.businesses,
      nextCursor: page.nextCursor,
      account: account,
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    final cursor = current?.nextCursor;
    if (current == null || cursor == null || current.loadingMore) return;
    final scope = ref.read(accountScopeProvider);
    final loading = PollHistoryPage(
      businesses: current.businesses,
      nextCursor: cursor,
      loadingMore: true,
      account: current.account,
    );
    state = AsyncData(loading);
    try {
      final next = await ref.read(pollsServiceProvider).history(cursor: cursor);
      if (!ref.mounted || !scope.open || !identical(state.value, loading)) {
        return;
      }
      if (next.nextCursor == cursor) throw StateError('Repeated poll cursor');
      state = AsyncData(
        PollHistoryPage(
          businesses: mergePollBusinesses(current.businesses, next.businesses),
          nextCursor: next.nextCursor,
          account: current.account,
        ),
      );
    } on Object {
      if (!ref.mounted || !scope.open || !identical(state.value, loading)) {
        return;
      }
      state = AsyncData(
        PollHistoryPage(
          businesses: current.businesses,
          nextCursor: cursor,
          loadMoreFailed: true,
          account: current.account,
        ),
      );
    }
  }
}

final pollHistoryProvider =
    AsyncNotifierProvider<PollHistoryNotifier, PollHistoryPage>(
      PollHistoryNotifier.new,
      retry: (_, _) => null,
    );

PollHistoryPage? pollHistoryFor(
  AsyncValue<PollHistoryPage>? history,
  String? account,
) {
  final page = history?.value;
  return page?.account == account ? page : null;
}

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

const openPollNote = 'Your answers are valuable. Please answer honestly.';

/// Share of the person's first answered question, under the brand name.
String pollDoneDetail(PollBusiness business) {
  for (final poll in business.polls) {
    for (var i = 0; i < poll.questions.length; i++) {
      final question = poll.questions[i];
      final chosen = question.chosen;
      if (!poll.asks(i) || chosen == null) continue;
      return '${question.shares[chosen]}% chose the same as you.';
    }
  }
  return 'Thank you for answering honestly.';
}

enum PollListSort {
  closing,
  latest,
  votes;

  String get label => switch (this) {
    closing => 'Closing soonest',
    latest => 'Closing latest',
    votes => 'Most votes',
  };
}

List<PollBusiness> sortPollTiles(
  List<PollBusiness> businesses,
  PollListSort sort,
) {
  final tiles = [...businesses];
  tiles.sort((a, b) {
    final left = a.polls.single;
    final right = b.polls.single;
    return switch (sort) {
      PollListSort.votes => right.total.compareTo(left.total),
      PollListSort.latest => right.closesAt.compareTo(left.closesAt),
      PollListSort.closing => left.closesAt.compareTo(right.closesAt),
    };
  });
  return tiles;
}

bool pollClosingSoon(Poll poll, DateTime now) {
  final left = poll.closesAt.difference(now);
  return !left.isNegative && left < const Duration(days: 2);
}

/// Whether every poll the business runs has closed: its tile dims and
/// stops taking taps (480:22779).
bool pollsClosed(PollBusiness business, DateTime now) =>
    business.polls.every((p) => p.closedAt(now));

/// "QUESTION 2 OF 3", or "LAST QUESTION" once a branch skipped one so the
/// count would mislead.
String pollStepLabel({
  required int at,
  required int count,
  required bool last,
  required bool skipped,
}) => (last && skipped ? 'Last question' : 'Question ${at + 1} of $count')
    .toUpperCase();
