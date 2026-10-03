import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/repository.dart';

/// A submission with the brief it answers and, for a winner, the award the
/// ledger paid for it.
class SubmissionItem {
  const SubmissionItem({
    required this.submission,
    required this.brief,
    this.awardKobo,
  });

  final Submission submission;
  final Brief? brief;
  final int? awardKobo;

  String get id => submission.id;
  SubmissionStatus get status => submission.status;
  bool get underReview =>
      status == SubmissionStatus.pending || status == SubmissionStatus.scored;

  /// "Brief title · Business", or the title alone when the business is
  /// anonymous.
  String get briefLine {
    final b = brief;
    if (b == null) return '';
    final business = b.businessName;
    return business == null ? b.title : '${b.title} · $business';
  }
}

/// The three groups of the list, in the order the frame shows them.
enum SubmissionGroup {
  underReview('Under review'),
  winner('Winner'),
  notSelected('Not selected');

  const SubmissionGroup(this.title);
  final String title;

  static SubmissionGroup of(SubmissionStatus status) => switch (status) {
    SubmissionStatus.pending || SubmissionStatus.scored => underReview,
    SubmissionStatus.winner => winner,
    SubmissionStatus.filteredOut => notSelected,
  };
}

class MySubmissions {
  const MySubmissions(this.items);

  /// Newest first.
  final List<SubmissionItem> items;

  int get underReviewCount => items.where((i) => i.underReview).length;

  List<SubmissionItem> group(SubmissionGroup group) =>
      items.where((i) => SubmissionGroup.of(i.status) == group).toList();

  String get greeting {
    if (items.isEmpty) return '0 sent';
    return '${items.length} sent · $underReviewCount under review';
  }
}

/// No automatic retry: the failed state offers "Try again".
final mySubmissionsProvider = FutureProvider.autoDispose<MySubmissions>(
  retry: (_, _) => null,
  (ref) async {
    final repo = ref.watch(repositoryProvider);
    final (submissions, briefs, ledger) = await (
      repo.submissions(),
      repo.briefs(),
      repo.ledger(),
    ).wait;
    final byId = {for (final b in briefs) b.id: b};
    final awards = <String, int>{
      for (final l in ledger)
        if (l.type == LedgerType.award && l.submissionId != null)
          l.submissionId!: l.amountKobo,
    };
    final items = [
      for (final s in submissions)
        SubmissionItem(
          submission: s,
          brief: byId[s.briefId],
          awardKobo: awards[s.id],
        ),
    ]..sort((a, b) => b.submission.createdAt.compareTo(a.submission.createdAt));
    return MySubmissions(items);
  },
);

/// Taken from the loaded list at once when there is one, so a detail pushed
/// from a row draws from its first frame and its status can fly in.
final submissionItemProvider = FutureProvider.autoDispose
    .family<SubmissionItem?, String>((ref, id) {
      SubmissionItem? pick(MySubmissions all) =>
          all.items.where((i) => i.id == id).firstOrNull;
      final loaded = ref.watch(mySubmissionsProvider).value;
      if (loaded != null) return pick(loaded);
      return ref.watch(mySubmissionsProvider.future).then(pick);
    });
