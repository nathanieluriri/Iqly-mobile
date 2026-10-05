import 'demo_data.dart';

/// One poll a business runs (Exp/PollCard). Polls are a design proposal
/// behind Flags.polls: the API does not serve them yet, so every figure is
/// illustrative. [votes] counts each choice, the person's own vote included
/// once [chosen] is set.
class Poll {
  const Poll({
    required this.id,
    required this.question,
    required this.choices,
    required this.votes,
    required this.closesAt,
    this.chosen,
  });

  final String id;
  final String question;
  final List<String> choices;
  final List<int> votes;
  final DateTime closesAt;
  final int? chosen;

  bool get voted => chosen != null;

  int get total => votes.fold(0, (sum, count) => sum + count);

  bool closedAt(DateTime now) => !closesAt.isAfter(now);

  /// Whole percentages of [total] that add up to 100: each share rounds
  /// down, then the points left go to the largest remainders, so a card
  /// never reads 99% or 101%.
  List<int> get shares {
    final sum = total;
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

  /// This poll with the person's vote for [choice] counted.
  Poll withVote(int choice) => Poll(
    id: id,
    question: question,
    choices: choices,
    votes: [
      for (var i = 0; i < votes.length; i++) votes[i] + (i == choice ? 1 : 0),
    ],
    closesAt: closesAt,
    chosen: choice,
  );
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

  int get answered => polls.where((p) => p.voted).length;

  int get unanswered => polls.length - answered;

  bool get allAnswered => unanswered == 0;

  /// The soonest close among the polls, when the first results land.
  DateTime get firstClose =>
      polls.map((p) => p.closesAt).reduce((a, b) => a.isBefore(b) ? a : b);

  PollBusiness withPoll(Poll poll) => PollBusiness(
    id: id,
    name: name,
    polls: [for (final p in polls) p.id == poll.id ? poll : p],
    logo: logo,
    cover: cover,
    banner: banner,
  );
}

/// The B2 polls at [now]. Orchid Foods' two polls are the Figma frames
/// (33:169, 33:289); the flavour poll's counts give the row note's
/// 45 / 33 / 22 of 214 once the person votes Zobo and ginger. The Unibooks and
/// Sunline questions are their Figma tiles'; their choices are written for
/// the demo. Orchid Foods has 2 open and unanswered,
/// Unibooks 1, Sunline 1 answered.
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
      ),
      Poll(
        id: 'p2',
        question: 'Which can size should the first run use?',
        choices: const ['33cl slim can', '50cl can', '1 litre bottle'],
        votes: const [84, 73, 40],
        closesAt: now.add(const Duration(days: 5)),
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
