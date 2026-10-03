import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'pressable.dart';
import 'vector.dart';

/// Figma State=Default is [standard].
enum IqOptionRowState { standard, selected }

/// Exp/OptionRow: a 56 high picker row for long lists (universities,
/// states, banks, sort). Selected is the tint fill with the check; the
/// label stays Regular and wraps to a second line, the row growing to fit
/// (Figma 188:8340 wraps "Lagos State University of Science and
/// Technology"). A pick gives the select haptic.
///
/// Figma over brief: the check is a plain 16 x 11.5 stroked tick (2.2 px), not the brush check icon.
/// Figma over brief: Default is a white Color/card row with radius 12.
///
/// Motion (MOTION-SPEC 5.7): pressed, the fill goes to panel (100 ms in,
/// 160 out); selected, it floods to tint (120 ease-out) and the check
/// draws left to right over 160 from +40; a cleared pick goes back to card
/// as its check fades (120 ease-in). Reduced motion: the fill cuts and the
/// check shows at once.
class IqOptionRow extends StatefulWidget {
  const IqOptionRow({
    super.key,
    this.label = 'University of Lagos',
    this.note = 'Akoka, Lagos',
    this.showNote = true,
    this.state = IqOptionRowState.standard,
    this.onTap,
  });

  final String label;
  final String note;
  final bool showNote;
  final IqOptionRowState state;
  final VoidCallback? onTap;

  static const double height = 56;

  @override
  State<IqOptionRow> createState() => _IqOptionRowState();
}

class _IqOptionRowState extends State<IqOptionRow>
    with SingleTickerProviderStateMixin {
  static final Duration _drawFrom = IqDurations.stagger;

  late final AnimationController _check = AnimationController(
    vsync: this,
    value: _selected ? 1 : 0,
  );
  Animation<double> _draw = kAlwaysCompleteAnimation;
  Animation<double> _fade = kAlwaysCompleteAnimation;
  Duration _fill = Duration.zero;
  bool _wasPressed = false;

  bool get _selected => widget.state == IqOptionRowState.selected;

  @override
  void didUpdateWidget(IqOptionRow old) {
    super.didUpdateWidget(old);
    if (widget.state == old.state) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _fill = Duration.zero;
      _draw = _fade = kAlwaysCompleteAnimation;
      _check.value = _selected ? 1 : 0;
      return;
    }
    _fill = IqDurations.chain;
    if (_selected) {
      final total = _drawFrom + IqDurations.tick;
      _check.duration = total;
      _draw = _check.drive(
        CurveTween(
          curve: Interval(
            _drawFrom.inMicroseconds / total.inMicroseconds,
            1,
            curve: IqCurves.easeOut,
          ),
        ),
      );
      _fade = kAlwaysCompleteAnimation;
      _check.forward(from: 0);
    } else {
      _check.duration = IqDurations.chain;
      _draw = kAlwaysCompleteAnimation;
      _fade = _check.drive(CurveTween(curve: IqCurves.easeOut));
      _check.reverse(from: 1);
    }
  }

  @override
  void dispose() {
    _check.dispose();
    super.dispose();
  }

  Duration _fillFor(BuildContext context, bool pressed) {
    if (pressed != _wasPressed) {
      _wasPressed = pressed;
      _fill = pressed ? IqDurations.dim : motion(context, IqDurations.release);
    }
    return _fill;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Semantics(
      selected: selected,
      child: IqPressable(
        onTap: widget.onTap,
        semanticLabel: widget.label,
        haptic: IqHaptics.select,
        builder: (context, pressed) => AnimatedContainer(
          duration: _fillFor(context, pressed),
          curve: selected || pressed ? IqCurves.easeOut : IqCurves.easeIn,
          constraints: const BoxConstraints(minHeight: IqOptionRow.height),
          padding: const EdgeInsets.symmetric(
            horizontal: IqSpace.s4,
            vertical: IqSpace.s1,
          ),
          decoration: BoxDecoration(
            color: selected
                ? IqColors.tint
                : pressed
                ? IqColors.panel
                : IqColors.card,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: IqText.body.copyWith(color: IqColors.fg),
                    ),
                    if (widget.showNote) ...[
                      const SizedBox(height: 1),
                      Text(
                        widget.note,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: IqText.small.copyWith(color: IqColors.fg3),
                      ),
                    ],
                  ],
                ),
              ),
              AnimatedBuilder(
                animation: _check,
                builder: (context, _) {
                  if (_check.isDismissed) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(left: IqSpace.s3),
                    child: FadeTransition(
                      opacity: _fade,
                      child: ClipRect(
                        clipper: _DrawClipper(_draw.value),
                        child: const _Check(),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The 16 x 11.5 tick; the export carries 1.1 px of stroke bleed around it.
class _Check extends StatelessWidget {
  const _Check();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 11.5,
      child: OverflowBox(
        maxWidth: 19,
        maxHeight: 14,
        alignment: Alignment.topLeft,
        child: Transform.translate(
          offset: const Offset(-1.1, -1.1),
          child: const IqVector(
            'assets/vectors/option-row-check.svg',
            color: IqColors.brand,
            width: 19,
            height: 14,
          ),
        ),
      ),
    );
  }
}

/// Reveals the check left to right; at 1 it lets the stroke bleed show.
class _DrawClipper extends CustomClipper<Rect> {
  const _DrawClipper(this.reveal);

  final double reveal;

  @override
  Rect getClip(Size size) => reveal >= 1
      ? Rect.fromLTRB(-4, -4, size.width + 4, size.height + 4)
      : Rect.fromLTWH(-4, -4, 4 + size.width * reveal, size.height + 8);

  @override
  bool shouldReclip(_DrawClipper old) => old.reveal != reveal;
}
