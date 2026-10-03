import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';
import 'vector.dart';

enum IqBookmarkState { off, on }

enum IqBookmarkTone { paper, ink }

/// Exp/Bookmark: save a brief. A 44 x 44 tap target around the 22 px brush
/// bookmark. Paper on light cards, Ink on the dark hero ticket. On is the
/// orange marker fill under an orange outline (saved, not a warning) and
/// is the same in both tones. Tapping flips [state] through [onChanged]
/// with the select haptic.
///
/// Figma over brief: the bookmark icon is stroked and recoloured via its stroke.
/// Figma over brief: the Ink outline is Color/sidebar-fg.
class IqBookmark extends StatelessWidget {
  const IqBookmark({
    super.key,
    this.state = IqBookmarkState.off,
    this.tone = IqBookmarkTone.paper,
    this.onChanged,
  });

  final IqBookmarkState state;
  final IqBookmarkTone tone;
  final ValueChanged<IqBookmarkState>? onChanged;

  @override
  Widget build(BuildContext context) {
    final on = state == IqBookmarkState.on;
    final onChanged = this.onChanged;
    return Semantics(
      toggled: on,
      child: IqPressable(
        semanticLabel: on ? 'Saved' : 'Save',
        haptic: IqHaptics.select,
        onTap: onChanged == null
            ? null
            : () => onChanged(on ? IqBookmarkState.off : IqBookmarkState.on),
        builder: (context, pressed) => SizedBox.square(
          dimension: 44,
          child: Stack(
            children: [
              if (on)
                const Positioned(
                  left: 17.42,
                  top: 14.67,
                  width: 10,
                  height: 15,
                  child: IqVector(
                    'assets/vectors/bookmark-marker.svg',
                    color: IqColors.accent,
                  ),
                ),
              Positioned(
                left: 11,
                top: 11,
                child: IqIcon(
                  IqIcons.bookmark,
                  size: 22,
                  color: on
                      ? IqColors.accent
                      : tone == IqBookmarkTone.ink
                      ? IqColors.sidebarFg
                      : IqColors.brand,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
