import 'dart:async';

import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'tilt.dart';

enum IqClaimStampKind {
  pending,
  checking,
  verified,
  credited,
  needsInfo,
  rejected,
}

/// Exp/ClaimStamp: the claim state as a rubber stamp, Mob/Label words in a 1.5 px
/// ink outline tilted 2° clockwise, on no fill so it sits on paper or ink.
/// [label] defaults to the Figma words per kind. A new kind lands the stamp:
/// scale 1.15 to 1 with a 2° overshoot, 240 ms ease-out; Checking pulses its
/// dot like the Countdown Hot halo while it holds the screen's pulse.
/// Reduced motion: a 150 ms crossfade.
///
/// With [landAfter] the stamp also lands the first time it is seen, that
/// long after, fading in as it lands: a screen that opens on the change
/// (Proof submitted, Reward credited; MOTION-SPEC §5.30). Under reduced
/// motion it fades in over 150 ms instead.
///
/// Figma over its note: Checking carries an 8 px brand dot, not a clock.
/// Figma over brief: Credited reads Paid to wallet, Rejected Not approved, in
/// sentence case since the 5 Oct update (no longer mono caps).
class IqClaimStamp extends StatefulWidget {
  const IqClaimStamp({
    super.key,
    this.kind = IqClaimStampKind.pending,
    this.label,
    this.landAfter,
  });

  final IqClaimStampKind kind;
  final String? label;
  final Duration? landAfter;

  static const double tilt = 2;
  static const Duration land = IqDurations.mark;
  static const Duration fade = IqDurations.crossfade;
  static const Duration pulse = IqDurations.pulse;

  static String defaultLabel(IqClaimStampKind kind) => switch (kind) {
    IqClaimStampKind.pending => 'Pending',
    IqClaimStampKind.checking => 'Checking',
    IqClaimStampKind.verified => 'Verified',
    IqClaimStampKind.credited => 'Paid to wallet',
    IqClaimStampKind.needsInfo => 'Needs info',
    IqClaimStampKind.rejected => 'Not approved',
  };

  @override
  State<IqClaimStamp> createState() => _IqClaimStampState();
}

class _IqClaimStampState extends State<IqClaimStamp>
    with TickerProviderStateMixin, PulseLoop {
  // Preserved so the reduced motion fade in keeps its 150 ms when the
  // platform turns animations off.
  late final AnimationController _land = AnimationController(
    vsync: this,
    duration: IqClaimStamp.land,
    value: widget.landAfter == null ? 1 : 0,
    animationBehavior: AnimationBehavior.preserve,
  );
  late bool _appearing = widget.landAfter != null;
  Timer? _appear;
  @override
  late final AnimationController pulse = AnimationController(
    vsync: this,
    duration: IqClaimStamp.pulse,
  );
  bool _reduced = false;

  @override
  PulsePriority get pulsePriority => PulsePriority.checking;

  @override
  bool get wantsPulse => widget.kind == IqClaimStampKind.checking;

  static final _scale = Tween<double>(
    begin: 1.15,
    end: 1,
  ).chain(CurveTween(curve: IqCurves.easeOut));
  static final _appearOpacity = CurveTween(
    curve: const Interval(0, 0.5, curve: IqCurves.easeOut),
  );
  static final _angle = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.0,
        end: IqClaimStamp.tilt * 2,
      ).chain(CurveTween(curve: IqCurves.easeOut)),
      weight: 60,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: IqClaimStamp.tilt * 2,
        end: IqClaimStamp.tilt,
      ).chain(CurveTween(curve: IqCurves.easeInOut)),
      weight: 40,
    ),
  ]);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    syncPulse();
  }

  @override
  void didUpdateWidget(IqClaimStamp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind) {
      if (!_reduced && !_appearing) {
        _land
          ..duration = IqClaimStamp.land
          ..forward(from: 0);
      }
      syncPulse();
    }
  }

  void _seen() {
    if (_appear != null) return;
    _appear = Timer(widget.landAfter!, () {
      if (!mounted) return;
      _land
        ..duration = _reduced ? IqClaimStamp.fade : IqClaimStamp.land
        ..forward(from: 0).whenCompleteOrCancel(() {
          if (mounted) setState(() => _appearing = false);
        });
    });
  }

  @override
  void dispose() {
    _appear?.cancel();
    _land.dispose();
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stamp = _stamp(widget.kind);
    Widget landing = AnimatedBuilder(
      animation: _land,
      builder: (context, child) {
        final t = _land.value;
        final still = _reduced && _appearing;
        final Widget tilted = IqTilt(
          degrees: still ? IqClaimStamp.tilt : _angle.transform(t),
          child: Transform.scale(
            scale: still ? 1 : _scale.transform(t),
            child: child,
          ),
        );
        if (widget.landAfter == null) return tilted;
        return Opacity(
          opacity: !_appearing
              ? 1
              : still
              ? t
              : _appearOpacity.transform(t),
          child: tilted,
        );
      },
      child: AnimatedSwitcher(
        duration: _reduced ? IqClaimStamp.fade : Duration.zero,
        child: KeyedSubtree(key: ValueKey(widget.kind), child: stamp),
      ),
    );
    if (widget.landAfter != null) {
      landing = FirstSeen(onSeen: _seen, child: landing);
    }
    return Padding(padding: const EdgeInsets.all(3), child: landing);
  }

  Widget _stamp(IqClaimStampKind kind) {
    final ink = _ink(kind);
    final label = widget.label ?? IqClaimStamp.defaultLabel(kind);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: IqSpace.s2p5,
        vertical: IqSpace.s1,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(IqRadius.sm),
        border: Border.all(color: ink, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (kind == IqClaimStampKind.checking) ...[
            SizedBox.square(
              dimension: 8,
              child: AnimatedBuilder(
                animation: pulse,
                builder: (context, _) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (pulsing)
                      Positioned.fill(
                        child: Transform.scale(
                          scale:
                              1 +
                              (IqScale.halo - 1) *
                                  IqCurves.easeOut.transform(pulse.value),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: IqColors.brand.withValues(
                                alpha: IqOpacity.halo * (1 - pulse.value),
                              ),
                            ),
                          ),
                        ),
                      ),
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: IqColors.brand,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: IqSpace.s1p5),
          ],
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: IqText.label.copyWith(color: ink),
          ),
        ],
      ),
    );
  }

  static Color _ink(IqClaimStampKind kind) => switch (kind) {
    IqClaimStampKind.pending => IqColors.fg2,
    IqClaimStampKind.checking => IqColors.brand,
    IqClaimStampKind.verified => IqColors.ok,
    IqClaimStampKind.credited => IqColors.ok,
    IqClaimStampKind.needsInfo => IqColors.accentStrong,
    IqClaimStampKind.rejected => IqColors.err,
  };
}
