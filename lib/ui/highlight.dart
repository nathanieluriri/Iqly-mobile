import 'dart:async';

import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'vector.dart';

enum IqHighlightTone { orange, lilac, green, inverse }

/// Exp/Highlight: a highlighter stroke behind the one figure that matters;
/// Inverse is cream text over an orange brush underline for dark grounds.
/// The marker wipes in left to right, 240 ms ease-out, once on appear, or
/// [delay] later so a list row's band waits for its row (MOTION-SPEC
/// §5.13). [style] takes the nested text style override (TicketCard uses
/// Mob/Small strong).
class IqHighlight extends StatefulWidget {
  const IqHighlight({
    super.key,
    this.text = '12 spots left',
    this.tone = IqHighlightTone.orange,
    this.style = IqText.bodyStrong,
    this.delay = Duration.zero,
  });

  final String text;
  final IqHighlightTone tone;
  final TextStyle style;
  final Duration delay;

  static const Duration wipe = IqDurations.mark;

  @override
  State<IqHighlight> createState() => _IqHighlightState();
}

class _IqHighlightState extends State<IqHighlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wipe = AnimationController(
    vsync: this,
    duration: IqHighlight.wipe,
  );
  late final Animation<double> _reveal = _wipe.drive(
    CurveTween(curve: IqCurves.easeOut),
  );
  bool _started = false;
  Timer? _wait;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _wipe.value = 1;
    } else if (widget.delay == Duration.zero) {
      _wipe.forward();
    } else {
      _wait = Timer(widget.delay, _wipe.forward);
    }
  }

  @override
  void dispose() {
    _wait?.cancel();
    _wipe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inverse = widget.tone == IqHighlightTone.inverse;
    final ink = inverse ? IqColors.primaryFg : IqColors.brand;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth;
              final h = box.maxHeight;
              // Figma pins the marker in percentages of the hugging box.
              final inset = inverse
                  ? EdgeInsets.fromLTRB(
                      w * 0.0036,
                      h * 0.827,
                      w * 0.0138,
                      h * 0.0217,
                    )
                  : EdgeInsets.fromLTRB(
                      w * -0.0059,
                      h * 0.2878,
                      w * 0.0105,
                      h * 0.0304,
                    );
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: inset.left,
                    top: inset.top,
                    right: inset.right,
                    bottom: inset.bottom,
                    child: AnimatedBuilder(
                      animation: _reveal,
                      builder: (context, child) => ClipRect(
                        clipper: _WipeClipper(_reveal.value),
                        child: child,
                      ),
                      child: IqVector(
                        inverse
                            ? 'assets/vectors/highlight-underline.svg'
                            : 'assets/vectors/highlight-marker.svg',
                        color: _markerColor(widget.tone),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: IqSpace.s1,
            vertical: 1,
          ),
          child: Text(
            widget.text,
            maxLines: 1,
            softWrap: false,
            style: widget.style.copyWith(color: ink),
          ),
        ),
      ],
    );
  }

  static Color _markerColor(IqHighlightTone tone) => switch (tone) {
    IqHighlightTone.orange => IqColors.accentSoft,
    IqHighlightTone.lilac => IqColors.tintStrong,
    IqHighlightTone.green => IqColors.okSoft,
    IqHighlightTone.inverse => IqColors.accent,
  };
}

class _WipeClipper extends CustomClipper<Rect> {
  const _WipeClipper(this.reveal);

  final double reveal;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, -size.height, size.width * reveal, size.height * 3);

  @override
  bool shouldReclip(_WipeClipper oldClipper) => oldClipper.reveal != reveal;
}
