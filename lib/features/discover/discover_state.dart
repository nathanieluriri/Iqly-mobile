import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/deadline.dart';
import '../../core/session.dart';
import '../../data/models.dart';
import '../../data/reference_data.dart';
import '../../data/repository.dart';
import '../onboarding/onboarding_draft.dart';
import '../polls/polls_state.dart';

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

  void showAll() {
    if (state.forYou) state = state.copyWith(sort: FeedSort.newest);
  }
}

final discoverFiltersProvider =
    NotifierProvider<DiscoverFiltersNotifier, DiscoverFilters>(
      DiscoverFiltersNotifier.new,
    );

/// Counts lens chip taps (For you, All, Saved), so the feed under the chips
/// fades its content in on each (spec 3.7).
class LensSwitchNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final lensSwitchProvider = NotifierProvider<LensSwitchNotifier, int>(
  LensSwitchNotifier.new,
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

/// The bubbles follow the person's votes (lib/features/polls).
final pollBrandsProvider = FutureProvider<List<PollBrand>>(
  (ref) async => [
    for (final business in await ref.watch(pollsProvider.future))
      business.brand,
  ],
);

final activationsSummaryProvider = FutureProvider<ActivationsSummary>(
  (ref) => ref.watch(repositoryProvider).activationsSummary(),
);

String greeting(DateTime now, String? firstName) {
  if (firstName == null) return '';
  final part = now.hour < 12
      ? 'morning'
      : now.hour < 17
      ? 'afternoon'
      : 'evening';
  return 'Good $part, $firstName';
}

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

/// What Discover lays out: Closing soon, then the interest groups (For you
/// only), then More briefs, cut to the loaded window.
class FeedView {
  const FeedView({
    required this.total,
    required this.closingSoon,
    required this.groups,
    required this.more,
    required this.hasMore,
  });

  final int total;
  final List<Brief> closingSoon;
  final List<FeedGroup> groups;
  final FeedGroup more;
  final bool hasMore;

  bool get isEmpty => total == 0;
}

abstract final class FeedRules {
  static const closingSoonWithin = DeadlineRules.closingSoon;
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

  final closingSoon = _sorted(
    matching.where((b) {
      final left = timeLeft(b.deadline, now);
      return left != null &&
          left > Duration.zero &&
          left <= FeedRules.closingSoonWithin;
    }),
    _bySoonest(now),
  );

  final groups = <FeedGroup>[];
  final grouped = <String>{};
  if (filters.forYou) {
    for (final interest in interests) {
      final inGroup = _sorted(
        matching.where((b) => b.interest == interest),
        _bySoonest(now),
      );
      if (inGroup.isEmpty) continue;
      grouped.addAll(inGroup.map((b) => b.id));
      final label = Reference.interests
          .firstWhere((o) => o.value == interest)
          .label;
      groups.add(
        FeedGroup(title: label, briefs: inGroup, total: inGroup.length),
      );
    }
  }

  final rest = _sorted(
    matching.where((b) => !grouped.contains(b.id)),
    switch (filters.sort) {
      FeedSort.mostUrgent => _bySoonest(now),
      FeedSort.biggestReward => (a, b) => b.rewardPoolKobo.compareTo(
        a.rewardPoolKobo,
      ),
      FeedSort.myInterests ||
      FeedSort.newest => (a, b) => b.createdAt.compareTo(a.createdAt),
    },
  );

  final inGroups = grouped.length;
  final moreShown = (window - inGroups).clamp(0, rest.length);
  return FeedView(
    total: matching.length,
    closingSoon: closingSoon,
    groups: groups,
    more: FeedGroup(
      title: 'More briefs',
      briefs: rest.take(moreShown).toList(),
      total: rest.length,
    ),
    hasMore: moreShown < rest.length,
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
  static const _key = 'discover.savedBriefs';

  /// The device's copy is there from the first frame, so a bookmark never
  /// animates into the state it already had.
  @override
  FutureOr<List<Brief>> build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_key);
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
      .setString(_key, jsonEncode([for (final b in briefs) b.toJson()]));
}

final savedBriefsProvider =
    AsyncNotifierProvider<SavedBriefsNotifier, List<Brief>>(
      SavedBriefsNotifier.new,
    );

/// Briefs with a close reminder (an hour before close).
class CloseRemindersNotifier extends AsyncNotifier<Set<String>> {
  static const _key = 'discover.closeReminders';

  /// The device's copy is there from the first frame, so "Remind me" opens
  /// in its state instead of switching into it.
  @override
  FutureOr<Set<String>> build() {
    final stored = ref.watch(sharedPreferencesProvider).getStringList(_key);
    if (stored != null) return stored.toSet();
    return _seed();
  }

  Future<Set<String>> _seed() async {
    final ids = await ref.watch(repositoryProvider).closeReminderIds();
    await ref.read(sharedPreferencesProvider).setStringList(_key, ids);
    return ids.toSet();
  }

  Future<void> setReminder(String id, bool on) async {
    final next = {...?state.value};
    on ? next.add(id) : next.remove(id);
    state = AsyncData(next);
    await ref.read(sharedPreferencesProvider).setStringList(_key, [...next]);
    await ref.read(repositoryProvider).setCloseReminder(id, on);
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
