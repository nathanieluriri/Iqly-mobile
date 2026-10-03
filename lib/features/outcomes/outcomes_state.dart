import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/money.dart';
import '../../data/models.dart';
import '../../data/outcomes_data.dart';
import '../../data/outcomes_service.dart';
import '../../data/repository.dart';
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

/// A note's time as 193:9681 writes it: "FRI, 11:20 AM" within the week,
/// the date before that.
String noteTime(DateTime at, DateTime now) {
  final pattern = now.difference(at).inDays < 7
      ? 'EEE, h:mm a'
      : 'd MMM, h:mm a';
  return DateFormat(pattern).format(at).toUpperCase();
}

/// A decided submission and how it placed: My submissions' row (the
/// submission, its brief and the ledger award), the outcome the business
/// published, the contributor's name for the share card and, for an entry
/// not picked, the brief to try next.
class ResultData {
  const ResultData({
    required this.item,
    required this.outcome,
    required this.name,
    this.next,
  });

  final SubmissionItem item;
  final Outcome? outcome;
  final String name;
  final Brief? next;

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

  /// The award as a reward: no decimals.
  String get amount {
    final award = item.awardKobo;
    return award == null ? '' : naira(award, decimals: false);
  }

  String get shareName => 'iqly-win-${item.id}.png';
}

final resultProvider = FutureProvider.autoDispose.family<ResultData?, String>(
  retry: (_, _) => null,
  (ref, id) async {
    final item = await ref.watch(submissionItemProvider(id).future);
    if (item == null || item.underReview) return null;
    final (outcome, user) = await (
      ref.watch(outcomesServiceProvider).outcome(id),
      ref.watch(onboardingUserProvider.future),
    ).wait;
    Brief? next;
    if (item.status == SubmissionStatus.filteredOut) {
      next = await _nextBrief(ref, item);
    }
    return ResultData(
      item: item,
      outcome: outcome,
      name: user.name,
      next: next,
    );
  },
);

/// A live brief not answered yet, the same business first (193:9681 offers
/// Harbour's other brief), then the soonest to close.
Future<Brief?> _nextBrief(Ref ref, SubmissionItem item) async {
  final (briefs, mine) = await (
    ref.watch(repositoryProvider).briefs(),
    ref.watch(mySubmissionsProvider.future),
  ).wait;
  final answered = {for (final i in mine.items) i.submission.briefId};
  final business = item.brief?.businessName;
  final open = [
    for (final b in briefs)
      if (b.isLive && !answered.contains(b.id)) b,
  ];
  int rank(Brief b) => b.businessName == business ? 0 : 1;
  open.sort((a, b) {
    final byBusiness = rank(a).compareTo(rank(b));
    if (byBusiness != 0) return byBusiness;
    final ad = a.deadline, bd = b.deadline;
    if (ad == null || bd == null) return ad == null ? 1 : -1;
    return ad.compareTo(bd);
  });
  return open.firstOrNull;
}

sealed class BoardItem {
  const BoardItem();
}

class BoardRow extends BoardItem {
  const BoardRow(this.entry, {this.you = false});

  final LeaderboardEntry entry;
  final bool you;
}

/// The line under the paid places: the pool they split.
class BoardCutoff extends BoardItem {
  const BoardCutoff(this.poolKobo);

  final int poolKobo;

  String get label => '${rewardPool(poolKobo)} split'.toUpperCase();
}

/// Ranks skipped between two rows ("· · ·").
class BoardGap extends BoardItem {
  const BoardGap();
}

/// The board as B13 draws it (193:9779, 225:10747): the paid places with
/// the contributor's own row among them when it was paid, the cutoff line
/// with the brief's pool, then the rows below it, with a gap where ranks
/// are skipped. The contributor's row carries their own entry and award.
class Leaderboard {
  const Leaderboard({
    required this.brief,
    required this.paid,
    required this.entries,
    required this.items,
  });

  final Brief brief;
  final int paid;
  final int entries;
  final List<BoardItem> items;

  String get title => 'Top $paid of $entries entries';

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
    final rows = [for (final l in outcome.leaders) BoardRow(l), you]
      ..sort((a, b) => a.entry.rank.compareTo(b.entry.rank));
    final paid = [
      for (final r in rows)
        if (r.entry.amountKobo != null) r,
    ];
    final items = <BoardItem>[...paid, BoardCutoff(brief.rewardPoolKobo)];
    var last = paid.isEmpty ? 0 : paid.last.entry.rank;
    for (final row in rows) {
      if (row.entry.amountKobo != null) continue;
      if (row.entry.rank > last + 1) items.add(const BoardGap());
      items.add(row);
      last = row.entry.rank;
    }
    return Leaderboard(
      brief: brief,
      paid: paid.length,
      entries: entries,
      items: items,
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
