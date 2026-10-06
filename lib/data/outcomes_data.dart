/// One row of a brief's leaderboard: the rank, the contributor (as shipped:
/// their name or "Anonymous"), their entry and the amount awarded, null
/// below the paid places.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.name,
    required this.entry,
    this.amountKobo,
  });

  final int rank;
  final String name;
  final String entry;
  final int? amountKobo;
}

/// The business's short note to an entry it did not pick. A proposal: it
/// needs a business-side field, so it sits behind Flags.businessNote.
class BusinessNote {
  const BusinessNote({
    required this.business,
    required this.body,
    required this.sentAt,
  });

  final String business;
  final String body;
  final DateTime sentAt;
}

/// How a decided submission placed. [rank] and [entries] stay null until
/// the business publishes its leaderboard; [leaders] are the other
/// contributors' rows in rank order (the contributor's own row is built
/// from their submission and award).
class Outcome {
  const Outcome({
    required this.submissionId,
    required this.link,
    this.rank,
    this.entries,
    this.leaders = const [],
    this.note,
  });

  final String submissionId;

  /// The brief's public page (iqly.net/challenges/:id), for Copy link and
  /// the share text.
  final String link;
  final int? rank;
  final int? entries;
  final List<LeaderboardEntry> leaders;
  final BusinessNote? note;

  bool get hasLeaderboard => rank != null && entries != null;
}

/// Demo outcomes from the B13 frames.
///
/// s2 (193:9573, 193:9779): 5th of 48. The others were paid 175,000,
/// 100,000, 62,500 and 50,000 and the contributor 12,500 (DemoData ledger
/// l3), which foots to brief c3's 400,000 pool.
///
/// s5 (193:9681, 225:10747): 9th of 36. Figma pays 32,000, 24,000, 16,000
/// and 8,000 ("₦80,000 shared by the winners"), but s5 answers c7, whose
/// pool is 350,000 (DemoData), so the same 40/30/20/10 split is kept on
/// 350,000.
///
/// Both boards list ranks 4 to 12 as 193:9779 and 225:10747 draw them; a
/// live board lists every rank the API returns.
///
/// s3: the business has not published a leaderboard.
abstract final class OutcomesDemo {
  static Outcome? of(String submissionId, DateTime now) =>
      switch (submissionId) {
        's2' => const Outcome(
          submissionId: 's2',
          link: 'https://iqly.net/challenges/c3',
          rank: 5,
          entries: 48,
          leaders: [
            LeaderboardEntry(
              rank: 1,
              name: 'Chinedu A.',
              entry: 'Bundles reset on Sunday',
              amountKobo: 17500000,
            ),
            LeaderboardEntry(
              rank: 2,
              name: 'Tunde F.',
              entry: 'Open banks on Sunday',
              amountKobo: 10000000,
            ),
            LeaderboardEntry(
              rank: 3,
              name: 'Anonymous',
              entry: 'Sunday is for family',
              amountKobo: 6250000,
            ),
            LeaderboardEntry(
              rank: 4,
              name: 'Ngozi E.',
              entry: 'Data runs out by Sunday',
              amountKobo: 5000000,
            ),
            LeaderboardEntry(
              rank: 6,
              name: 'Anonymous',
              entry: 'Sunday is church day',
            ),
            LeaderboardEntry(
              rank: 7,
              name: 'Bola A.',
              entry: 'No bank, no stress',
            ),
            LeaderboardEntry(
              rank: 8,
              name: 'Amaka O.',
              entry: 'Sunday balance check',
            ),
            LeaderboardEntry(
              rank: 9,
              name: 'Emeka U.',
              entry: 'Rest day for your money',
            ),
            LeaderboardEntry(
              rank: 10,
              name: 'Funke A.',
              entry: 'Pay Monday, not Sunday',
            ),
            LeaderboardEntry(rank: 11, name: 'Anonymous', entry: 'Slow Sunday'),
            LeaderboardEntry(
              rank: 12,
              name: 'Ifeoma N.',
              entry: 'Network goes to church too',
            ),
          ],
        ),
        's3' => const Outcome(
          submissionId: 's3',
          link: 'https://iqly.net/challenges/c8',
        ),
        's5' => Outcome(
          submissionId: 's5',
          link: 'https://iqly.net/challenges/c7',
          rank: 9,
          entries: 36,
          leaders: const [
            LeaderboardEntry(
              rank: 1,
              name: 'Chinedu A.',
              entry: 'One counter, every branch',
              amountKobo: 14000000,
            ),
            LeaderboardEntry(
              rank: 2,
              name: 'Anonymous',
              entry: 'Skip-the-queue card',
              amountKobo: 10500000,
            ),
            LeaderboardEntry(
              rank: 3,
              name: 'Tunde F.',
              entry: 'Pay once at the door',
              amountKobo: 7000000,
            ),
            LeaderboardEntry(
              rank: 4,
              name: 'Ngozi E.',
              entry: 'A quick-jobs lane',
              amountKobo: 3500000,
            ),
            LeaderboardEntry(
              rank: 5,
              name: 'Chiamaka O.',
              entry: 'Two tellers, one queue',
            ),
            LeaderboardEntry(
              rank: 6,
              name: 'Bola A.',
              entry: 'Book a slot by USSD',
            ),
            LeaderboardEntry(
              rank: 7,
              name: 'Anonymous',
              entry: 'Evening hours for traders',
            ),
            LeaderboardEntry(
              rank: 8,
              name: 'Emeka U.',
              entry: 'A card for regulars',
            ),
            LeaderboardEntry(
              rank: 10,
              name: 'Funke A.',
              entry: 'Number tickets at the door',
            ),
            LeaderboardEntry(
              rank: 11,
              name: 'Amaka O.',
              entry: 'Mobile counter at the market',
            ),
            LeaderboardEntry(
              rank: 12,
              name: 'Ifeoma N.',
              entry: 'Let agents take deposits',
            ),
          ],
          note: BusinessNote(
            business: 'Harbour Microfinance',
            body:
                'Good idea. The winners also fixed the Monday rush without '
                'adding staff.',
            sentAt: _lastFriday(now, hour: 11, minute: 20),
          ),
        ),
        _ => null,
      };

  /// Figma's "FRI, 11:20 AM" seen on a Saturday morning: the Friday before.
  static DateTime _lastFriday(
    DateTime now, {
    required int hour,
    required int minute,
  }) {
    var back = (now.weekday - DateTime.friday) % 7;
    if (back == 0) back = 7;
    final day = DateTime(now.year, now.month, now.day - back);
    return DateTime(day.year, day.month, day.day, hour, minute);
  }
}
