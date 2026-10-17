import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/money.dart';
import '../../data/models.dart';
import '../../data/outcomes_data.dart';
import '../../data/outcomes_service.dart';
import '../onboarding/onboarding_draft.dart';
import '../submissions/submissions_state.dart';

/// "5th", "9th", "21st".
String ordinal(int n) {
  final teen = n % 100 >= 11 && n % 100 <= 13;
  final suffix = teen
      ? 'th'
      : switch (n % 10) {
          1 => 'st',
          2 => 'nd',
          3 => 'rd',
          _ => 'th',
        };
  return '$n$suffix';
}

/// A note's time as 193:9681 writes it: "Fri, 11:20 am" within the week,
/// the date before that.
String noteTime(DateTime at, DateTime now) {
  final pattern = now.difference(at).inDays < 7
      ? 'EEE, h:mm a'
      : 'd MMM, h:mm a';
  return DateFormat(pattern)
      .format(at)
      .replaceAll('AM', 'am')
      .replaceAll('PM', 'pm');
}

/// A decided submission and how it placed: My submissions' row (the
/// submission, its brief and the ledger award), the outcome the business
/// published, the contributor's name for the share card and, for an entry
/// not picked, the briefs to try next.
class ResultData {
  const ResultData({
    required this.item,
    required this.outcome,
    required this.name,
    this.next = const [],
  });

  final SubmissionItem item;
  final Outcome? outcome;
  final String name;
  final List<Brief> next;

  bool get winner => item.status == SubmissionStatus.winner;

  /// "Winner · 5th of 48", or the business while no board is out (the
  /// ShareCard default "WINNER · ORCHID FOODS").
  String get shareEyebrow {
    final placing = this.placing;
    if (placing != null) return 'Winner · $placing';
    final business = item.brief?.businessName;
    return business == null ? 'Winner' : 'Winner · $business';
  }

  /// "9th of 36".
  String? get placing {
    final rank = outcome?.rank;
    final entries = outcome?.entries;
    if (rank == null || entries == null) return null;
    return '${ordinal(rank)} of $entries';
  }

  /// The award as the ledger paid it, two decimals (193:9573).
  String get amount {
    final award = item.awardKobo;
    return award == null ? '' : naira(award);
  }

  String get shareName => 'iqly-win-${item.id}.png';
}

final resultProvider = FutureProvider.autoDispose.family<ResultData?, String>(
  retry: (_, _) => null,
  (ref, id) async {
    // Asked together, so a network that does not answer holds the page for
    // one wait on the phone's copies, not one per read.
    final outcomeRead = ref.watch(outcomesServiceProvider).outcome(id)
      ..ignore();
    final userRead = ref.watch(onboardingUserProvider.future)..ignore();
    final item = await ref.watch(submissionItemProvider(id).future);
    if (item == null) throw SubmissionUnavailable(id);
    if (item.underReview) return null;
    final (outcome, user) = await (outcomeRead, userRead).wait;
    var next = const <Brief>[];
    if (item.status == SubmissionStatus.filteredOut) {
      next = await _nextBriefs(ref, item);
    }
    return ResultData(
      item: item,
      outcome: outcome,
      name: user.name,
      next: next,
    );
  },
);

/// The Briefs under a result not picked (193:9681): four open briefs from
/// other businesses, soonest to close first.
Future<List<Brief>> _nextBriefs(Ref ref, SubmissionItem item) async {
  final open = await openBriefs(ref);
  final business = item.brief?.businessName;
  return open.where((b) => b.businessName != business).take(4).toList();
}

class BoardRow {
  const BoardRow(this.entry, {this.you = false});

  final LeaderboardEntry entry;
  final bool you;
}

/// The board as B13 draws it (193:9779, 225:10747; designer doc rev 57):
/// the top three on the podium, then every other rank from fourth down in
/// one list, the contributor's own row in place. Only paid ranks show an
/// amount.
class Leaderboard {
  const Leaderboard({
    required this.brief,
    required this.entries,
    required this.podium,
    required this.rows,
    required this.eyebrow,
  });

  final Brief brief;

  /// The brief's title over a win (193:9779), your entry's over a result
  /// not picked (225:10747), as the frames write them.
  final String eyebrow;
  final int entries;

  /// First, second and third.
  final List<BoardRow> podium;

  /// Fourth down, in rank order.
  final List<BoardRow> rows;

  String get title => '$entries submissions, ranked';

  static Leaderboard? of(ResultData data) {
    final outcome = data.outcome;
    final brief = data.item.brief;
    final rank = outcome?.rank;
    final entries = outcome?.entries;
    if (outcome == null || brief == null || rank == null || entries == null) {
      return null;
    }
    final you = BoardRow(
      LeaderboardEntry(
        rank: rank,
        name: 'You',
        entry: data.item.submission.title,
        amountKobo: data.winner ? data.item.awardKobo : null,
      ),
      you: true,
    );
    final ranked = [for (final l in outcome.leaders) BoardRow(l), you]
      ..sort((a, b) => a.entry.rank.compareTo(b.entry.rank));
    return Leaderboard(
      brief: brief,
      entries: entries,
      podium: ranked.take(3).toList(),
      rows: ranked.skip(3).toList(),
      eyebrow: data.winner ? brief.title : data.item.submission.title,
    );
  }
}

/// True the first time the Winner result shows for [id] on this device: the
/// success haptic plays once (MOTION-SPEC §2.7, "Winner result first seen").
bool firstCelebration(SharedPreferences prefs, String id) {
  const key = 'outcomes.celebrated';
  final seen = prefs.getStringList(key) ?? const [];
  if (seen.contains(id)) return false;
  prefs.setStringList(key, [...seen, id]);
  return true;
}
