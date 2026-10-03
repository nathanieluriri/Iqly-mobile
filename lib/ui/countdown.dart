import 'package:flutter/material.dart';

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
    if (remaining < const Duration(hours: 6)) return IqCountdownTone.hot;
    if (remaining < const Duration(days: 1)) return IqCountdownTone.warm;
    return IqCountdownTone.calm;
  }
}

/// Exp/Countdown: time left as a chip, a clock on a tone halo, the time as a
/// figure and the mono LEFT unit. Appears with a fade and 8 px rise (220 ms);
/// a new time slides the old digits up 6 px (160 ms); Hot pulses its halo
/// every 1.4 s and Warm breathes once on appear. Reduced motion: no
/// movement, the Hot halo holds at .2.
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

  static const Duration appear = Duration(milliseconds: 220);
  static const Duration tick = Duration(milliseconds: 160);
  static const Duration pulse = Duration(milliseconds: 1400);

  @override
  State<IqCountdown> createState() => _IqCountdownState();
}

class _IqCountdownState extends State<IqCountdown>
    with TickerProviderStateMixin {
  late final AnimationController _appear = AnimationController(
    vsync: this,
    duration: IqCountdown.appear,
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: IqCountdown.pulse,
  );
  bool _reduced = false;
  bool _started = false;
  bool _repeating = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (!_started) {
      _started = true;
      if (_reduced) {
        _appear.value = 1;
      } else {
        _appear.forward();
        if (widget.tone == IqCountdownTone.warm) _pulse.forward();
      }
    }
    _syncPulse();
  }

  @override
  void didUpdateWidget(IqCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tone != widget.tone) _syncPulse();
  }

  void _syncPulse() {
    final hot = widget.tone == IqCountdownTone.hot;
    if (!_reduced && hot) {
      if (!_repeating) _pulse.repeat();
      _repeating = true;
      return;
    }
    final breathing =
        widget.tone == IqCountdownTone.warm &&
        !_repeating &&
        _pulse.status == AnimationStatus.forward;
    if (_reduced || !breathing) {
      _pulse.stop();
      _pulse.value = 0;
    }
    _repeating = false;
  }

  @override
  void dispose() {
    _appear.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final look = _CountdownLook.of(widget.tone);
    final closed = widget.tone == IqCountdownTone.closed;
    final rise = CurvedAnimation(parent: _appear, curve: Curves.easeOut);
    return AnimatedBuilder(
      animation: rise,
      builder: (context, child) => Opacity(
        opacity: rise.value,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - rise.value)),
          child: child,
        ),
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
                    child: AnimatedBuilder(
                      animation: _pulse,
                      builder: (context, _) => _halo(look),
                    ),
                  ),
                  const IqIcon(IqIcons.timer, size: 16, color: IqColors.brand),
                ],
              ),
            ),
            const SizedBox(width: IqSpace.s2),
            _Ticker(
              text: widget.time,
              duration: _reduced ? Duration.zero : IqCountdown.tick,
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
    );
  }

  Widget _halo(_CountdownLook look) {
    final t = _pulse.value;
    var scale = 1.0;
    var opacity = look.haloOpacity;
    if (widget.tone == IqCountdownTone.hot) {
      if (_reduced) {
        opacity = 0.2;
      } else if (_pulse.isAnimating) {
        scale = 1 + 0.8 * Curves.easeOut.transform(t);
        opacity = 0.35 * (1 - t);
      }
    } else if (widget.tone == IqCountdownTone.warm && t > 0 && t < 1) {
      final breath = Curves.easeInOut.transform(t < 0.5 ? t * 2 : 2 - t * 2);
      scale = 1 + 0.3 * breath;
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

class _Ticker extends StatelessWidget {
  const _Ticker({
    required this.text,
    required this.duration,
    required this.style,
  });

  final String text;
  final Duration duration;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (current, previous) => Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerLeft,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) {
        final incoming = child.key == ValueKey(text);
        final offset = Tween<Offset>(
          begin: Offset(0, incoming ? 6 : -6),
          end: Offset.zero,
        );
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) => Opacity(
            opacity: animation.value,
            child: Transform.translate(
              offset: offset.transform(animation.value),
              child: child,
            ),
          ),
          child: child,
        );
      },
      child: Text(
        text,
        key: ValueKey(text),
        maxLines: 1,
        softWrap: false,
        style: style,
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
