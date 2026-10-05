import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/drafts_data.dart';
import '../../data/models.dart';
import '../../data/repository.dart';

/// The drafts on this phone, newest edit first. Saves land here at once and
/// reach the store behind them.
class DraftsNotifier extends AsyncNotifier<List<Draft>> {
  @override
  Future<List<Draft>> build() => ref.watch(repositoryProvider).drafts();

  IqlyRepository get _repository => ref.read(repositoryProvider);

  Future<void> save(Draft draft) async {
    final rest = [
      for (final d in state.value ?? const <Draft>[])
        if (d.briefId != draft.briefId) d,
    ];
    state = AsyncData(draft.isEmpty ? rest : [draft, ...rest]);
    await _repository.saveDraft(draft);
  }

  Future<void> discard(Iterable<String> briefIds) async {
    final gone = briefIds.toSet();
    state = AsyncData([
      for (final d in state.value ?? const <Draft>[])
        if (!gone.contains(d.briefId)) d,
    ]);
    await _repository.discardDrafts(gone);
  }
}

final draftsProvider = AsyncNotifierProvider<DraftsNotifier, List<Draft>>(
  DraftsNotifier.new,
);

/// A draft with the brief it answers, for its logo and business name.
class DraftItem {
  const DraftItem(this.draft, this.brief);

  final Draft draft;
  final Brief? brief;

  String get business => businessOf(brief);
}

final draftItemsProvider = FutureProvider<List<DraftItem>>((ref) async {
  final drafts = await ref.watch(draftsProvider.future);
  final briefs = await ref.watch(repositoryProvider).briefs();
  return [
    for (final draft in drafts)
      DraftItem(
        draft,
        briefs.where((b) => b.id == draft.briefId).firstOrNull,
      ),
  ];
});

/// "The business" in prose; an anonymous one reads "Private business".
String businessOf(Brief? brief) => brief?.businessName ?? 'Private business';

/// "2 hours ago", "yesterday", "3 days ago" (481:23202).
String editedAgo(DateTime at, DateTime now) {
  final minutes = now.difference(at).inMinutes.abs();
  final days = (minutes / Duration.minutesPerDay).round();
  if (days == 1) return 'yesterday';
  if (days > 1) return '$days days ago';
  final hours = (minutes / Duration.minutesPerHour).round();
  if (hours == 0) return 'just now';
  return hours == 1 ? '1 hour ago' : '$hours hours ago';
}

String stepOf(Draft draft) => 'Step ${draft.step} of ${DraftSteps.total}';

/// "Unibooks · Step 2 of 3 · 2 hours ago" under a DraftRow title.
String draftMeta(DraftItem item, DateTime now) =>
    '${item.business} · ${stepOf(item.draft)} · '
    '${editedAgo(item.draft.editedAt, now)}';

/// The draft actions sheet's line (499:26919).
String draftActionsBody(DraftItem item, DateTime now) =>
    '${item.business} · ${stepOf(item.draft)} · edited '
    '${editedAgo(item.draft.editedAt, now)}. '
    'Pick up where you stopped, or discard it.';

/// "Drafts · 2" and "Unibooks and Sunline · last edited 2 hours ago" on the
/// My submissions entry row (35:24).
String draftsEntryLabel(int count) => 'Drafts · $count';

String draftsEntryDescription(List<DraftItem> items, DateTime now) {
  final names = <String>[];
  for (final item in items) {
    if (!names.contains(item.business)) names.add(item.business);
  }
  final who = names.length == 1
      ? names.single
      : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
  return '$who · last edited ${editedAgo(items.first.draft.editedAt, now)}';
}

String draftsCount(int count) => count == 1 ? '1 draft' : '$count drafts';

String discardLabel(int count) =>
    count == 1 ? 'Discard 1 draft' : 'Discard $count drafts';
