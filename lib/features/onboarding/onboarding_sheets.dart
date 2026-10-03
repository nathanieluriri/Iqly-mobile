import 'package:flutter/material.dart';

import '../../data/reference_data.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';
import '../../ui/option_row.dart';
import '../../ui/top_bar.dart';

/// Opens a first-run picker sheet: card fill, 24 top radius, ink scrim at
/// 30%, its top 120 below the top of the screen (Figma 188:8340).
Future<String?> showOnboardingSheet(
  BuildContext context,
  WidgetBuilder builder,
) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    backgroundColor: IqColors.card,
    barrierColor: IqColors.brand.withValues(alpha: 0.3),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    clipBehavior: Clip.antiAlias,
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

/// A short list (state of residence, education): tapping a row picks it.
class OptionSheet extends StatelessWidget {
  const OptionSheet({
    super.key,
    required this.title,
    required this.options,
    this.selected,
  });

  final String title;
  final List<RefOption> options;
  final String? selected;

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
                onTap: () => Navigator.of(context).pop(option.value),
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
  final q = query.trim().toLowerCase();
  final matches = Reference.universities
      .where((u) => q.isEmpty || u.toLowerCase().contains(q))
      .toList();
  final near = [
    for (final entry in universityCampuses.entries)
      if (entry.value.$2 == state && matches.contains(entry.key)) entry.key,
  ];
  return [...near, ...matches.where((u) => !near.contains(u))];
}

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
    final selected = _selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IqTopBar(
          variant: IqTopBarVariant.sheet,
          title: 'University',
          onClose: () => Navigator.of(context).pop(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            IqSpace.s4,
            IqSpace.s1,
            IqSpace.s4,
            0,
          ),
          child: IqField(
            label: 'Search universities…',
            value: '',
            controller: _query,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: (_) => setState(() {}),
          ),
        ),
        if (query.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              IqSpace.s4,
              IqSpace.s3,
              IqSpace.s4,
              0,
            ),
            child: Text(
              '${results.length} ${results.length == 1 ? 'match' : 'matches'}'
                  .toUpperCase(),
              style: IqText.mono.copyWith(color: IqColors.fg2),
            ),
          ),
        Expanded(
          child: results.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(IqSpace.s4),
                  child: Text(
                    'No university found.',
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
                  itemCount: results.length,
                  separatorBuilder: (context, i) =>
                      const SizedBox(height: IqSpace.s1),
                  itemBuilder: (context, i) {
                    final name = results[i];
                    final campus = universityCampuses[name];
                    return IqOptionRow(
                      label: name,
                      note: campus?.$1 ?? '',
                      showNote: campus != null,
                      state: name == selected
                          ? IqOptionRowState.selected
                          : IqOptionRowState.standard,
                      onTap: () => setState(() => _selected = name),
                    );
                  },
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
                IqButton(
                  label: 'Use this',
                  showIcon: false,
                  width: double.infinity,
                  disabled: selected == null,
                  onTap: () => Navigator.of(context).pop(selected),
                ),
                const SizedBox(height: IqSpace.s2),
                IqButton(
                  label: 'Add my university',
                  kind: IqButtonKind.ghost,
                  showIcon: false,
                  width: double.infinity,
                  disabled: query.isEmpty,
                  onTap: () => Navigator.of(context).pop(query),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
