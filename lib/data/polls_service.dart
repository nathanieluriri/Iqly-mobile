import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/backend.dart';
import '../core/session.dart';
import 'api_client.dart';
import 'live/live_account.dart';
import 'live/live_repository.dart' show liveModeProvider;
import 'polls_data.dart';

/// Polls (Flags.polls): the demo answers with the B2 figures after a short
/// delay and keeps the person's votes for as long as the app runs; a live
/// launch reads and votes on the API (contract 11.1).
abstract class PollsService {
  /// The businesses with open polls, the person's own votes marked.
  Future<List<PollBusiness>> businesses();

  /// One poll the person may see, under its business with that poll alone.
  Future<PollBusiness> poll(String pollId);

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
  Future<PollBusiness> poll(String pollId) async {
    for (final business in _businesses) {
      for (final poll in business.polls) {
        if (poll.id == pollId) return business.only(poll);
      }
    }
    throw StateError('No poll $pollId');
  }

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

/// Polls on the API. The list is kept for a read without a connection; a
/// vote goes online only, since its answer is the results to show. A
/// refusal throws [ApiRefused] with the API's code.
class LivePollsService implements PollsService {
  LivePollsService(this.link);

  final AccountLink link;

  @override
  Future<List<PollBusiness>> businesses() async =>
      pollBusinessesFromJson(await link.fetch('/polls', AccountKeys.polls));

  /// What the phone kept from the last list, without asking the API.
  Future<List<PollBusiness>> kept() async =>
      pollBusinessesFromJson(await link.kept(AccountKeys.polls) ?? const {});

  @override
  Future<PollBusiness> poll(String pollId) async {
    final res = await link.scope.guard(
      link.api.get('/polls/${Uri.encodeComponent(pollId)}'),
    );
    final business = res.ok ? pollAloneFromJson(res.data) : null;
    if (business == null) throw ApiRefused.of(res);
    return business;
  }

  @override
  Future<Poll> vote(String pollId, int choice) async {
    final res = await link.scope.guard(
      link.api.post('/polls/${Uri.encodeComponent(pollId)}/vote', {
        'choice': choice,
      }),
    );
    final poll = res.ok ? pollFromJson(res.data) : null;
    if (poll == null) throw ApiRefused.of(res);
    return poll;
  }
}

/// Polls a live launch does not run: reads fail, no vote is sent.
class PausedPollsService implements PollsService {
  const PausedPollsService();

  static Future<Never> _paused() =>
      Future.error(const FeaturePaused(LiveFeature.polls));

  @override
  Future<List<PollBusiness>> businesses() => _paused();

  @override
  Future<PollBusiness> poll(String pollId) => _paused();

  @override
  Future<Poll> vote(String pollId, int choice) => _paused();
}

/// A contract 11.1 poll, or null without an id, a question, choices or a
/// close.
Poll? pollFromJson(Object? json) {
  if (json is! Map) return null;
  final id = apiText(json['id']);
  final question = apiText(json['question']);
  final closesAt = apiTime(json['closesAt']);
  final choices = [
    if (json['choices'] case final List<Object?> list)
      for (final choice in list)
        if (choice is String) choice,
  ];
  if (id == null || question == null || closesAt == null || choices.isEmpty) {
    return null;
  }
  final counted = json['votes'];
  final votes = [
    for (var i = 0; i < choices.length; i++)
      counted is List && i < counted.length ? apiInt(counted[i]) ?? 0 : 0,
  ];
  final chosen = apiInt(json['chosen']);
  return Poll(
    id: id,
    question: question,
    choices: choices,
    votes: votes,
    closesAt: closesAt,
    chosen: chosen != null && chosen >= 0 && chosen < choices.length
        ? chosen
        : null,
    closed: json['closed'] == true,
  );
}

PollBusiness? _business(Object? json, List<Poll> polls) {
  if (json is! Map) return null;
  final id = apiText(json['id']);
  final name = apiText(json['name']);
  if (id == null || name == null || polls.isEmpty) return null;
  return PollBusiness(
    id: id,
    name: name,
    polls: polls,
    logo: apiText(json['logoUrl']),
    cover: apiText(json['coverUrl']),
    banner: apiText(json['bannerUrl']),
  );
}

/// `GET /polls`, in the API's order.
List<PollBusiness> pollBusinessesFromJson(Map<String, dynamic> json) => [
  if (json['businesses'] case final List<Object?> businesses)
    for (final business in businesses)
      if (business is Map)
        ?_business(business, [
          if (business['polls'] case final List<Object?> polls)
            for (final poll in polls) ?pollFromJson(poll),
        ]),
];

/// `GET /polls/:id`: the poll under the business it names.
PollBusiness? pollAloneFromJson(Map<String, dynamic> json) {
  final poll = pollFromJson(json);
  return poll == null ? null : _business(json['business'], [poll]);
}

/// The demo in a preview launch, the API while polls run live; a live
/// launch without them refuses, so no sample poll shows as the person's.
final pollsServiceProvider = Provider<PollsService>((ref) {
  ref.watch(accountProvider);
  if (ref.watch(liveModeProvider).isPreview) return DemoPollsService();
  final link = ref.watch(liveLinkProvider(LiveFeature.polls));
  return link == null ? const PausedPollsService() : LivePollsService(link);
});
