import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/backend.dart';
import '../../core/deadline.dart';
import '../../core/session.dart';
import '../../data/live/live_repository.dart';
import '../../data/models.dart';
import '../../data/repository.dart';

/// A submission with the brief it answers and, for a winner, the award the
/// ledger paid for it and when.
class SubmissionItem {
  const SubmissionItem({
    required this.submission,
    required this.brief,
    this.awardKobo,
    this.awardedAt,
  });

  final Submission submission;
  final Brief? brief;
  final int? awardKobo;
  final DateTime? awardedAt;

  String get id => submission.id;
  SubmissionStatus get status => submission.status;
  bool get underReview =>
      status == SubmissionStatus.pending || status == SubmissionStatus.scored;

  /// "Business · brief title", or the title alone when the business is
  /// anonymous (324:14478).
  String get briefLine {
    final b = brief;
    if (b == null) return '';
    final business = b.businessName;
    return business == null ? b.title : '$business · ${b.title}';
  }
}

/// The Segmented lenses of My submissions, in Figma order.
enum SubmissionsTab {
  underReview('Under review'),
  winners('Winners'),
  notSelected('Not selected');

  const SubmissionsTab(this.label);
  final String label;

  static SubmissionsTab of(SubmissionStatus status) => switch (status) {
    SubmissionStatus.pending || SubmissionStatus.scored => underReview,
    SubmissionStatus.winner => winners,
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

  List<SubmissionItem> of(SubmissionsTab tab) =>
      items.where((i) => SubmissionsTab.of(i.status) == tab).toList();

  /// What the wins paid, in kobo.
  int get wonKobo =>
      of(SubmissionsTab.winners).fold(0, (sum, i) => sum + (i.awardKobo ?? 0));
}

/// The submissions the signed-in account sent in this session, newest
/// first. A send hands its receipt here, so My submissions and Submission
/// detail have the new one at once instead of waiting for the next load to
/// bring it back.
class SentSubmissionsNotifier extends Notifier<List<SubmissionItem>> {
  @override
  List<SubmissionItem> build() {
    ref.watch(accountProvider);
    return const [];
  }

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
/// from the moment they are sent. Kept for the session: a later visit shows
/// what it has and [refreshQuietly] loads behind it. Live entries carry
/// their brief and award as the API embeds them, so an entry on a brief
/// that has left the live feed still shows it.
class MySubmissionsNotifier extends AsyncNotifier<MySubmissions> {
  @override
  Future<MySubmissions> build() async {
    ref.watch(accountProvider);
    ref.listen(sentSubmissionsProvider, (_, sent) {
      if (state case AsyncData(:final value)) {
        state = AsyncData(value.including(sent));
      }
    });
    final repo = ref.watch(repositoryProvider);
    if (ref.watch(liveModeProvider).isLive(LiveFeature.submissions)) {
      final items = [
        for (final s in await repo.submissions())
          SubmissionItem(
            submission: s,
            brief: s.brief,
            awardKobo: s.award?.amountKobo,
            awardedAt: s.award?.awardedAt,
          ),
      ]..sort(MySubmissions._newestFirst);
      return MySubmissions(items).including(ref.read(sentSubmissionsProvider));
    }
    final (submissions, briefs, ledger) = await (
      repo.submissions(),
      repo.briefs(),
      repo.ledger(),
    ).wait;
    final byId = {for (final b in briefs) b.id: b};
    final awards = <String, LedgerEntry>{
      for (final l in ledger)
        if (l.type == LedgerType.award && l.submissionId != null)
          l.submissionId!: l,
    };
    final items = [
      for (final s in submissions)
        SubmissionItem(
          submission: s,
          brief: byId[s.briefId],
          awardKobo: awards[s.id]?.amountKobo,
          awardedAt: awards[s.id]?.createdAt,
        ),
    ]..sort(MySubmissions._newestFirst);
    return MySubmissions(items).including(ref.read(sentSubmissionsProvider));
  }

  /// Loads again behind the list on screen; a failure keeps the list.
  void refreshQuietly() {
    if (state.hasValue) ref.invalidateSelf();
  }
}

/// No automatic retry: the failed state offers "Try again".
final mySubmissionsProvider =
    AsyncNotifierProvider<MySubmissionsNotifier, MySubmissions>(
      MySubmissionsNotifier.new,
      retry: (_, _) => null,
    );

/// The lens My submissions shows; it stays put across visits.
class SubmissionsTabNotifier extends Notifier<SubmissionsTab> {
  @override
  SubmissionsTab build() => SubmissionsTab.underReview;

  void select(SubmissionsTab tab) => state = tab;
}

final submissionsTabProvider =
    NotifierProvider<SubmissionsTabNotifier, SubmissionsTab>(
      SubmissionsTabNotifier.new,
    );

/// Taken from the loaded list, or from the ones just sent, at once when
/// either has it, so a detail pushed from a card or from the sent moment
/// draws from its first frame. Only a cold open waits for the load.
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

/// Live briefs not answered yet, soonest to close first.
Future<List<Brief>> openBriefs(Ref ref) async {
  final (briefs, mine) = await (
    ref.watch(repositoryProvider).briefs(),
    ref.watch(mySubmissionsProvider.future),
  ).wait;
  final answered = {for (final i in mine.items) i.submission.briefId};
  return [
    for (final b in briefs)
      if (b.isLive && !answered.contains(b.id)) b,
  ]..sort((a, b) {
    final ad = a.deadline, bd = b.deadline;
    if (ad == null || bd == null) return ad == null ? 1 : -1;
    return ad.compareTo(bd);
  });
}

/// "Try another brief" under Not selected (324:14520): two open briefs, the
/// business that passed on you first, then the soonest to close among the
/// ones with two days or more to go.
final tryAnotherBriefsProvider = FutureProvider.autoDispose<List<Brief>>((
  ref,
) async {
  final open = await openBriefs(ref);
  final mine = await ref.watch(mySubmissionsProvider.future);
  final passed = {
    for (final i in mine.of(SubmissionsTab.notSelected)) ?i.brief?.businessName,
  };
  final now = ref.watch(clockProvider)();
  bool roomy(Brief b) =>
      b.deadline == null ||
      b.deadline!.difference(now) >= DeadlineRules.closingSoonOutline;
  final same = open.where((b) => passed.contains(b.businessName));
  final rest = open.where((b) => !passed.contains(b.businessName) && roomy(b));
  return [...same, ...rest].take(2).toList();
});
