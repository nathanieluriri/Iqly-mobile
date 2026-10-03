import 'package:flutter/material.dart';

import '../../data/reference_data.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';
import '../../ui/option_row.dart';
import '../../ui/top_bar.dart';
import 'onboarding_draft.dart';

/// Opens a first-run picker sheet: card fill, 24 top radius, ink scrim at
/// 30%, its top 120 below the top of the screen (Figma 188:8340). It rises
/// with the platform sheet motion, or appears in place under reduced motion.
Future<T?> showOnboardingSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    backgroundColor: IqColors.card,
    barrierColor: IqColors.brand.withValues(alpha: 0.3),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    clipBehavior: Clip.antiAlias,
    sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (context) {
      final media = MediaQuery.of(context);
      return SizedBox(
        height: media.size.height - _sheetTop,
        child: Padding(
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: builder(context),
        ),
      );
    },
  );
}

const double _sheetTop = 120;

final stateOptions = [for (final s in Reference.states) RefOption(s, s)];

/// A short list (state of residence, education): tapping a row picks it and
/// closes the sheet, unless [onSelected] takes the pick instead.
class OptionSheet extends StatelessWidget {
  const OptionSheet({
    super.key,
    required this.title,
    required this.options,
    this.selected,
    this.onSelected,
  });

  final String title;
  final List<RefOption> options;
  final String? selected;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IqTopBar(
          variant: IqTopBarVariant.sheet,
          title: title,
          onClose: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              IqSpace.s4,
              IqSpace.s1,
              IqSpace.s4,
              IqSpace.s4,
            ),
            itemCount: options.length,
            separatorBuilder: (context, i) =>
                const SizedBox(height: IqSpace.s1),
            itemBuilder: (context, i) {
              final option = options[i];
              return IqOptionRow(
                label: option.label,
                showNote: false,
                state: option.value == selected
                    ? IqOptionRowState.selected
                    : IqOptionRowState.standard,
                onTap: () => onSelected == null
                    ? Navigator.of(context).pop(option.value)
                    : onSelected!(option.value),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Campus notes for the near-you group, from the Figma sheet. reference.ts
/// has names only, so universities without a note here sort after it.
const universityCampuses = {
  'University of Lagos': ('Akoka, Lagos', 'Lagos'),
  'Lagos State University': ('Ojo, Lagos', 'Lagos'),
  'Lagos State University of Science and Technology': (
    'Ikorodu, Lagos',
    'Lagos',
  ),
  'James Hope University, Lagos': ('Lekki, Lagos', 'Lagos'),
};

/// Universities matching [query], the ones in [state] first.
List<String> searchUniversities(String query, {String? state}) {
  final matches = _matching(Reference.universities, query);
  final near = [
    for (final entry in universityCampuses.entries)
      if (entry.value.$2 == state && matches.contains(entry.key)) entry.key,
  ];
  return [...near, ...matches.where((u) => !near.contains(u))];
}

/// [state]'s cities matching [query], in list order (capital first). Matches
/// ignore spacing and punctuation and include alternate spellings.
List<String> searchCities(String state, String query) {
  final q = placeKey(query);
  return [
    for (final city in Reference.cities[state] ?? const <String>[])
      if (q.isEmpty || placeSpellings(city).any((s) => s.contains(q))) city,
  ];
}

List<String> _matching(List<String> names, String query) {
  final q = query.trim().toLowerCase();
  return names.where((n) => q.isEmpty || n.toLowerCase().contains(q)).toList();
}

String _count(int n, String one, String many) =>
    '$n ${n == 1 ? one : many}'.toUpperCase();

/// B11 · Step 2 · University search (188:8340).
class UniversitySheet extends StatefulWidget {
  const UniversitySheet({
    super.key,
    this.selected,
    this.state,
    this.initialQuery = '',
  });

  final String? selected;
  final String? state;
  final String initialQuery;

  @override
  State<UniversitySheet> createState() => _UniversitySheetState();
}

class _UniversitySheetState extends State<UniversitySheet> {
  late final _query = TextEditingController(text: widget.initialQuery);
  late String? _selected = widget.selected;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.text.trim();
    final results = searchUniversities(query, state: widget.state);
    final selected = results.contains(_selected) ? _selected : null;
    return _SearchSheetLayout(
      title: 'University',
      search: IqField(
        label: 'Search universities…',
        value: '',
        controller: _query,
        autofocus: true,
        textInputAction: TextInputAction.search,
        onChanged: (_) => setState(() {}),
      ),
      count: query.isEmpty || results.isEmpty
          ? null
          : _count(results.length, 'match', 'matches'),
      empty: 'No university found.',
      rows: [
        for (final name in results)
          IqOptionRow(
            label: name,
            note: universityCampuses[name]?.$1 ?? '',
            showNote: universityCampuses.containsKey(name),
            state: name == selected
                ? IqOptionRowState.selected
                : IqOptionRowState.standard,
            onTap: () => setState(() => _selected = name),
          ),
      ],
      actions: [
        IqButton(
          label: 'Use this',
          showIcon: false,
          width: double.infinity,
          disabled: selected == null,
          onTap: () => Navigator.of(context).pop(selected),
        ),
        IqButton(
          label: 'Add my university',
          kind: IqButtonKind.ghost,
          showIcon: false,
          width: double.infinity,
          disabled: query.isEmpty,
          onTap: () => Navigator.of(context).pop(query),
        ),
      ],
    );
  }
}

/// The city search for [state], built like the university search. "Add
/// mine" offers the typed name when the list does not have it.
class CitySheet extends StatefulWidget {
  const CitySheet({super.key, required this.state, this.selected});

  final String state;

  /// The current city when [state]'s list has it.
  final String? selected;

  @override
  State<CitySheet> createState() => _CitySheetState();
}

class _CitySheetState extends State<CitySheet> {
  final _query = TextEditingController();
  late String? _selected = widget.selected;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final results = searchCities(widget.state, query);
    final selected = results.contains(_selected) ? _selected : null;
    final canAdd = query.isNotEmpty && listedCity(widget.state, query) == null;
    return _SearchSheetLayout(
      title: 'City',
      search: IqField(
        label: 'Search cities',
        value: '',
        controller: _query,
        textInputAction: TextInputAction.search,
        onChanged: (_) => setState(() {}),
      ),
      count: results.isEmpty
          ? null
          : query.isEmpty
          ? _count(results.length, 'city', 'cities')
          : _count(results.length, 'match', 'matches'),
      empty: 'No city found.',
      rows: [
        for (final name in results)
          IqOptionRow(
            label: name,
            showNote: false,
            state: name == selected
                ? IqOptionRowState.selected
                : IqOptionRowState.standard,
            onTap: () => setState(() => _selected = name),
          ),
      ],
      actions: [
        IqButton(
          label: 'Use this',
          showIcon: false,
          width: double.infinity,
          disabled: selected == null,
          onTap: () => Navigator.of(context).pop(selected),
        ),
        if (canAdd)
          IqButton(
            label: 'Add mine',
            kind: IqButtonKind.ghost,
            showIcon: false,
            width: double.infinity,
            onTap: () => Navigator.of(context).pop(query),
          ),
      ],
    );
  }
}

/// City picking from the CITY field. With no state yet, the sheet asks for
/// the state first (saved through [onState] as soon as it is picked), then
/// crossfades straight on to that state's cities. Pops with the city.
class CityPickerFlow extends StatefulWidget {
  const CityPickerFlow({
    super.key,
    required this.state,
    required this.city,
    required this.onState,
  });

  final String? state;
  final String city;
  final ValueChanged<String> onState;

  @override
  State<CityPickerFlow> createState() => _CityPickerFlowState();
}

class _CityPickerFlowState extends State<CityPickerFlow> {
  late String? _state = widget.state;

  void _pickState(String state) {
    widget.onState(state);
    setState(() => _state = state);
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeOut,
      child: state == null
          ? OptionSheet(
              key: const ValueKey('state'),
              title: 'State of residence',
              options: stateOptions,
              onSelected: _pickState,
            )
          : CitySheet(
              key: ValueKey(state),
              state: state,
              selected: listedCity(state, widget.city),
            ),
    );
  }
}

/// Title, search field, count line, results and the foot actions shared by
/// the university and city sheets.
class _SearchSheetLayout extends StatelessWidget {
  const _SearchSheetLayout({
    required this.title,
    required this.search,
    required this.count,
    required this.empty,
    required this.rows,
    required this.actions,
  });

  final String title;
  final Widget search;
  final String? count;
  final String empty;
  final List<Widget> rows;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final count = this.count;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IqTopBar(
          variant: IqTopBarVariant.sheet,
          title: title,
          onClose: () => Navigator.of(context).pop(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            IqSpace.s4,
            IqSpace.s1,
            IqSpace.s4,
            0,
          ),
          child: search,
        ),
        if (count != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              IqSpace.s4,
              IqSpace.s3,
              IqSpace.s4,
              0,
            ),
            child: Text(
              count,
              style: IqText.mono.copyWith(color: IqColors.fg2),
            ),
          ),
        Expanded(
          child: rows.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(IqSpace.s4),
                  child: Text(
                    empty,
                    style: IqText.body.copyWith(color: IqColors.fg2),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    IqSpace.s4,
                    IqSpace.s3,
                    IqSpace.s4,
                    IqSpace.s4,
                  ),
                  itemCount: rows.length,
                  separatorBuilder: (context, i) =>
                      const SizedBox(height: IqSpace.s1),
                  itemBuilder: (context, i) => rows[i],
                ),
        ),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: IqSpace.s3),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              IqSpace.s4,
              IqSpace.s3,
              IqSpace.s4,
              0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(height: IqSpace.s2),
                  actions[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
