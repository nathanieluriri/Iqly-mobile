import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/transitions.dart';
import '../../theme/theme.dart';
import '../../ui/avatar.dart';
import '../../ui/avatar_art.dart';
import '../../ui/avatar_option_tile.dart';
import '../../ui/avatar_part_tab.dart';
import '../../ui/avatar_swatch.dart';
import '../../ui/button.dart';
import '../../ui/confirm_sheet.dart';
import '../../ui/icon.dart';
import '../more/more_widgets.dart';
import 'avatar_state.dart';

/// The editor's tabs, in the Figma order (B22 · Avatar · Skin to
/// Background).
enum AvatarTab {
  skin(IqIcons.skin, 'Skin'),
  face(IqIcons.face, 'Face'),
  hair(IqIcons.hair, 'Hair'),
  facialHair(IqIcons.beard, 'Facial hair'),
  glasses(IqIcons.glasses, 'Glasses'),
  headwear(IqIcons.hat, 'Headwear'),
  clothes(IqIcons.shirt, 'Clothes'),
  background(IqIcons.background, 'Background');

  const AvatarTab(this.icon, this.label);
  final IqIcons icon;
  final String label;
}

/// B22 · Avatar (578:25922 to 581:27889): the big preview on the person's
/// background, the eight part tabs, then the part's swatches and option
/// tiles, each tile the person's own avatar with that option. Save avatar
/// saves and goes back; Back with unsaved changes asks first (Discard
/// changes?, 582:27615).
///
/// Motion (DS/Note Exp/Avatar): a swatch or option swaps the part on the
/// preview with a 160 ms pop, scale 0.96 to 1 ease-out; the background
/// eases to its new colour over the same 160 ms. Reduced motion: no pop.
class AvatarEditorScreen extends ConsumerStatefulWidget {
  const AvatarEditorScreen({super.key, this.initialTab = AvatarTab.skin});

  final AvatarTab initialTab;

  @override
  ConsumerState<AvatarEditorScreen> createState() => _AvatarEditorState();
}

class _AvatarEditorState extends ConsumerState<AvatarEditorScreen>
    with SingleTickerProviderStateMixin {
  late final IqAvatarLook _initial = ref.read(avatarProvider).look;
  late IqAvatarLook _look = _initial;
  late AvatarTab _tab = widget.initialTab;
  Set<IqAvatarPart> _popping = const {};
  bool _leaving = false;

  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: IqDurations.tick,
  );

  bool get _dirty => _look != _initial;

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  void _set(IqAvatarLook next) {
    if (next == _look) return;
    final changed = changedParts(_look, next);
    setState(() {
      _look = next;
      _popping = changed;
    });
    if (changed.isNotEmpty && !MediaQuery.disableAnimationsOf(context)) {
      _pop.forward(from: 0);
    }
  }

  Future<void> _save() async {
    if (_leaving) return;
    _leaving = true;
    await ref.read(avatarProvider.notifier).choose(IqPersonAvatar(_look));
    if (mounted) context.pop(true);
  }

  Future<void> _back() async {
    if (_leaving) return;
    if (!_dirty) {
      _leaving = true;
      context.pop(false);
      return;
    }
    final discard = await showIqConfirmSheet(
      Navigator.of(context, rootNavigator: true).context,
      title: 'Discard changes?',
      body:
          'Your avatar edits won’t be saved. Your current avatar stays as it '
          'is.',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep editing',
      scrim: IqScrim.fg,
    );
    if (!discard || !mounted) return;
    _leaving = true;
    context.pop(false);
  }

  Map<IqAvatarPart, double> get _scales {
    if (_popping.isEmpty || !_pop.isAnimating) return const {};
    final t = IqCurves.easeOut.transform(_pop.value);
    final scale = lerpDouble(IqScale.partSwap, 1, t)!;
    return {for (final part in _popping) part: scale};
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty || _leaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: SubPage(
        title: 'Edit avatar',
        hasFields: false,
        onBack: _back,
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: IqSpace.s1),
              AnimatedContainer(
                duration: motion(context, IqDurations.tick),
                curve: IqCurves.easeOut,
                height: 188,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: _look.background,
                  borderRadius: BorderRadius.circular(28),
                ),
                alignment: Alignment.topCenter,
                child: AnimatedBuilder(
                  animation: _pop,
                  builder: (context, _) => IqAvatarCharacter(
                    look: _look,
                    size: 188,
                    showBackground: false,
                    scales: _scales,
                  ),
                ),
              ),
              const SizedBox(height: IqSpace.s4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final tab in AvatarTab.values)
                    IqAvatarPartTab(
                      icon: tab.icon,
                      width: 44,
                      height: 44,
                      semanticLabel: tab.label,
                      state: tab == _tab
                          ? IqAvatarPartTabState.selected
                          : IqAvatarPartTabState.standard,
                      onTap: () => setState(() => _tab = tab),
                    ),
                ],
              ),
              const SizedBox(height: IqSpace.s4),
              Expanded(
                child: AnimatedSwitcher(
                  duration: motion(context, IqDurations.crossfade),
                  child: ListView(
                    key: ValueKey(_tab),
                    padding: const EdgeInsets.only(bottom: IqSpace.s6),
                    children: [
                      for (final (i, section) in _sections().indexed) ...[
                        if (i > 0) const SizedBox(height: IqSpace.s5),
                        section,
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          IqButton(
            label: 'Save avatar',
            showIcon: false,
            width: double.infinity,
            onTap: _save,
          ),
        ],
      ),
    );
  }

  List<Widget> _sections() {
    final look = _look;
    return switch (_tab) {
      AvatarTab.skin => [
        _swatches(
          'Skin tone',
          IqAvatarColors.skin,
          IqAvatarColors.skinLabels,
          look.skin,
          (i) => look.copyWith(skin: i),
        ),
      ],
      AvatarTab.face => [
        _swatches(
          'Eye colour',
          IqAvatarColors.eye,
          IqAvatarColors.eyeLabels,
          look.eye,
          (i) => look.copyWith(eye: i),
        ),
        _tiles(
          'Expression',
          IqAvatarExpression.values,
          look.expression,
          (e) => look.copyWith(expression: e),
          label: (e) => e.figma,
        ),
      ],
      AvatarTab.hair => [
        _swatches(
          'Hair colour',
          IqAvatarColors.hair,
          IqAvatarColors.hairLabels,
          look.hair,
          (i) => look.copyWith(hair: i),
        ),
        _tiles(
          'Style',
          IqAvatarHairStyle.values,
          look.hairStyle,
          (s) => look.copyWith(hairStyle: s),
          label: (s) => s.figma,
        ),
      ],
      AvatarTab.facialHair => [
        _swatches(
          'Colour',
          IqAvatarColors.hair,
          IqAvatarColors.hairLabels,
          look.facialHairColour,
          (i) => look.copyWith(facialHairColour: i),
        ),
        _tiles(
          'Style',
          IqAvatarFacialHairStyle.values,
          look.facialHair,
          (s) => look.copyWith(facialHair: s),
          label: (s) => s.figma,
          none: IqAvatarFacialHairStyle.none,
        ),
      ],
      AvatarTab.glasses => [
        _tiles(
          'Style',
          IqAvatarGlassesStyle.values,
          look.glasses,
          (s) => look.copyWith(glasses: s),
          label: (s) => s.figma,
          none: IqAvatarGlassesStyle.none,
        ),
      ],
      AvatarTab.headwear => [
        _swatches(
          'Colour',
          IqAvatarColors.cloth,
          IqAvatarColors.clothLabels,
          look.headwearColour,
          (i) => look.copyWith(headwearColour: i),
        ),
        _tiles(
          'Style',
          IqAvatarHeadwearStyle.values,
          look.headwear,
          (s) => look.copyWith(headwear: s),
          label: (s) => s.figma,
          none: IqAvatarHeadwearStyle.none,
        ),
      ],
      AvatarTab.clothes => [
        _swatches(
          'Colour',
          IqAvatarColors.cloth,
          IqAvatarColors.clothLabels,
          look.cloth,
          (i) => look.copyWith(cloth: i),
        ),
        _tiles(
          'Style',
          IqAvatarBodyStyle.values,
          look.body,
          (s) => look.copyWith(body: s),
          label: (s) => s.figma,
        ),
      ],
      AvatarTab.background => [
        _swatches(
          'Background',
          IqAvatarColors.bg,
          IqAvatarColors.bgLabels,
          look.bg,
          (i) => look.copyWith(bg: i),
        ),
      ],
    };
  }

  Widget _section(String title, Widget body) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        header: true,
        child: Text(
          title,
          style: IqText.cardTitle.copyWith(color: IqColors.fg),
        ),
      ),
      const SizedBox(height: IqSpace.s2p5),
      body,
    ],
  );

  /// [selected] and the swatch numbers count from 1, as the variables do.
  Widget _swatches(
    String title,
    List<Color> colours,
    List<String> labels,
    int selected,
    IqAvatarLook Function(int number) apply,
  ) => _section(
    title,
    Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        for (final (i, colour) in colours.indexed)
          IqAvatarSwatch(
            colour: colour,
            semanticLabel: labels[i],
            state: i + 1 == selected
                ? IqAvatarSwatchState.selected
                : IqAvatarSwatchState.standard,
            onTap: () => _set(apply(i + 1)),
          ),
      ],
    ),
  );

  Widget _tiles<T>(
    String title,
    List<T> options,
    T selected,
    IqAvatarLook Function(T option) apply, {
    required String Function(T option) label,
    T? none,
  }) => _section(
    title,
    Wrap(
      spacing: 29,
      runSpacing: IqSpace.s4,
      children: [
        for (final option in options)
          IqAvatarOptionTile(
            look: apply(option),
            none: option == none,
            semanticLabel: label(option),
            state: option == selected
                ? IqAvatarOptionTileState.selected
                : IqAvatarOptionTileState.standard,
            onTap: () => _set(apply(option)),
          ),
      ],
    ),
  );
}

/// The parts that look different in [next]: a swapped style, or a colour
/// the part paints with.
Set<IqAvatarPart> changedParts(IqAvatarLook before, IqAvatarLook next) {
  final was = before.colours;
  final now = next.colours;
  final recoloured = {
    for (final slot in now.keys)
      if (was[slot] != now[slot]) slot,
  };
  return {
    for (final part in IqAvatarPart.values)
      if (!identical(part.art(before), part.art(next)) ||
          _slotsOf(part.art(next)).any(recoloured.contains))
        part,
  };
}

final _slots = Expando<Set<String>>();

Set<String> _slotsOf(List<AvatarNode> layer) {
  if (layer.isEmpty) return const {};
  return _slots[layer] ??= {
    for (final node in layer)
      ...switch (node) {
        AvatarShape(:final slot) => {slot},
        AvatarGroup(:final children) => _slotsOf(children),
      },
  };
}
