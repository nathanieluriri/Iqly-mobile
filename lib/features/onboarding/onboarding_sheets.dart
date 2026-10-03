import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/motion.dart';
import '../../core/transitions.dart';
import '../../data/reference_data.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';
import '../../ui/option_row.dart';
import '../../ui/top_bar.dart';
import 'onboarding_draft.dart';

/// Opens a first-run picker sheet: card fill, 24 top radius, ink scrim at
/// 30%, its top 120 below the top of the screen (Figma 188:8340). It rises
/// and drops on the one sheet route (spec 3.3), fading in place under
/// reduced motion. With [hug] the sheet is as tall as its content and no
/// taller than that; otherwise it takes the full height.
///
/// The future completes once the sheet has dropped, so the picked value
/// lands on the step after it (spec 6.15); under reduced motion it
/// completes as the sheet starts to fade.
Future<T?> showOnboardingSheet<T>(
  BuildContext context,
  WidgetBuilder builder, {
  bool hug = false,
}) async {
  final reduced = MediaQuery.disableAnimationsOf(context);
  final route = IqSheetRoute<T>(
    scrim: IqScrim.picker,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    builder: (context) {
      final height = MediaQuery.sizeOf(context).height - _sheetTop;
      return MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Material(
          color: IqColors.card,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          clipBehavior: Clip.antiAlias,
          child: hug
              ? ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: double.infinity,
                    maxHeight: height,
                  ),
                  child: builder(context),
                )
              : SizedBox(
                  width: double.infinity,
                  height: height,
                  child: builder(context),
                ),
        ),
      );
    },
  );
  final value = await Navigator.of(context).push(route);
  if (!reduced) await route.completed;
  return value;
}

const double _sheetTop = 120;

final stateOptions = [for (final s in Reference.states) RefOption(s, s)];

/// A list of options (state of residence, education): tapping a row picks
/// it and closes the sheet 120 ms later, unless [onSelected] takes the pick
/// instead; the sheet ignores taps in between (spec 3.3). It is as tall as
/// its rows, scrolling once they outgrow the sheet.
class OptionSheet extends StatefulWidget {
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
  State<OptionSheet> createState() => _OptionSheetState();
}

class _OptionSheetState extends State<OptionSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _beat = AnimationController(vsync: this);
  String? _picked;

  void _pick(String value) {
    if (_picked != null) return;
    setState(() => _picked = value);
    void done() {
      if (!mounted) return;
      final onSelected = widget.onSelected;
      onSelected == null ? Navigator.of(context).pop(value) : onSelected(value);
    }

    final chain = motion(context, IqDurations.chain);
    if (chain == Duration.zero) {
      done();
    } else {
      _beat.duration = chain;
      _beat.forward().then((_) => done());
    }
  }

  @override
  void dispose() {
    _beat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.options;
    final selected = _picked ?? widget.selected;
    final bottom = IqSpace.s4 + MediaQuery.paddingOf(context).bottom;
    final rows =
        IqOptionRow.height * options.length + IqSpace.s1 * (options.length - 1);
    final height = _topBar + IqSpace.s1 + rows + bottom;
    return IgnorePointer(
      ignoring: _picked != null,
      child: LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          height: math.min(height, constraints.maxHeight),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IqTopBar(
                variant: IqTopBarVariant.sheet,
                title: widget.title,
                onClose: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    IqSpace.s4,
                    IqSpace.s1,
                    IqSpace.s4,
                    bottom,
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
                      onTap: () => _pick(option.value),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The sheet variant of Exp/TopBar.
  static const double _topBar = 76;
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
  'Lagos State University of Education': ('Ijanikin, Lagos', 'Lagos'),
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

/// B11 · Step 2 · University search (188:8340). The search field takes the
/// keyboard once the sheet has risen; picking a row selects it and puts the
/// keyboard away so "Use this" shows (the Figma frame is that moment).
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
  final _focus = FocusNode();
  late String? _selected = widget.selected;
  bool _asked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_asked) return;
    _asked = true;
    whenArrived(context, () {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _pick(String name) {
    _putKeyboardAway();
    setState(() => _selected = name);
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
        focusNode: _focus,
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
            onTap: () => _pick(name),
          ),
      ],
      use: IqButton(
        label: 'Use this',
        showIcon: false,
        width: double.infinity,
        disabled: selected == null,
        onTap: () => Navigator.of(context).pop(selected),
      ),
      add: IqButton(
        label: 'Add my university',
        kind: IqButtonKind.ghost,
        showIcon: false,
        width: double.infinity,
        disabled: query.isEmpty,
        onTap: () => Navigator.of(context).pop(query),
      ),
    );
  }
}

/// The city search for [state], built like the university search. "Add my
/// city" (Figma's "Add my university" pattern) offers the typed name when
/// the list does not have it, and stays in place, off, otherwise.
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
  final _focus = FocusNode();
  late String? _selected = widget.selected;
  bool _asked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_asked) return;
    _asked = true;
    whenArrived(context, () {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _pick(String name) {
    _putKeyboardAway();
    setState(() => _selected = name);
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
        focusNode: _focus,
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
            onTap: () => _pick(name),
          ),
      ],
      use: IqButton(
        label: 'Use this',
        showIcon: false,
        width: double.infinity,
        disabled: selected == null,
        onTap: () => Navigator.of(context).pop(selected),
      ),
      add: IqButton(
        label: 'Add my city',
        kind: IqButtonKind.ghost,
        showIcon: false,
        width: double.infinity,
        disabled: !canAdd,
        onTap: () => Navigator.of(context).pop(query),
      ),
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
      duration: motion(context, IqDurations.swap),
      switchInCurve: IqCurves.easeOut,
      switchOutCurve: IqCurves.easeOut,
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

/// A pick puts the keyboard away so "Use this" shows, the search field
/// keeping its focus and its Active look (Figma 188:8340); a tap on the field
/// brings the keyboard back.
void _putKeyboardAway() =>
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');

/// Title, search field, count line, results and the foot actions shared by
/// the university and city sheets. The foot (primary at y 720, ghost at y
/// 780 in Figma 188:8340) stays at the bottom of the sheet, under the
/// keyboard while it is up; the results take the room above the keyboard
/// and dragging them puts the keyboard away. The count rolls as it changes
/// and an empty result fades in (spec 6.15).
class _SearchSheetLayout extends StatelessWidget {
  const _SearchSheetLayout({
    required this.title,
    required this.search,
    required this.count,
    required this.empty,
    required this.rows,
    required this.use,
    required this.add,
  });

  final String title;
  final Widget search;
  final String? count;
  final String empty;
  final List<Widget> rows;
  final Widget use;
  final Widget add;

  @override
  Widget build(BuildContext context) {
    final count = this.count;
    final bottom = math.max(MediaQuery.paddingOf(context).bottom, IqSpace.s3);
    const footTop = IqSpace.s3;
    final foot = footTop + IqButton.height * 2 + IqSpace.s2 + bottom;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
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
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: RollingText(
                count,
                style: IqText.mono.copyWith(color: IqColors.fg2),
              ),
            ),
          ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: math.max(0, keyboard - foot)),
            child: AnimatedSwitcher(
              duration: motion(context, IqDurations.crossfade),
              switchInCurve: IqCurves.easeOut,
              switchOutCurve: IqCurves.easeOut,
              layoutBuilder: (current, previous) => Stack(
                fit: StackFit.expand,
                children: [...previous, ?current],
              ),
              child: rows.isEmpty
                  ? Padding(
                      key: const ValueKey('empty'),
                      padding: const EdgeInsets.all(IqSpace.s4),
                      child: Align(
                        alignment: AlignmentDirectional.topStart,
                        child: Text(
                          empty,
                          style: IqText.body.copyWith(color: IqColors.fg2),
                        ),
                      ),
                    )
                  : ListView.separated(
                      key: const ValueKey('rows'),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
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
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(IqSpace.s4, footTop, IqSpace.s4, bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              use,
              const SizedBox(height: IqSpace.s2),
              add,
            ],
          ),
        ),
      ],
    );
  }
}
