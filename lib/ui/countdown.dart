import 'package:flutter/material.dart';

import '../core/deadline.dart';
import '../core/motion.dart';
import '../theme/theme.dart';
import 'icon.dart';

enum IqCountdownTone {
  hot,
  warm,
  calm,
  closed;

  /// The activations colour ladder: Hot under 6 hours, Warm under a day,
  /// Calm otherwise, Closed once time is up or the activation has ended.
  static IqCountdownTone of(Duration remaining, {bool closed = false}) {
    if (closed || remaining <= Duration.zero) return IqCountdownTone.closed;
    if (remaining < DeadlineRules.countdownHot) return IqCountdownTone.hot;
    if (remaining < DeadlineRules.countdownWarm) return IqCountdownTone.warm;
    return IqCountdownTone.calm;
  }
}

/// Exp/Countdown: time left as a chip, a clock on a tone halo, the time as a
/// figure and the mono LEFT unit. Appears once seen with a fade and 8 px
/// rise (220 ms); a new time rolls its changed digits up 6 px (160 ms); Hot
/// pulses its halo every 1.4 s while it holds the screen's pulse and Warm
/// breathes once on appear. Reduced motion: no movement, the Hot halo holds
/// at .2.
///
/// Figma over brief: four tones and the Time and Show unit props.
/// Figma over brief: the clock glyph stays brand ink in every tone.
/// Figma over brief: Closed keeps the gap but drops the unit text.
class IqCountdown extends StatefulWidget {
  const IqCountdown({
    super.key,
    this.time = '5h 40m',
    this.showUnit = true,
    this.tone = IqCountdownTone.hot,
  });

  final String time;
  final bool showUnit;
  final IqCountdownTone tone;

  static const Duration appear = IqDurations.appear;
  static const Duration tick = IqDurations.tick;
  static const Duration pulse = IqDurations.pulse;

  @override
  State<IqCountdown> createState() => _IqCountdownState();
}

class _IqCountdownState extends State<IqCountdown>
    with TickerProviderStateMixin, PulseLoop {
  late final AnimationController _appear = AnimationController(
    vsync: this,
    duration: IqCountdown.appear,
  );
  late final Animation<double> _rise = _appear.drive(
    CurveTween(curve: IqCurves.easeOut),
  );
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: IqCountdown.pulse,
  );
  @override
  late final AnimationController pulse = AnimationController(
    vsync: this,
    duration: IqCountdown.pulse,
  );
  bool _reduced = false;

  @override
  PulsePriority get pulsePriority => PulsePriority.hotCountdown;

  @override
  bool get wantsPulse => widget.tone == IqCountdownTone.hot;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced) {
      _appear.value = 1;
      _breath
        ..stop()
        ..value = 0;
    }
    syncPulse();
  }

  @override
  void didUpdateWidget(IqCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tone != widget.tone) syncPulse();
  }

  void _seen() {
    if (_reduced || !mounted) return;
    _appear.forward();
    if (widget.tone == IqCountdownTone.warm) _breath.forward(from: 0);
  }

  @override
  void dispose() {
    _appear.dispose();
    _breath.dispose();
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final look = _CountdownLook.of(widget.tone);
    final closed = widget.tone == IqCountdownTone.closed;
    return FirstSeen(
      onSeen: _seen,
      child: FadeTransition(
        opacity: _rise,
        child: AnimatedBuilder(
          animation: _rise,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, IqTravel.rise * (1 - _rise.value)),
            child: child,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              IqSpace.s2p5,
              IqSpace.s1p5,
              14,
              IqSpace.s1p5,
            ),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: look.fill,
              borderRadius: BorderRadius.circular(IqRadius.full),
              border: look.stroke == null
                  ? null
                  : Border.all(color: look.stroke!, width: look.strokeWidth),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 18,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        left: -1,
                        top: -1,
                        width: 20,
                        height: 20,
                        child: RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: Listenable.merge([pulse, _breath]),
                            builder: (context, _) => _halo(look),
                          ),
                        ),
                      ),
                      const IqIcon(
                        IqIcons.timer,
                        size: 16,
                        color: IqColors.brand,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: IqSpace.s2),
                RollingText(
                  widget.time,
                  style: IqText.figureSmall.copyWith(color: look.ink),
                ),
                if (widget.showUnit) ...[
                  const SizedBox(width: IqSpace.s2),
                  if (!closed)
                    Text(
                      'LEFT',
                      maxLines: 1,
                      softWrap: false,
                      style: IqText.mono.copyWith(color: look.ink),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Hot beats (scale 1 to 1.8 ease-out as it fades .35 to 0, linear) while
  /// it holds the pulse and stands at .2 otherwise; Warm breathes once.
  Widget _halo(_CountdownLook look) {
    var scale = 1.0;
    var opacity = look.haloOpacity;
    if (widget.tone == IqCountdownTone.hot) {
      opacity = IqOpacity.haloStill;
      if (pulsing) {
        final t = pulse.value;
        scale = 1 + (IqScale.halo - 1) * IqCurves.easeOut.transform(t);
        opacity = IqOpacity.halo * (1 - t);
      }
    } else if (widget.tone == IqCountdownTone.warm && _breath.isAnimating) {
      final t = _breath.value;
      final breath = IqCurves.easeInOut.transform(t < 0.5 ? t * 2 : 2 - t * 2);
      scale = 1 + (IqScale.ring - 1) * breath;
      opacity = look.haloOpacity + 0.17 * breath;
    }
    return Transform.scale(
      scale: scale,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: look.halo.withValues(alpha: opacity),
        ),
      ),
    );
  }
}

class _CountdownLook {
  const _CountdownLook({
    required this.fill,
    required this.ink,
    required this.halo,
    required this.haloOpacity,
    this.stroke,
    this.strokeWidth = 1,
  });

  final Color fill;
  final Color ink;
  final Color halo;
  final double haloOpacity;
  final Color? stroke;
  final double strokeWidth;

  static _CountdownLook of(IqCountdownTone tone) => switch (tone) {
    IqCountdownTone.hot => const _CountdownLook(
      fill: IqColors.errSoft,
      ink: IqColors.err,
      halo: IqColors.err,
      haloOpacity: 0.3,
      stroke: IqColors.err,
    ),
    IqCountdownTone.warm => const _CountdownLook(
      fill: IqColors.accentSoft,
      ink: IqColors.accentStrong,
      halo: IqColors.accentStrong,
      haloOpacity: 0.18,
    ),
    IqCountdownTone.calm => const _CountdownLook(
      fill: IqColors.card,
      ink: IqColors.brand,
      halo: IqColors.ok,
      haloOpacity: 0,
      stroke: IqColors.brandLine2,
      strokeWidth: 1.5,
    ),
    IqCountdownTone.closed => const _CountdownLook(
      fill: IqColors.panel,
      ink: IqColors.fg3,
      halo: IqColors.fg3,
      haloOpacity: 0,
    ),
  };
}
