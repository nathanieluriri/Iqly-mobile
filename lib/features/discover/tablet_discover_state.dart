import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/deadline.dart';
import '../../core/money.dart';
import '../../data/models.dart';
import '../../data/reference_data.dart';

enum ClosesWithin {
  any('Any time', null),
  today('Today', Duration(days: 1)),
  threeDays('In the next 3 days', Duration(days: 3)),
  sevenDays('In the next 7 days', Duration(days: 7));

  const ClosesWithin(this.label, this.within);

  final String label;
  final Duration? within;

  /// The applied chip: "Closes: Today".
  String get chip => 'Closes: ${this == today ? label : label.toLowerCase()}';
}

/// The tablet filters (T4 · Discover · filters open), the desktop set: when
/// a brief closes, its reward pool, tier, category and interests. Empty
/// sets let everything through.
class TabletFilters {
  const TabletFilters({
    this.closes = ClosesWithin.any,
    this.tiers = const {},
    this.categories = const {},
    this.interests = const {},
    this.minKobo,
    this.maxKobo,
  });

  final ClosesWithin closes;
  final Set<Tier> tiers;
  final Set<Category> categories;
  final Set<String> interests;
  final int? minKobo;
  final int? maxKobo;

  bool get narrowed =>
      closes != ClosesWithin.any ||
      tiers.isNotEmpty ||
      categories.isNotEmpty ||
      interests.isNotEmpty ||
      minKobo != null ||
      maxKobo != null;

  bool matches(Brief brief, DateTime now) {
    final within = closes.within;
    if (within != null) {
      final left = timeLeft(brief.deadline, now);
      if (left == null || left <= Duration.zero || left > within) return false;
    }
    if (tiers.isNotEmpty && !tiers.contains(brief.tier)) return false;
    if (categories.isNotEmpty && !categories.contains(brief.category)) {
      return false;
    }
    if (interests.isNotEmpty && !interests.contains(brief.interest)) {
      return false;
    }
    final min = minKobo, max = maxKobo;
    if (min != null && brief.rewardPoolKobo < min) return false;
    if (max != null && brief.rewardPoolKobo > max) return false;
    return true;
  }

  TabletFilters copyWith({
    ClosesWithin? closes,
    Set<Tier>? tiers,
    Set<Category>? categories,
    Set<String>? interests,
    int? Function()? minKobo,
    int? Function()? maxKobo,
  }) => TabletFilters(
    closes: closes ?? this.closes,
    tiers: tiers ?? this.tiers,
    categories: categories ?? this.categories,
    interests: interests ?? this.interests,
    minKobo: minKobo == null ? this.minKobo : minKobo(),
    maxKobo: maxKobo == null ? this.maxKobo : maxKobo(),
  );

  /// One chip per applied filter, with what clears it.
  List<(String, TabletFilters)> chips() => [
    for (final t in tiers)
      ('Tier: ${t.label}', copyWith(tiers: {...tiers}..remove(t))),
    if (closes != ClosesWithin.any)
      (closes.chip, copyWith(closes: ClosesWithin.any)),
    for (final c in categories)
      (
        'Category: ${c.label}',
        copyWith(categories: {...categories}..remove(c)),
      ),
    for (final i in interests)
      (filterInterestLabel(i), copyWith(interests: {...interests}..remove(i))),
    if (minKobo != null || maxKobo != null)
      (
        'Reward: ${minKobo == null ? 'any' : rewardPool(minKobo!)} to '
            '${maxKobo == null ? 'any' : rewardPool(maxKobo!)}',
        copyWith(minKobo: () => null, maxKobo: () => null),
      ),
  ];
}

String filterInterestLabel(String value) =>
    Reference.interests
        .where((o) => o.value == value)
        .map((o) => o.label)
        .firstOrNull ??
    value;

class TabletFiltersNotifier extends Notifier<TabletFilters> {
  @override
  TabletFilters build() => const TabletFilters();

  void apply(TabletFilters filters) => state = filters;
}

final tabletFiltersProvider =
    NotifierProvider<TabletFiltersNotifier, TabletFilters>(
      TabletFiltersNotifier.new,
    );

/// The Saved lens on the tablet Discover, which keeps all three lenses on
/// one page.
class SavedLensNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool saved) => state = saved;
}

final tabletSavedLensProvider = NotifierProvider<SavedLensNotifier, bool>(
  SavedLensNotifier.new,
);
