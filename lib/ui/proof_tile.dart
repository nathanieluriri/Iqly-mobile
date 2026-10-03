import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'button.dart';
import 'icon.dart';
import 'pressable.dart';
import 'tilt.dart';

enum IqProofTileState { empty, error }

/// Exp/ProofTile: the tap target for the proof recording, a dashed outline
/// round a tilted sticker, a title, a hint and a Secondary button. Fills its
/// parent's width (358 in Figma). [title], [hint] and [action] default to
/// the Figma copy per state; the tile and its button both call [onTap].
///
/// The sticker breathes (scale 1 to 1.04 over 2.4 s, sine) while empty; a
/// press flashes the tile accent-soft (180 ms); turning to Error shakes the
/// tile 2 px three times (240 ms). Reduced motion: no breathing, no shake.
///
/// Figma over its note: Error keeps the title in brand ink; only the
/// outline, wash, sticker and hint go red.
/// Figma over its note: the hint wraps to two lines.
class IqProofTile extends StatefulWidget {
  const IqProofTile({
    super.key,
    this.state = IqProofTileState.empty,
    this.title,
    this.hint,
    this.action,
    this.onTap,
  });

  final IqProofTileState state;
  final String? title;
  final String? hint;
  final String? action;
  final VoidCallback? onTap;

  static const Duration breath = Duration(milliseconds: 2400);
  static const Duration flash = Duration(milliseconds: 180);
  static const Duration shake = Duration(milliseconds: 240);

  @override
  State<IqProofTile> createState() => _IqProofTileState();
}

class _IqProofTileState extends State<IqProofTile>
    with TickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: IqProofTile.breath,
  );
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: IqProofTile.shake,
  );
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    _syncBreath();
  }

  @override
  void didUpdateWidget(IqProofTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state == widget.state) return;
    _syncBreath();
    if (widget.state == IqProofTileState.error && !_reduced) {
      _shake.forward(from: 0);
    }
  }

  void _syncBreath() {
    if (!_reduced && widget.state == IqProofTileState.empty) {
      if (!_breath.isAnimating) _breath.repeat();
    } else {
      _breath.stop();
      _breath.value = 0;
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.state == IqProofTileState.error;
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) => Transform.translate(
        offset: Offset(2 * math.sin(_shake.value * math.pi * 6), 0),
        child: child,
      ),
      child: IqPressable(
        onTap: widget.onTap,
        semanticLabel: widget.title ?? _title,
        builder: (context, pressed) => CustomPaint(
          foregroundPainter: _DashedOutline(
            error ? IqColors.err : IqColors.brandLine2,
          ),
          child: AnimatedContainer(
            duration: _reduced ? Duration.zero : IqProofTile.flash,
            curve: Curves.easeOut,
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
            decoration: BoxDecoration(
              color: pressed
                  ? IqColors.accentSoft
                  : error
                  ? IqColors.errWash
                  : IqColors.card,
              borderRadius: BorderRadius.circular(IqRadius.xl2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _breath,
                  builder: (context, child) => Transform.scale(
                    scale:
                        1 + 0.02 * (1 - math.cos(_breath.value * 2 * math.pi)),
                    child: child,
                  ),
                  child: IqTilt(
                    degrees: 6,
                    child: Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: error ? IqColors.errSoft : IqColors.accent,
                      ),
                      child: IqIcon(
                        error ? IqIcons.warning : IqIcons.video,
                        size: 26,
                        color: error ? IqColors.err : IqColors.brand,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: IqSpace.s2p5),
                Text(
                  widget.title ?? _title,
                  textAlign: TextAlign.center,
                  style: IqText.bodyStrong.copyWith(color: IqColors.brand),
                ),
                const SizedBox(height: IqSpace.s2p5),
                Text(
                  widget.hint ?? _hint,
                  textAlign: TextAlign.center,
                  style: IqText.small.copyWith(
                    color: error ? IqColors.errStrong : IqColors.fg2,
                  ),
                ),
                const SizedBox(height: IqSpace.s2p5),
                IqButton(
                  label: widget.action ?? _action,
                  kind: IqButtonKind.secondary,
                  showIcon: false,
                  onTap: widget.onTap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _error => widget.state == IqProofTileState.error;

  String get _title => _error
      ? 'That recording is over 60 seconds'
      : 'Add your screen recording';

  String get _hint => _error
      ? 'Trim it to the part that shows the step and the result, then add it '
            'again.'
      : 'The step and the result, up to 60 s. MP4 or MOV, up to 50 MB.';

  String get _action => _error ? 'Choose another' : 'Choose a video';
}

class _DashedOutline extends CustomPainter {
  const _DashedOutline(this.color);

  final Color color;

  static const double width = 2;
  static const double dash = 8;
  static const double gap = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(width / 2);
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          rect,
          const Radius.circular(IqRadius.xl2 - width / 2),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash + gap) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedOutline oldDelegate) => oldDelegate.color != color;
}
