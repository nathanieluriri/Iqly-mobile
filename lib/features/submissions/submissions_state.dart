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

  /// With the [sent] ones the load does not have yet, newest first.
  MySubmissions including(List<SubmissionItem> sent) {
    final known = {for (final i in items) i.id};
    final missing = [
      for (final i in sent)
        if (!known.contains(i.id)) i,
    ];
    if (missing.isEmpty) return this;
    return MySubmissions([...missing, ...items]..sort(_newestFirst));
  }

  static int _newestFirst(SubmissionItem a, SubmissionItem b) =>
      b.submission.createdAt.compareTo(a.submission.createdAt);

  int get underReviewCount => items.where((i) => i.underReview).length;

  List<SubmissionItem> group(SubmissionGroup group) =>
      items.where((i) => SubmissionGroup.of(i.status) == group).toList();

  String get greeting {
    if (items.isEmpty) return '0 sent';
    return '${items.length} sent · $underReviewCount under review';
  }
}

/// The submissions sent in this session, newest first. A send hands its
/// receipt here, so My submissions and Submission detail have the new one
/// at once instead of waiting for the next load to bring it back.
class SentSubmissionsNotifier extends Notifier<List<SubmissionItem>> {
  @override
  List<SubmissionItem> build() => const [];

  void add(SubmissionItem item) => state = [
    item,
    for (final i in state)
      if (i.id != item.id) i,
  ];
}

final sentSubmissionsProvider =
    NotifierProvider<SentSubmissionsNotifier, List<SubmissionItem>>(
      SentSubmissionsNotifier.new,
    );

/// The contributor's submissions, with the ones sent this session in place
/// from the moment they are sent.
class MySubmissionsNotifier extends AsyncNotifier<MySubmissions> {
  @override
  Future<MySubmissions> build() async {
    ref.listen(sentSubmissionsProvider, (_, sent) {
      if (state case AsyncData(:final value)) {
        state = AsyncData(value.including(sent));
      }
    });
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
    ]..sort(MySubmissions._newestFirst);
    return MySubmissions(items).including(ref.read(sentSubmissionsProvider));
  }
}

/// No automatic retry: the failed state offers "Try again".
final mySubmissionsProvider =
    AsyncNotifierProvider.autoDispose<MySubmissionsNotifier, MySubmissions>(
      MySubmissionsNotifier.new,
      retry: (_, _) => null,
    );

/// Taken from the loaded list, or from the ones just sent, at once when
/// either has it, so a detail pushed from a row or from the sent moment
/// draws from its first frame (and a row's status can fly in). Only a cold
/// open waits for the load.
final submissionItemProvider = FutureProvider.autoDispose
    .family<SubmissionItem?, String>((ref, id) {
      SubmissionItem? pick(MySubmissions all) =>
          all.items.where((i) => i.id == id).firstOrNull;
      final loaded = ref.watch(mySubmissionsProvider).value;
      if (loaded != null) return pick(loaded);
      final sent = ref
          .watch(sentSubmissionsProvider)
          .where((i) => i.id == id)
          .firstOrNull;
      if (sent != null) return sent;
      return ref.watch(mySubmissionsProvider.future).then(pick);
    });
