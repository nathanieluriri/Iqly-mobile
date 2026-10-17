import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/deadline.dart';
import '../../core/session.dart';
import '../../data/models.dart';
import '../../data/reference_data.dart';
import '../../data/repository.dart';
import '../../surfaces/surfaces.dart';
import '../onboarding/onboarding_draft.dart';
import '../submissions/submissions_state.dart';

enum FeedSort {
  myInterests('My interests first'),
  mostUrgent('Most urgent'),
  newest('Newest first'),
  biggestReward('Biggest reward');

  const FeedSort(this.label);
  final String label;
}

/// The Filters sheet. A null tier or category is "all". "My interests
/// first" is the For you feed; any other sort is the All feed.
class DiscoverFilters {
  const DiscoverFilters({
    this.status = BriefStatus.live,
    this.tier,
    this.category,
    this.sort = FeedSort.myInterests,
  });

  final BriefStatus status;
  final Tier? tier;
  final Category? category;
  final FeedSort sort;

  bool get forYou => sort == FeedSort.myInterests;

  /// True when the filters hide briefs; the sort alone does not.
  bool get narrowed =>
      status != BriefStatus.live || tier != null || category != null;

  bool matches(Brief brief) =>
      brief.status == status &&
      (tier == null || brief.tier == tier) &&
      (category == null || brief.category == category);

  DiscoverFilters copyWith({
    BriefStatus? status,
    Tier? Function()? tier,
    Category? Function()? category,
    FeedSort? sort,
  }) => DiscoverFilters(
    status: status ?? this.status,
    tier: tier == null ? this.tier : tier(),
    category: category == null ? this.category : category(),
    sort: sort ?? this.sort,
  );
}

class DiscoverFiltersNotifier extends Notifier<DiscoverFilters> {
  @override
  DiscoverFilters build() => const DiscoverFilters();

  void apply(DiscoverFilters filters) => state = filters;

  void showForYou() => state = state.copyWith(sort: FeedSort.myInterests);

  /// All lists closing soon first (designer answer 20).
  void showAll() {
    if (state.forYou) state = state.copyWith(sort: FeedSort.mostUrgent);
  }
}

final discoverFiltersProvider =
    NotifierProvider<DiscoverFiltersNotifier, DiscoverFilters>(
      DiscoverFiltersNotifier.new,
    );

/// The gift's shine plays once a session, on the first Discover load, and
/// not at all once Referrals has opened (designer answer 32). True once it
/// is spent either way.
class GiftShineNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void spend() => state = true;
}

final giftShineSpentProvider = NotifierProvider<GiftShineNotifier, bool>(
  GiftShineNotifier.new,
);

/// The lists that have played their first arrive this session (spec 2.6:
/// a list arrives on its first load, not on revisits).
final arrivedListsProvider = Provider<Set<String>>((ref) => <String>{});

/// The interests that order For you: the ones picked in first run, else
/// the profile's.
final feedInterestsProvider = Provider<List<String>>((ref) {
  final picked = ref.watch(
    onboardingDraftProvider.select((d) => d.profile.interests),
  );
  if (picked.isNotEmpty) return picked;
  final user = ref.watch(onboardingUserProvider).value;
  if (user == null) return const [];
  return [
    for (final label in user.interests)
      for (final option in Reference.interests)
        if (option.label == label) option.value,
  ];
});

enum RefreshPhase { idle, refreshing, done }

class FeedData {
  const FeedData({
    required this.briefs,
    this.window = FeedPaging.pageSize,
    this.loadingMore = false,
    this.refresh = RefreshPhase.idle,
    this.refreshedAt,
  });

  final List<Brief> briefs;

  /// How many list tickets (interest groups and More briefs) are loaded.
  final int window;
  final bool loadingMore;
  final RefreshPhase refresh;
  final DateTime? refreshedAt;

  FeedData copyWith({
    List<Brief>? briefs,
    int? window,
    bool? loadingMore,
    RefreshPhase? refresh,
    DateTime? refreshedAt,
  }) => FeedData(
    briefs: briefs ?? this.briefs,
    window: window ?? this.window,
    loadingMore: loadingMore ?? this.loadingMore,
    refresh: refresh ?? this.refresh,
    refreshedAt: refreshedAt ?? this.refreshedAt,
  );
}

abstract final class FeedPaging {
  static const pageSize = 6;
}

class DiscoverFeedNotifier extends AsyncNotifier<FeedData> {
  @override
  Future<FeedData> build() async => FeedData(
    briefs: await ref.watch(repositoryProvider).briefs(load: BriefsLoad.feed),
  );

  Future<void> retry() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  /// Pull to refresh: the feed stays as it is (no dimming) until the new
  /// list lands.
  Future<void> refresh() async {
    final current = state.value;
    if (current == null || current.refresh == RefreshPhase.refreshing) return;
    state = AsyncData(current.copyWith(refresh: RefreshPhase.refreshing));
    try {
      final briefs = await ref
          .read(repositoryProvider)
          .briefs(load: BriefsLoad.refresh);
      state = AsyncData(
        current.copyWith(
          briefs: briefs,
          refresh: RefreshPhase.done,
          refreshedAt: ref.read(clockProvider)(),
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(refresh: RefreshPhase.idle));
    }
  }

  /// A return to the tab: the feed on screen stays as it is and the new
  /// list replaces it when it lands; a failure keeps what was there.
  Future<void> refreshQuietly() async {
    final current = state.value;
    if (current == null || current.refresh != RefreshPhase.idle) return;
    try {
      final briefs = await ref
          .read(repositoryProvider)
          .briefs(load: BriefsLoad.refresh);
      final now = state.value;
      if (now == null || now.refresh != RefreshPhase.idle) return;
      state = AsyncData(now.copyWith(briefs: briefs));
    } catch (_) {}
  }

  void settleRefresh() {
    final current = state.value;
    if (current == null || current.refresh != RefreshPhase.done) return;
    state = AsyncData(current.copyWith(refresh: RefreshPhase.idle));
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final briefs = await ref
          .read(repositoryProvider)
          .briefs(load: BriefsLoad.nextPage);
      state = AsyncData(
        current.copyWith(
          briefs: briefs,
          window: current.window + FeedPaging.pageSize,
          loadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }

  void resetWindow() {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(window: FeedPaging.pageSize));
  }
}

/// No automatic retry: a failed load shows the banner and its Try again.
final discoverFeedProvider =
    AsyncNotifierProvider<DiscoverFeedNotifier, FeedData>(
      DiscoverFeedNotifier.new,
      retry: (count, error) => null,
    );

class FeedGroup {
  const FeedGroup({
    required this.title,
    required this.briefs,
    required this.total,
  });

  final String title;
  final List<Brief> briefs;
  final int total;
}

/// What Discover lays out under its Briefs heading, cut to the loaded
/// window. For you: the briefs closing soon and those filed under the
/// person's interests, then More briefs. All: one list. Closing soon cards
/// always lead (Exp/BriefCard).
class FeedView {
  const FeedView({
    required this.total,
    required this.briefs,
    required this.more,
    required this.hasMore,
  });

  final int total;
  final FeedGroup briefs;
  final FeedGroup more;
  final bool hasMore;

  bool get isEmpty => total == 0;
}

/// Whether [brief] wears the closing-soon tint and outline.
bool isClosingSoon(Brief brief, DateTime now) {
  final left = timeLeft(brief.deadline, now);
  return left != null &&
      left > Duration.zero &&
      left < DeadlineRules.closingSoonOutline;
}

List<Brief> filterBriefs(List<Brief> briefs, DiscoverFilters filters) =>
    briefs.where(filters.matches).toList();

FeedView buildFeed({
  required List<Brief> briefs,
  required DiscoverFilters filters,
  required List<String> interests,
  required DateTime now,
  required int window,
}) {
  final matching = filterBriefs(briefs, filters);
  bool leads(Brief b) => isClosingSoon(b, now);
  final closing = _sorted(matching.where(leads), _bySoonest(now));
  final rest = matching.where((b) => !leads(b));

  final List<Brief> first;
  final List<Brief> second;
  if (filters.forYou) {
    first = [
      ...closing,
      ..._sorted(
        rest.where((b) => interests.contains(b.interest)),
        _bySoonest(now),
      ),
    ];
    second = _sorted(
      rest.where((b) => !interests.contains(b.interest)),
      _bySoonest(now),
    );
  } else {
    first = [
      ...closing,
      ..._sorted(rest, switch (filters.sort) {
        FeedSort.biggestReward => (a, b) => b.rewardPoolKobo.compareTo(
          a.rewardPoolKobo,
        ),
        FeedSort.newest => (a, b) => b.createdAt.compareTo(a.createdAt),
        FeedSort.mostUrgent || FeedSort.myInterests => _bySoonest(now),
      }),
    ];
    second = const [];
  }

  final firstShown = window.clamp(0, first.length);
  final secondShown = (window - first.length).clamp(0, second.length);
  return FeedView(
    total: matching.length,
    briefs: FeedGroup(
      title: 'Briefs',
      briefs: first.take(firstShown).toList(),
      total: first.length,
    ),
    more: FeedGroup(
      title: 'More briefs',
      briefs: second.take(secondShown).toList(),
      total: second.length,
    ),
    hasMore: firstShown + secondShown < matching.length,
  );
}

int Function(Brief, Brief) _bySoonest(DateTime now) => (a, b) {
  final da = a.deadline, db = b.deadline;
  if (da == null && db == null) return 0;
  if (da == null) return 1;
  if (db == null) return -1;
  return da.compareTo(db);
};

/// Stable: equal keys keep the API order.
List<Brief> _sorted(Iterable<Brief> briefs, int Function(Brief, Brief) by) {
  final indexed = briefs.toList().asMap().entries.toList()
    ..sort((a, b) {
      final c = by(a.value, b.value);
      return c != 0 ? c : a.key.compareTo(b.key);
    });
  return [for (final e in indexed) e.value];
}

/// Saved briefs, newest save first, kept on the device in full so the Saved
/// list and brief detail still open offline. Seeds from the account on
/// first run.
class SavedBriefsNotifier extends AsyncNotifier<List<Brief>> {
  static const key = 'discover.savedBriefs';

  /// The device's copy is there from the first frame, so a bookmark never
  /// animates into the state it already had.
  @override
  FutureOr<List<Brief>> build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(key);
    if (raw != null) {
      return [
        for (final item in jsonDecode(raw) as List<Object?>)
          Brief.fromJson((item! as Map).cast<String, Object?>()),
      ];
    }
    return _seed();
  }

  Future<List<Brief>> _seed() async {
    final repo = ref.watch(repositoryProvider);
    final saved = [
      for (final id in await repo.savedBriefIds()) ?await repo.brief(id),
    ];
    await _persist(saved);
    return saved;
  }

  bool isSaved(String id) => state.value?.any((b) => b.id == id) ?? false;

  Future<void> setSaved(Brief brief, bool saved) async {
    final current = [...?state.value]..removeWhere((b) => b.id == brief.id);
    if (saved) current.insert(0, brief);
    state = AsyncData(current);
    await _persist(current);
    await ref.read(repositoryProvider).setBriefSaved(brief.id, saved);
  }

  Future<void> _persist(List<Brief> briefs) => ref
      .read(sharedPreferencesProvider)
      .setString(key, jsonEncode([for (final b in briefs) b.toJson()]));
}

final savedBriefsProvider =
    AsyncNotifierProvider<SavedBriefsNotifier, List<Brief>>(
      SavedBriefsNotifier.new,
    );

/// Briefs with a close reminder (an hour before close).
class CloseRemindersNotifier extends AsyncNotifier<Set<String>> {
  static const key = 'discover.closeReminders';

  /// The device's copy is there from the first frame, so "Remind me" opens
  /// in its state instead of switching into it.
  @override
  FutureOr<Set<String>> build() {
    final stored = ref.watch(sharedPreferencesProvider).getStringList(key);
    if (stored != null) return stored.toSet();
    return _seed();
  }

  Future<Set<String>> _seed() async {
    final ids = await ref.watch(repositoryProvider).closeReminderIds();
    await ref.read(sharedPreferencesProvider).setStringList(key, ids);
    return ids.toSet();
  }

  Future<void> setReminder(String id, bool on) async {
    final next = {...?state.value};
    on ? next.add(id) : next.remove(id);
    state = AsyncData(next);
    await ref.read(sharedPreferencesProvider).setStringList(key, [...next]);
    await ref.read(repositoryProvider).setCloseReminder(id, on);
    await syncSurfaces();
  }

  /// Puts the phone's scheduled reminders in step with the switches and
  /// each brief's current close.
  Future<void> syncSurfaces() async {
    final surfaces = ref.read(surfacesProvider);
    if (surfaces == null) return;
    try {
      final ids = await future;
      final repository = ref.read(repositoryProvider);
      final briefs = await Future.wait(ids.map(repository.brief));
      await surfaces.syncCloseReminders(briefs.nonNulls);
    } on Object catch (error) {
      debugPrint('Close reminders not scheduled: $error');
    }
  }
}

final closeRemindersProvider =
    AsyncNotifierProvider<CloseRemindersNotifier, Set<String>>(
      CloseRemindersNotifier.new,
    );

/// Brief detail: from the API, else the saved copy when offline.
final briefDetailProvider = FutureProvider.family<Brief?, String>((
  ref,
  id,
) async {
  try {
    final brief = await ref.watch(repositoryProvider).brief(id);
    if (brief != null) return brief;
  } catch (_) {
    // Offline: fall through to the saved copy.
  }
  final saved = await ref.watch(savedBriefsProvider.future);
  return saved.where((b) => b.id == id).firstOrNull;
});

/// The person's submission to brief [id], if they sent one: from those
/// sent this session at once, else from the account.
final briefSubmissionProvider = Provider.autoDispose.family<String?, String>((
  ref,
  id,
) {
  final sent = ref
      .watch(sentSubmissionsProvider)
      .where((i) => i.submission.briefId == id)
      .firstOrNull;
  if (sent != null) return sent.id;
  return ref
      .watch(_accountSubmissionsProvider)
      .value
      ?.where((s) => s.briefId == id)
      .firstOrNull
      ?.id;
});

final _accountSubmissionsProvider =
    FutureProvider.autoDispose<List<Submission>>(
      (ref) => ref.watch(repositoryProvider).submissions(),
    );
