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

/// Exp/ClaimStamp: the claim state as a rubber stamp, mono caps in a 1.5 px
/// ink outline tilted 2° clockwise, on no fill so it sits on paper or ink.
/// [label] defaults to the Figma words per kind. A new kind lands the stamp:
/// scale 1.15 to 1 with a 2° overshoot, 240 ms ease-out; Checking pulses its
/// dot like the Countdown Hot halo while it holds the screen's pulse.
/// Reduced motion: a 150 ms crossfade.
///
/// Figma over its note: Checking carries an 8 px brand dot, not a clock.
/// Figma over brief: Credited reads PAID TO WALLET, Rejected NOT APPROVED.
class IqClaimStamp extends StatefulWidget {
  const IqClaimStamp({
    super.key,
    this.kind = IqClaimStampKind.pending,
    this.label,
  });

  final IqClaimStampKind kind;
  final String? label;

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
  late final AnimationController _land = AnimationController(
    vsync: this,
    duration: IqClaimStamp.land,
    value: 1,
  );
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
      if (!_reduced) _land.forward(from: 0);
      syncPulse();
    }
  }

  @override
  void dispose() {
    _land.dispose();
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stamp = _stamp(widget.kind);
    return Padding(
      padding: const EdgeInsets.all(3),
      child: AnimatedBuilder(
        animation: _land,
        builder: (context, child) => IqTilt(
          degrees: _angle.transform(_land.value),
          child: Transform.scale(
            scale: _scale.transform(_land.value),
            child: child,
          ),
        ),
        child: AnimatedSwitcher(
          duration: _reduced ? IqClaimStamp.fade : Duration.zero,
          child: KeyedSubtree(key: ValueKey(widget.kind), child: stamp),
        ),
      ),
    );
  }

  Widget _stamp(IqClaimStampKind kind) {
    final ink = _ink(kind);
    final label = (widget.label ?? IqClaimStamp.defaultLabel(kind))
        .toUpperCase();
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
            style: IqText.mono.copyWith(color: ink),
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
