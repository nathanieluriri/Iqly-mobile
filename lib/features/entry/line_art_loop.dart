import 'package:flutter/material.dart';

import '../../ui/illustration.dart';

/// The landing loop (Exp/LineArt Frame 1 to 3): 0.6 s hold, 1.1 s move,
/// 0.9 s hold, 1.1 s move, 0.6 s hold, 1.1 s back, ease in and out. Figma
/// Smart Animates the layers; the exports are flat, so the keyframes
/// crossfade. Reduced motion holds Frame 1.
class LineArtLoop extends StatefulWidget {
  const LineArtLoop({super.key, required this.size});

  final double size;

  @override
  State<LineArtLoop> createState() => _LineArtLoopState();
}

class _LineArtLoopState extends State<LineArtLoop>
    with SingleTickerProviderStateMixin {
  static const _steps = [0.6, 1.1, 0.9, 1.1, 0.6, 1.1];
  static final double _total = _steps.reduce((a, b) => a + b);

  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (_total * 1000).round()),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _clock
        ..stop()
        ..value = 0;
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  /// Opacity of each keyframe at time [t] seconds into the loop.
  static List<double> _weights(double t) {
    var start = 0.0;
    for (var i = 0; i < _steps.length; i++) {
      final end = start + _steps[i];
      if (t < end || i == _steps.length - 1) {
        final from = i ~/ 2;
        if (i.isEven) return _only(from);
        final p = Curves.easeInOut.transform(
          ((t - start) / _steps[i]).clamp(0.0, 1.0),
        );
        final to = (from + 1) % 3;
        final w = [0.0, 0.0, 0.0];
        w[from] = 1 - p;
        w[to] = p;
        return w;
      }
      start = end;
    }
    return _only(0);
  }

  static List<double> _only(int i) => [
    for (var k = 0; k < 3; k++) k == i ? 1.0 : 0.0,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _clock,
        builder: (context, _) {
          final w = _weights(_clock.value * _total);
          return Stack(
            children: [
              for (final frame in IqLineArtFrames.values)
                if (w[frame.index] > 0)
                  Opacity(
                    opacity: w[frame.index],
                    child: IqLineArt(frame, size: widget.size),
                  ),
            ],
          );
        },
      ),
    );
  }
}
