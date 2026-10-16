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
/// Motion (spec 5.12, build extension): the icon presses to .9 (100 ms, back
/// in 160). When the person saves, the outline inks orange (120 ms) and the
/// marker drops into the page top to bottom (240 ms ease-out); unsaving fades
/// the marker (150 ms ease-in) as the outline returns. A state that arrives
/// from data, not a tap, shows at once. Reduced motion: colours and fill at
/// once, no press scale.
///
/// Figma over brief: the bookmark icon is stroked and recoloured via its stroke.
/// Figma over brief: the Ink outline is Color/sidebar-fg.
class IqBookmark extends StatefulWidget {
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
  State<IqBookmark> createState() => _IqBookmarkState();
}

class _IqBookmarkState extends State<IqBookmark> with TickerProviderStateMixin {
  late final AnimationController _drop = AnimationController(
    vsync: this,
    duration: IqDurations.mark,
    value: _on ? 1 : 0,
  );
  late final Animation<double> _reveal = _drop.drive(
    CurveTween(curve: IqCurves.easeOut),
  );
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: IqDurations.crossfade,
    value: _on ? 1 : 0,
  );
  // Only ever reversed, so the ease-out reads as an ease-in exit.
  late final Animation<double> _opacity = _fade.drive(
    CurveTween(curve: IqCurves.easeOut),
  );
  bool _flipped = false;
  Duration _ink = Duration.zero;

  bool get _on => widget.state == IqBookmarkState.on;

  @override
  void didUpdateWidget(IqBookmark old) {
    super.didUpdateWidget(old);
    if (old.state == widget.state) return;
    final animate = _flipped && !MediaQuery.disableAnimationsOf(context);
    _flipped = false;
    _ink = animate ? IqDurations.press : Duration.zero;
    if (!animate) {
      _drop.value = _on ? 1 : 0;
      _fade.value = _on ? 1 : 0;
    } else if (_on) {
      _fade.value = 1;
      _drop.forward(from: 0);
    } else {
      _fade.reverse(from: 1);
    }
  }

  @override
  void dispose() {
    _drop.dispose();
    _fade.dispose();
    super.dispose();
  }

  void _tap() {
    _flipped = true;
    widget.onChanged!(_on ? IqBookmarkState.off : IqBookmarkState.on);
  }

  @override
  Widget build(BuildContext context) {
    final on = _on;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final outline = on
        ? IqColors.accent
        : widget.tone == IqBookmarkTone.ink
        ? IqColors.sidebarFg
        : IqColors.brand;
    return Semantics(
      toggled: on,
      child: IqPressable(
        tactile: false,
        semanticLabel: on ? 'Saved' : 'Save',
        hint: on ? 'Saved' : 'Save',
        haptic: IqHaptics.select,
        onTap: widget.onChanged == null ? null : _tap,
        builder: (context, pressed) => AnimatedScale(
          scale: pressed && !reduced ? IqScale.bookmarkPress : 1,
          duration: pressed ? IqDurations.dim : IqDurations.release,
          curve: IqCurves.easeOut,
          child: SizedBox.square(
            dimension: 44,
            child: Stack(
              children: [
                Positioned(
                  left: 17.42,
                  top: 14.67,
                  width: 10,
                  height: 15,
                  child: FadeTransition(
                    opacity: _opacity,
                    child: AnimatedBuilder(
                      animation: _reveal,
                      child: const IqVector(
                        'assets/vectors/bookmark-marker.svg',
                        color: IqColors.accent,
                      ),
                      builder: (context, child) => ClipRect(
                        clipper: _DropClipper(_reveal.value),
                        clipBehavior: _drop.isCompleted
                            ? Clip.none
                            : Clip.hardEdge,
                        child: child,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 11,
                  top: 11,
                  child: TweenAnimationBuilder<Color?>(
                    tween: ColorTween(end: outline),
                    duration: _ink,
                    curve: IqCurves.easeOut,
                    builder: (context, color, _) =>
                        IqIcon(IqIcons.bookmark, size: 22, color: color!),
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

/// Reveals the marker from the top edge down, like a ribbon dropping into
/// the page.
class _DropClipper extends CustomClipper<Rect> {
  const _DropClipper(this.reveal);

  final double reveal;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(-size.width, 0, size.width * 3, size.height * reveal);

  @override
  bool shouldReclip(_DropClipper oldClipper) => oldClipper.reveal != reveal;
}
