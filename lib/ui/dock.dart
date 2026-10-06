import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';

enum IqDockActive {
  discover('Discover', IqIcons.discover),
  submissions('Submissions', IqIcons.submissions),
  wallet('Wallet', IqIcons.wallet),
  more('More', IqIcons.more);

  const IqDockActive(this.label, this.icon);

  final String label;
  final IqIcons icon;
}

/// Exp/Dock: the floating tab dock, 358 wide, four equal tabs with labels
/// always on. The lit tab is a lighter purple pill with an orange glyph and
/// a white label; the others keep a cream glyph over a 70% label. More is
/// the fourth tab (designer answer 1); Profile now lives inside it.
///
/// Motion (designer doc rev 55, replacing the spec 3.6 slide): a dock
/// switch is instant, pill, colours and glyph at once; a tab change gives
/// the select haptic. Float it 16 pt above the home indicator.
///
/// Figma over brief: the lit tab is a sidebar-accent pill, not an orange disc.
/// Figma over its description: the lit label is primary-fg white, not cream.
/// Figma slip: Active=Discover inks the resting More glyph orange; every
/// other variant rests it cream like its neighbours, which is what this does.
class IqDock extends StatelessWidget {
  const IqDock({
    super.key,
    this.active = IqDockActive.discover,
    this.onChanged,
  });

  final IqDockActive active;
  final ValueChanged<IqDockActive>? onChanged;

  static const double width = 358;
  static const double height = 64;

  @override
  Widget build(BuildContext context) {
    const duration = Duration.zero;
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(IqSpace.s1p5),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: IqColors.brand,
        borderRadius: BorderRadius.circular(32),
        boxShadow: IqShadows.lg,
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          const gap = IqSpace.s0p5;
          final tab = (box.maxWidth - gap * 3) / 4;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: duration,
                curve: IqCurves.easeOut,
                left: active.index * (tab + gap),
                top: 0,
                bottom: 0,
                width: tab,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: IqColors.sidebarAccent,
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final item in IqDockActive.values) ...[
                    if (item.index > 0) const SizedBox(width: gap),
                    SizedBox(
                      width: tab,
                      child: _Tab(
                        item: item,
                        lit: item == active,
                        duration: duration,
                        onTap: onChanged == null
                            ? null
                            : () => onChanged!(item),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.item,
    required this.lit,
    required this.duration,
    this.onTap,
  });

  final IqDockActive item;
  final bool lit;
  final Duration duration;
  final VoidCallback? onTap;

  static final _restLabel = IqColors.sidebarFg.withValues(alpha: 0.7);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: lit,
      child: IqPressable(
        onTap: onTap,
        semanticLabel: item.label,
        haptic: lit ? null : IqHaptics.select,
        builder: (context, pressed) => TweenAnimationBuilder<double>(
          tween: Tween(end: lit ? 1 : 0),
          duration: duration,
          curve: IqCurves.easeOut,
          builder: (context, t, _) => Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: IqSpace.s1,
              vertical: IqSpace.s1p5,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.scale(
                  scale: lit
                      ? IqScale.dockGlyph + (1 - IqScale.dockGlyph) * t
                      : 1,
                  child: IqIcon(
                    item.icon,
                    size: 24,
                    color: Color.lerp(IqColors.sidebarFg, IqColors.accent, t)!,
                  ),
                ),
                const SizedBox(height: IqSpace.s0p5),
                Text(
                  item.label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: IqText.label.copyWith(
                    color: Color.lerp(_restLabel, IqColors.primaryFg, t),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
