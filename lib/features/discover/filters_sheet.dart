import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/responsive.dart';
import '../../data/models.dart';
import '../../data/reference_data.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';
import '../../ui/top_bar.dart';
import '../onboarding/onboarding_sheets.dart';
import 'discover_routes.dart';
import 'discover_state.dart';

/// The Filters sheet over Discover: an ink scrim at 50%, the card sheet
/// sliding up 0.3 s ease-out (Figma Smart Animate).
Page<void> filtersSheetPage(GoRouterState state) => CustomTransitionPage(
  key: state.pageKey,
  opaque: false,
  barrierDismissible: true,
  barrierColor: IqColors.brand.withValues(alpha: 0.5),
  transitionDuration: const Duration(milliseconds: 300),
  reverseTransitionDuration: const Duration(milliseconds: 300),
  child: const Align(alignment: Alignment.bottomCenter, child: FiltersSheet()),
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return SlideTransition(
      position: Tween(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
      child: child,
    );
  },
);

/// B1 · Discover · Filters sheet (31:397) with the B12 Sort "My interests
/// first" (192:9763). Changes apply on "Show N briefs"; "Clear filters"
/// resets; close keeps what was there.
class FiltersSheet extends ConsumerStatefulWidget {
  const FiltersSheet({super.key});

  static const double height = 542;

  @override
  ConsumerState<FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends ConsumerState<FiltersSheet> {
  late DiscoverFilters _draft = ref.read(discoverFiltersProvider);

  static const _all = 'all';

  Future<void> _pick({
    required String title,
    required List<RefOption> options,
    required String selected,
    required void Function(String value) onPicked,
  }) async {
    final value = await showOnboardingSheet(
      context,
      (context) =>
          OptionSheet(title: title, options: options, selected: selected),
    );
    if (value != null && mounted) setState(() => onPicked(value));
  }

  @override
  Widget build(BuildContext context) {
    final briefs = ref.watch(discoverFeedProvider).value?.briefs ?? const [];
    final count = filterBriefs(briefs, _draft).length;
    final media = MediaQuery.of(context);
    final height = FiltersSheet.height.clamp(
      0.0,
      media.size.height - media.padding.top,
    );

    final statuses = [
      for (final s in BriefStatus.values) RefOption(s.name, s.label),
    ];
    final tiers = [
      const RefOption(_all, 'Standard and Advanced'),
      for (final t in Tier.values) RefOption(t.name, t.label),
    ];
    final categories = [
      const RefOption(_all, 'All categories'),
      for (final c in Category.values) RefOption(c.name, c.label),
    ];
    final sorts = [for (final s in FeedSort.values) RefOption(s.name, s.label)];

    Widget field(
      String label,
      List<RefOption> options,
      String selected,
      void Function(String) onPicked,
    ) => IqField(
      kind: IqFieldKind.picker,
      state: IqFieldState.valid,
      pickerLabel: label,
      pickerValue: options.firstWhere((o) => o.value == selected).label,
      showStatus: false,
      onTap: () => _pick(
        title: label,
        options: options,
        selected: selected,
        onPicked: onPicked,
      ),
    );

    return CenteredContent(
      child: Material(
        color: IqColors.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IqTopBar(
                variant: IqTopBarVariant.sheet,
                title: 'Filters',
                onClose: () => leave(context),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    IqSpace.s4,
                    IqSpace.s2,
                    IqSpace.s4,
                    0,
                  ),
                  children: [
                    field(
                      'Status',
                      statuses,
                      _draft.status.name,
                      (v) => _draft = _draft.copyWith(
                        status: BriefStatus.values.byName(v),
                      ),
                    ),
                    const SizedBox(height: IqSpace.s2),
                    field(
                      'Tier',
                      tiers,
                      _draft.tier?.name ?? _all,
                      (v) => _draft = _draft.copyWith(
                        tier: () => v == _all ? null : Tier.values.byName(v),
                      ),
                    ),
                    const SizedBox(height: IqSpace.s2),
                    field(
                      'Category',
                      categories,
                      _draft.category?.name ?? _all,
                      (v) => _draft = _draft.copyWith(
                        category: () =>
                            v == _all ? null : Category.values.byName(v),
                      ),
                    ),
                    const SizedBox(height: IqSpace.s2),
                    field(
                      'Sort',
                      sorts,
                      _draft.sort.name,
                      (v) => _draft = _draft.copyWith(
                        sort: FeedSort.values.byName(v),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  IqSpace.s4,
                  IqSpace.s4,
                  IqSpace.s4,
                  media.padding.bottom,
                ),
                child: Column(
                  children: [
                    IqButton(
                      label: count == 0
                          ? 'No briefs match'
                          : 'Show $count ${count == 1 ? 'brief' : 'briefs'}',
                      width: double.infinity,
                      disabled: count == 0,
                      onTap: () {
                        ref
                            .read(discoverFiltersProvider.notifier)
                            .apply(_draft);
                        leave(context);
                      },
                    ),
                    const SizedBox(height: IqSpace.s2),
                    IqButton(
                      label: 'Clear filters',
                      kind: IqButtonKind.ghost,
                      showIcon: false,
                      onTap: () {
                        ref
                            .read(discoverFiltersProvider.notifier)
                            .apply(const DiscoverFilters());
                        leave(context);
                      },
                    ),
                    const SizedBox(height: IqSpace.s4),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
