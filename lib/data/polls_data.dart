import 'demo_data.dart';

/// Shares of [votes] in whole percentages that add up to 100: each share
/// rounds down, then the points left go to the largest remainders, the
/// earlier choice first on a tie, so a card never reads 99% or 101%.
List<int> wholeShares(List<int> votes) {
  final sum = votes.fold(0, (a, b) => a + b);
  if (sum == 0) return [for (final _ in votes) 0];
  final exact = [for (final count in votes) count * 100 / sum];
  final whole = [for (final share in exact) share.floor()];
  var left = 100 - whole.fold(0, (a, b) => a + b);
  final byRemainder = [for (var i = 0; i < votes.length; i++) i]
    ..sort((a, b) {
      final order = (exact[b] - whole[b]).compareTo(exact[a] - whole[a]);
      return order != 0 ? order : a.compareTo(b);
    });
  for (final i in byRemainder) {
    if (left == 0) break;
    whole[i]++;
    left--;
  }
  return whole;
}

/// One answer of `POST /polls/:id/answers` (contract 14.1).
typedef PollAnswer = ({int question, int choice});

/// When a later question shows: only after one of [choices] was picked on
/// the question at [question] (its index in the poll).
class PollBranch {
  const PollBranch({required this.question, required this.choices});

  final int question;
  final List<int> choices;
}

/// One question of a poll: its choices, the counts (zeros until the person
/// has answered or the poll has closed), the person's pick, and the branch
/// it shows on, if any.
class PollQuestion {
  const PollQuestion({
    required this.question,
    required this.choices,
    required this.votes,
    this.chosen,
    this.showIf,
  });

  final String question;
  final List<String> choices;
  final List<int> votes;
  final int? chosen;
  final PollBranch? showIf;

  bool get answered => chosen != null;

  int get total => votes.fold(0, (sum, count) => sum + count);

  List<int> get shares => wholeShares(votes);

  PollQuestion withVote(int choice) => PollQuestion(
    question: question,
    choices: choices,
    votes: [
      for (var i = 0; i < votes.length; i++) votes[i] + (i == choice ? 1 : 0),
    ],
    chosen: choice,
    showIf: showIf,
  );
}

/// One poll a business runs (Exp/PollCard), behind Flags.polls: the
/// preview's illustrative figures, or the API's (contract 11.1). The poll's
/// own [question] is its first; [followUps] are the second and third a
/// poll can ask (health's `pollQuestions`), each perhaps shown only after some
/// answers to an earlier one. [votes] counts each choice, the person's own
/// vote included once [chosen] is set; the API sends no counts until the
/// person has voted or the poll has closed, so they read as zeros until then.
class Poll {
  const Poll({
    required this.id,
    required this.question,
    required this.choices,
    required this.votes,
    required this.closesAt,
    this.chosen,
    this.closed = false,
    this.followUps = const [],
  });

  final String id;
  final String question;
  final List<String> choices;
  final List<int> votes;
  final DateTime closesAt;
  final int? chosen;

  /// The API says it has closed, whatever this phone's clock says.
  final bool closed;
  final List<PollQuestion> followUps;

  /// Every question, the first included.
  List<PollQuestion> get questions => [
    PollQuestion(
      question: question,
      choices: choices,
      votes: votes,
      chosen: chosen,
    ),
    ...followUps,
  ];

  /// Whether the question at [index] is asked, from the answers so far: a
  /// branched one only once its earlier question was answered one of the
  /// ways it names.
  bool asks(int index) {
    final all = questions;
    final branch = all[index].showIf;
    if (branch == null) return true;
    if (branch.question < 0 || branch.question >= index) return false;
    if (!asks(branch.question)) return false;
    final picked = all[branch.question].chosen;
    return picked != null && branch.choices.contains(picked);
  }

  /// Whether the question at [index] is not asked whatever comes: its
  /// earlier question was answered another way.
  bool skips(int index) {
    final branch = questions[index].showIf;
    if (branch == null) return false;
    if (branch.question < 0 || branch.question >= index) return true;
    if (skips(branch.question)) return true;
    final picked = questions[branch.question].chosen;
    return picked != null && !branch.choices.contains(picked);
  }

  /// The questions asked and answered.
  int get answered => [
    for (var i = 0; i < questions.length; i++)
      if (asks(i) && questions[i].answered) i,
  ].length;

  /// Every question it asks is answered.
  bool get voted {
    final all = questions;
    for (var i = 0; i < all.length; i++) {
      if (!all[i].answered && !skips(i)) return false;
    }
    return true;
  }

  int get total => votes.fold(0, (sum, count) => sum + count);

  bool closedAt(DateTime now) => closed || !closesAt.isAfter(now);

  List<int> get shares => wholeShares(votes);

  /// This poll with [choice] picked on its question at [question], not yet
  /// sent, so nothing is counted: the walk's answers before Done.
  Poll withPick(int choice, {int question = 0}) => Poll(
    id: id,
    question: this.question,
    choices: choices,
    votes: votes,
    closesAt: closesAt,
    chosen: question == 0 ? choice : chosen,
    closed: closed,
    followUps: [
      for (final (i, q) in followUps.indexed)
        i + 1 == question
            ? PollQuestion(
                question: q.question,
                choices: q.choices,
                votes: q.votes,
                chosen: choice,
                showIf: q.showIf,
              )
            : q,
    ],
  );

  /// The answers to send: each question asked, with its pick.
  List<PollAnswer> get answers => [
    for (var i = 0; i < questions.length; i++)
      if (asks(i) && questions[i].chosen != null)
        (question: i, choice: questions[i].chosen!),
  ];

  /// This poll with the person's vote for [choice] on its question at
  /// [question] counted.
  Poll withVote(int choice, {int question = 0}) {
    final first = question == 0 ? questions.first.withVote(choice) : null;
    return Poll(
      id: id,
      question: this.question,
      choices: choices,
      votes: first?.votes ?? votes,
      closesAt: closesAt,
      chosen: first?.chosen ?? chosen,
      closed: closed,
      followUps: [
        for (final (i, q) in followUps.indexed)
          i + 1 == question ? q.withVote(choice) : q,
      ],
    );
  }
}

/// A business with open polls: one Discover bubble, one row on Polls, one
/// sheet.
class PollBusiness {
  const PollBusiness({
    required this.id,
    required this.name,
    required this.polls,
    this.logo,
    this.cover,
    this.banner,
  });

  final String id;
  final String name;
  final List<Poll> polls;

  /// The business art (asset paths in the demo, URLs from the API): the
  /// logo, the tile's photo and the poll sheet's header photo.
  final String? logo;
  final String? cover;
  final String? banner;

  /// The first question, which the business's tile shows.
  String get headline => polls.first.question;

  String get initial => name.substring(0, 1);

  /// The questions answered, across its polls.
  int get answered => polls.fold(0, (sum, p) => sum + p.answered);

  /// Every question its polls can ask, the ones a branch may skip included.
  int get questionCount => polls.fold(0, (sum, p) => sum + p.questions.length);

  /// The polls still to finish.
  int get unanswered => polls.where((p) => !p.voted).length;

  bool get allAnswered => unanswered == 0;

  /// One of its polls asks more than one question: the sheet walks the
  /// questions one at a time.
  bool get stepped => polls.any((p) => p.followUps.isNotEmpty);

  /// The soonest close among the polls, when the first results land.
  DateTime get firstClose =>
      polls.map((p) => p.closesAt).reduce((a, b) => a.isBefore(b) ? a : b);

  PollBusiness withPoll(Poll poll) => PollBusiness(
    id: id,
    name: name,
    polls: polls.any((p) => p.id == poll.id)
        ? [for (final p in polls) p.id == poll.id ? poll : p]
        : [...polls, poll],
    logo: logo,
    cover: cover,
    banner: banner,
  );

  /// This business with [poll] alone, as one poll's detail names it.
  PollBusiness only(Poll poll) => PollBusiness(
    id: id,
    name: name,
    polls: [poll],
    logo: logo,
    cover: cover,
    banner: banner,
  );

  PollBusiness withoutPoll(String pollId) => PollBusiness(
    id: id,
    name: name,
    polls: [
      for (final p in polls)
        if (p.id != pollId) p,
    ],
    logo: logo,
    cover: cover,
    banner: banner,
  );
}

/// The B2 polls at [now]. Orchid Foods asks one poll of three questions
/// (1600:33055 to 1600:34175): the flavour, then how much ginger only after
/// Zobo and ginger, then the can size. Its counts give 45 / 33 / 22 of 214
/// once the person votes Zobo and ginger, and 26 / 48 / 26 of 96 for A
/// little. The Unibooks and Sunline questions are their Figma tiles'; their
/// choices are written for the demo. Orchid Foods and Unibooks are open and
/// unanswered, Sunline answered.
List<PollBusiness> demoPolls(DateTime now) => [
  PollBusiness(
    id: 'orchid-foods',
    name: 'Orchid Foods',
    logo: DemoData.logoOf('orchid-foods'),
    cover: DemoData.coverOf('orchid-foods'),
    banner: DemoData.coverOf('orchid-foods', 2),
    polls: [
      Poll(
        id: 'p1',
        question: 'Which flavour should we launch first?',
        choices: const ['Zobo and ginger', 'Tiger nut', 'Pineapple and mint'],
        votes: const [95, 71, 47],
        closesAt: now.add(const Duration(days: 2)),
        followUps: const [
          PollQuestion(
            question: 'How much ginger should it have?',
            choices: ['A little', 'Medium', 'A lot'],
            votes: [24, 46, 25],
            showIf: PollBranch(question: 0, choices: [0]),
          ),
          PollQuestion(
            question: 'Which can size should the first run use?',
            choices: ['33cl slim can', '50cl can', '1 litre bottle'],
            votes: [84, 73, 40],
          ),
        ],
      ),
    ],
  ),
  PollBusiness(
    id: 'unibooks',
    name: 'Unibooks',
    logo: DemoData.logoOf('unibooks'),
    cover: DemoData.coverOf('unibooks'),
    banner: DemoData.coverOf('unibooks', 2),
    polls: [
      Poll(
        id: 'p3',
        question: 'Where do you buy your course books?',
        choices: const ['Campus bookshop', 'WhatsApp sellers', 'Online'],
        votes: const [61, 24, 12],
        closesAt: now.add(const Duration(days: 4)),
      ),
    ],
  ),
  PollBusiness(
    id: 'sunline',
    name: 'Sunline',
    logo: DemoData.logoOf('sunline'),
    cover: DemoData.coverOf('sunline'),
    banner: DemoData.coverOf('sunline', 2),
    polls: [
      Poll(
        id: 'p4',
        question: 'When should a kiosk open in the morning?',
        choices: const ['6 am', '7 am', '8 am'],
        votes: const [58, 81, 37],
        closesAt: now.add(const Duration(days: 1)),
        chosen: 1,
      ),
    ],
  ),
];
