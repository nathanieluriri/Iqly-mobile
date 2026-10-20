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

  /// Casts the person's vote for [choice] on [pollId]'s first question and
  /// answers with the poll as it stands after it, so the shares include it.
  Future<Poll> vote(String pollId, int choice);

  /// Answers every question [pollId] asks at once, its first included,
  /// and answers with the poll and its results (contract 14.1).
  Future<Poll> answer(String pollId, List<PollAnswer> answers);
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
  Future<Poll> vote(String pollId, int choice) =>
      answer(pollId, [(question: 0, choice: choice)]);

  @override
  Future<Poll> answer(String pollId, List<PollAnswer> answers) async {
    await _wait();
    for (final business in _businesses) {
      for (final poll in business.polls) {
        if (poll.id != pollId) continue;
        if (poll.voted || poll.closedAt(_clock())) return poll;
        var counted = poll;
        for (final (:question, :choice) in answers) {
          if (question < counted.questions.length &&
              !counted.questions[question].answered) {
            counted = counted.withVote(choice, question: question);
          }
        }
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
  LivePollsService(this.link, {this.questions = false});

  final AccountLink link;

  /// Health's `pollQuestions`: a poll's later questions are read and answered.
  final bool questions;

  @override
  Future<List<PollBusiness>> businesses() async => pollBusinessesFromJson(
    await link.fetch('/polls', AccountKeys.polls),
    questions: questions,
  );

  /// What the phone kept from the last list, without asking the API.
  Future<List<PollBusiness>> kept() async => pollBusinessesFromJson(
    await link.kept(AccountKeys.polls) ?? const {},
    questions: questions,
  );

  @override
  Future<PollBusiness> poll(String pollId) async {
    final res = await link.scope.guard(
      link.api.get('/polls/${Uri.encodeComponent(pollId)}'),
    );
    final business = res.ok
        ? pollAloneFromJson(res.data, questions: questions)
        : null;
    if (business == null) throw ApiRefused.of(res);
    return business;
  }

  @override
  Future<Poll> vote(String pollId, int choice) => _send(
    link.api.post('/polls/${Uri.encodeComponent(pollId)}/vote', {
      'choice': choice,
    }),
  );

  /// Only an API with `pollQuestions` takes the answers together; before
  /// it a poll has its one question, which goes as a vote.
  @override
  Future<Poll> answer(String pollId, List<PollAnswer> answers) async {
    if (!questions) {
      if (answers.length == 1 && answers.single.question == 0) {
        return vote(pollId, answers.single.choice);
      }
      throw const FeaturePaused(LiveFeature.pollQuestions);
    }
    return _send(
      link.api.post('/polls/${Uri.encodeComponent(pollId)}/answers', {
        'answers': [
          for (final (:question, :choice) in answers)
            {'question': question, 'choice': choice},
        ],
      }),
    );
  }

  Future<Poll> _send(Future<ApiResponse> request) async {
    final res = await link.scope.guard(request);
    final poll = res.ok ? pollFromJson(res.data, questions: questions) : null;
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

  @override
  Future<Poll> answer(String pollId, List<PollAnswer> answers) => _paused();
}

List<String> _choices(Object? json) => [
  if (json case final List<Object?> list)
    for (final choice in list)
      if (choice is String) choice,
];

List<int> _counts(Object? counted, int length) => [
  for (var i = 0; i < length; i++)
    counted is List && i < counted.length ? apiInt(counted[i]) ?? 0 : 0,
];

int? _pick(Object? json, int length) {
  final chosen = apiInt(json);
  return chosen != null && chosen >= 0 && chosen < length ? chosen : null;
}

/// A question of a `pollQuestions` poll (contract 14.1): `{index,
/// question, choices, showIf: {question, choices} | null, chosen, votes,
/// shares, total}`, `showIf.question` the index of the earlier question it
/// follows. Null when it has no question or choices.
PollQuestion? pollQuestionFromJson(Object? json) {
  if (json is! Map) return null;
  final question = apiText(json['question']);
  final choices = _choices(json['choices']);
  if (question == null || choices.isEmpty) return null;
  final branch = json['showIf'];
  final after = branch is Map ? apiInt(branch['question']) : null;
  return PollQuestion(
    question: question,
    choices: choices,
    votes: _counts(json['votes'], choices.length),
    chosen: _pick(json['chosen'], choices.length),
    showIf: branch is Map && after != null
        ? PollBranch(
            question: after,
            choices: [
              if (branch['choices'] case final List<Object?> picks)
                for (final pick in picks) ?apiInt(pick),
            ],
          )
        : null,
  );
}

/// A contract 11.1 poll, or null without an id, a question, choices or a
/// close. With [questions] (health's `pollQuestions`) up to three questions are
/// read from `questions`, whose first is the poll's own; a later question
/// that does not read, or one past the third, ends them there.
Poll? pollFromJson(Object? json, {bool questions = false}) {
  if (json is! Map) return null;
  final id = apiText(json['id']);
  final question = apiText(json['question']);
  final closesAt = apiTime(json['closesAt']);
  final choices = _choices(json['choices']);
  if (id == null || question == null || closesAt == null || choices.isEmpty) {
    return null;
  }
  final followUps = <PollQuestion>[];
  final asked = json['questions'];
  if (questions && asked is List) {
    for (final item in asked.skip(1).take(2)) {
      final next = pollQuestionFromJson(item);
      if (next == null) break;
      followUps.add(next);
    }
  }
  return Poll(
    id: id,
    question: question,
    choices: choices,
    votes: _counts(json['votes'], choices.length),
    closesAt: closesAt,
    chosen: _pick(json['chosen'], choices.length),
    closed: json['closed'] == true,
    followUps: followUps,
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
List<PollBusiness> pollBusinessesFromJson(
  Map<String, dynamic> json, {
  bool questions = false,
}) => [
  if (json['businesses'] case final List<Object?> businesses)
    for (final business in businesses)
      if (business is Map)
        ?_business(business, [
          if (business['polls'] case final List<Object?> polls)
            for (final poll in polls) ?pollFromJson(poll, questions: questions),
        ]),
];

/// `GET /polls/:id`: the poll under the business it names.
PollBusiness? pollAloneFromJson(
  Map<String, dynamic> json, {
  bool questions = false,
}) {
  final poll = pollFromJson(json, questions: questions);
  return poll == null ? null : _business(json['business'], [poll]);
}

/// The demo in a preview launch, the API while polls run live; a live
/// launch without them refuses, so no sample poll shows as the person's.
final pollsServiceProvider = Provider<PollsService>((ref) {
  ref.watch(accountProvider);
  if (ref.watch(liveModeProvider).isPreview) return DemoPollsService();
  final link = ref.watch(liveLinkProvider(LiveFeature.polls));
  return link == null
      ? const PausedPollsService()
      : LivePollsService(
          link,
          questions: ref
              .watch(liveModeProvider)
              .isLive(LiveFeature.pollQuestions),
        );
});
