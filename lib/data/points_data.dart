/// One contributor on the iQL points leaderboard: rank, name ("Anonymous"
/// when they hide it), points, wins and submissions this month.
class PointsEntry {
  const PointsEntry({
    required this.rank,
    required this.name,
    required this.points,
    required this.wins,
    required this.submissions,
    this.you = false,
  });

  final int rank;
  final String name;
  final int points;
  final int wins;
  final int submissions;
  final bool you;
}

/// The general leaderboard (548:25018): every contributor ranked by iQL
/// points for [month]. [entries] is the page the source returns, ranked;
/// [contributors] counts everyone on the board.
class PointsBoard {
  const PointsBoard({
    required this.month,
    required this.contributors,
    required this.entries,
  });

  final DateTime month;
  final int contributors;
  final List<PointsEntry> entries;

  PointsEntry? get you {
    for (final e in entries) {
      if (e.you) return e;
    }
    return null;
  }
}

/// The sample board from 548:25018, October, the contributor 7th of 2,130
/// with the pass's points, wins and submissions. The points mechanics are
/// illustrative until the API has them.
///
/// Doc over Figma: row 10's subline reads "8 submissions · 40 polls" in
/// the frame; the doc sets wins · submissions on every row.
abstract final class PointsDemo {
  static const contributors = 2130;

  static PointsBoard of(
    DateTime now, {
    required int points,
    required int wins,
    required int submissions,
  }) => PointsBoard(
    month: DateTime(now.year, now.month),
    contributors: contributors,
    entries: [
      const PointsEntry(
        rank: 1,
        name: 'Chinedu A.',
        points: 3420,
        wins: 6,
        submissions: 21,
      ),
      const PointsEntry(
        rank: 2,
        name: 'Tunde F.',
        points: 2980,
        wins: 5,
        submissions: 18,
      ),
      const PointsEntry(
        rank: 3,
        name: 'Ngozi E.',
        points: 2410,
        wins: 4,
        submissions: 16,
      ),
      const PointsEntry(
        rank: 4,
        name: 'Amaka O.',
        points: 2105,
        wins: 3,
        submissions: 14,
      ),
      const PointsEntry(
        rank: 5,
        name: 'Bola A.',
        points: 1880,
        wins: 2,
        submissions: 19,
      ),
      const PointsEntry(
        rank: 6,
        name: 'Emeka U.',
        points: 1420,
        wins: 1,
        submissions: 22,
      ),
      PointsEntry(
        rank: 7,
        name: 'You',
        points: points,
        wins: wins,
        submissions: submissions,
        you: true,
      ),
      const PointsEntry(
        rank: 8,
        name: 'Funke A.',
        points: 1190,
        wins: 1,
        submissions: 15,
      ),
      const PointsEntry(
        rank: 9,
        name: 'Ifeoma N.',
        points: 1050,
        wins: 1,
        submissions: 12,
      ),
      const PointsEntry(
        rank: 10,
        name: 'Anonymous',
        points: 980,
        wins: 0,
        submissions: 8,
      ),
    ],
  );
}
