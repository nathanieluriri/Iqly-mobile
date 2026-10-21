import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation.dart';
import '../../data/reference_data.dart';
import '../../theme/theme.dart';
import '../../ui/avatar.dart';
import '../../ui/button.dart';
import '../../ui/icon.dart';
import '../../ui/pressable.dart';
import '../avatar/avatar_state.dart';
import '../avatar/choose_avatar.dart';
import '../entry/entry_widgets.dart' show EntryLink;
import '../more/more_state.dart';
import '../onboarding/gender_screen.dart' show genderHelp;
import '../onboarding/onboarding_draft.dart';
import '../profile/profile_routes.dart';
import '../profile/profile_state.dart';
import '../profile/your_details_screen.dart';
import '../shell/tablet_sheet.dart';

/// T15 · Settings · Your details (Mobile App · tablet, 1852:63238 and
/// 1852:59892): the profile header with Change your avatar, the heading
/// and the email line over the details as a key and value table. A row
/// opens its Edit page; Gender opens in place as three radios with Cancel
/// and Save. Portrait stacks the radios and lets a long value wrap.
class TabletYourDetails extends ConsumerStatefulWidget {
  const TabletYourDetails({super.key});

  @override
  ConsumerState<TabletYourDetails> createState() => _TabletYourDetailsState();
}

class _TabletYourDetailsState extends ConsumerState<TabletYourDetails> {
  bool _editing = false;
  String? _choice;
  bool _saving = false;

  Future<void> _save(String? held) async {
    final choice = _choice ?? held;
    if (_saving || choice == null) return;
    setState(() => _saving = true);
    try {
      await saveProfile(
        ref,
        details: (d) => d.copyWith(gender: choice),
        answers: (a) => a.copyWith(gender: choice),
      );
    } on Exception {
      if (mounted) setState(() => _saving = false);
      return;
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _editing = false;
      _choice = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final details = ref.watch(accountDetailsProvider).value;
    final answers = ref.watch(profileAnswersProvider);
    final pass = ref.watch(contributorPassProvider).value;
    final name = ref.watch(accountNameProvider) ?? pass?.user.name ?? '';
    final avatar = ref.watch(avatarProvider.select((a) => a.spec));
    final held = profileGender(details, answers);
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 600;
        final rows = [
          for (final field in DetailField.values)
            if (detailShown(field, answers))
              field == DetailField.gender && _editing
                  ? _GenderBlock(
                      picked: _choice ?? held,
                      wide: wide,
                      saving: _saving,
                      onPick: (value) => setState(() => _choice = value),
                      onCancel: () => setState(() {
                        _editing = false;
                        _choice = null;
                      }),
                      onSave: () => _save(held),
                    )
                  : _Row(
                      label: field.label,
                      value: detailValue(field, details, answers),
                      wide: wide,
                      onTap: field == DetailField.gender
                          ? () => setState(() => _editing = true)
                          : () => context.open(editDetailPath(field)),
                    ),
        ];
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: IqSpace.s8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(IqRadius.sm),
                    child: ColoredBox(
                      color: IqColors.tintStrong,
                      child: IqAvatar(avatar, size: 64),
                    ),
                  ),
                  const SizedBox(width: IqSpace.s4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: IqText.title.copyWith(color: IqColors.fg),
                        ),
                        Text(
                          pass?.user.email ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: IqText.body.copyWith(color: IqColors.fg3),
                        ),
                      ],
                    ),
                  ),
                  EntryLink(
                    label: 'Change your avatar',
                    onTap: () => chooseAvatar(context),
                  ),
                ],
              ),
              const SizedBox(height: IqSpace.s6),
              Text(
                'Your details',
                style: IqText.title.copyWith(color: IqColors.fg),
              ),
              const SizedBox(height: IqSpace.s1),
              Text(
                'Your email stays as your sign-in.',
                style: IqText.small.copyWith(color: IqColors.fg2),
              ),
              const SizedBox(height: IqSpace.s6),
              TabletCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, row) in rows.indexed) ...[
                      if (i > 0)
                        const SizedBox(
                          height: 1,
                          child: ColoredBox(color: IqColors.line),
                        ),
                      row,
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    required this.wide,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool wide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IqPressable(
      onTap: onTap,
      tactile: false,
      semanticLabel: '$label, $value',
      builder: (context, pressed) => ColoredBox(
        color: pressed ? IqColors.secondary : IqColors.card,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 50),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: IqSpace.s5,
              vertical: IqSpace.s3,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: wide ? 196 : 180,
                  child: Text(
                    label,
                    style: IqText.body.copyWith(color: IqColors.fg2),
                  ),
                ),
                Expanded(
                  child: Text(
                    value,
                    maxLines: wide ? 1 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: IqText.body.copyWith(color: IqColors.fg),
                  ),
                ),
                const SizedBox(width: IqSpace.s3),
                const IqIcon(IqIcons.forward, size: 16, color: IqColors.fg3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GenderBlock extends StatelessWidget {
  const _GenderBlock({
    required this.picked,
    required this.wide,
    required this.saving,
    required this.onPick,
    required this.onCancel,
    required this.onSave,
  });

  final String? picked;
  final bool wide;
  final bool saving;
  final ValueChanged<String> onPick;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final radios = [
      for (final option in Reference.genders)
        _Radio(
          label: option.label,
          selected: option.value == picked,
          onTap: () => onPick(option.value),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        IqSpace.s5,
        IqSpace.s4,
        IqSpace.s5,
        IqSpace.s5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            DetailField.gender.label,
            style: IqText.body.copyWith(color: IqColors.fg),
          ),
          const SizedBox(height: IqSpace.s3),
          if (wide)
            Row(
              children: [
                for (final (i, radio) in radios.indexed) ...[
                  if (i > 0) const SizedBox(width: IqSpace.s2),
                  Expanded(child: radio),
                ],
              ],
            )
          else
            for (final (i, radio) in radios.indexed) ...[
              if (i > 0) const SizedBox(height: IqSpace.s2),
              radio,
            ],
          const SizedBox(height: IqSpace.s3),
          Text(genderHelp, style: IqText.small.copyWith(color: IqColors.fg3)),
          const SizedBox(height: IqSpace.s3),
          Row(
            children: [
              IqButton(
                label: 'Cancel',
                kind: IqButtonKind.ghost,
                showIcon: false,
                width: 120,
                onTap: onCancel,
              ),
              const SizedBox(width: IqSpace.s2),
              IqButton(
                label: 'Save',
                showIcon: false,
                width: 120,
                loading: saving,
                onTap: onSave,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: IqPressable(
        onTap: onTap,
        semanticLabel: label,
        builder: (context, pressed) => Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: IqSpace.s3),
          decoration: BoxDecoration(
            color: pressed ? IqColors.secondary : IqColors.card,
            borderRadius: BorderRadius.circular(IqRadius.sm),
            border: Border.all(color: IqColors.line),
          ),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? IqColors.primary : IqColors.fg3,
                    width: selected ? 5 : 1,
                  ),
                ),
              ),
              const SizedBox(width: IqSpace.s2p5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: IqText.body.copyWith(color: IqColors.fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
