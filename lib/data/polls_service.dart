import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session.dart';
import 'polls_data.dart';

/// Polls (Flags.polls). The API does not serve them yet; the demo answers
/// with the B2 figures after a short delay and keeps the person's votes
/// for as long as the app runs.
abstract class PollsService {
  /// The businesses with open polls, the person's own votes marked.
  Future<List<PollBusiness>> businesses();

  /// Casts the person's vote for [choice] on [pollId] and answers with the
  /// poll as it stands after it, so the shares include it.
  Future<Poll> vote(String pollId, int choice);
}

class DemoPollsService implements PollsService {
  DemoPollsService({
    this.delay = const Duration(milliseconds: 400),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration delay;
  final DateTime Function() _clock;

  late List<PollBusiness> _businesses = demoPolls(_clock());

  Future<void> _wait() =>
      delay == Duration.zero ? Future.value() : Future<void>.delayed(delay);

  @override
  Future<List<PollBusiness>> businesses() async => [
    for (final business in _businesses)
      if (business.polls.any((p) => !p.closedAt(_clock()))) business,
  ];

  @override
  Future<Poll> vote(String pollId, int choice) async {
    await _wait();
    for (final business in _businesses) {
      for (final poll in business.polls) {
        if (poll.id != pollId) continue;
        if (poll.voted || poll.closedAt(_clock())) return poll;
        final counted = poll.withVote(choice);
        _businesses = [
          for (final b in _businesses) b == business ? b.withPoll(counted) : b,
        ];
        return counted;
      }
    }
    throw StateError('No poll $pollId');
  }
}

final pollsServiceProvider = Provider<PollsService>((ref) {
  ref.watch(accountProvider);
  return DemoPollsService();
});
