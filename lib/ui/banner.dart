import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';

enum IqBannerKind { urgent, offline, error }

/// Exp/Banner: a marker strip at the top of a list, one sentence and one
/// action. It slides down from under the top bar on appear (240 ms
/// ease-out) pushing the list, and slides back up when [visible] turns
/// false (180 ms, reading ease-in); under reduced motion it fades. The
/// Urgent clock pulses like Countdown Hot (halo 1 to 1.8, .35 to 0, every
/// 1.4 s) while it holds the screen's pulse, and holds a static .2 halo
/// otherwise and under reduced motion. [margin] is space that opens and
/// closes with the banner (the gap to the list it pushes).
///
/// Figma over brief: Urgent is Color/accent-soft and Error Color/err-soft, not the full accent or red.
/// Figma over its note: Offline is Color/panel, not the paper background.
/// Figma over brief: the action is Color/primary with a 14 px forward arrow.
/// Note over Figma: the Urgent halo is drawn in the app; the Figma master has none.
class IqBanner extends StatefulWidget {
  const IqBanner({
    super.key,
    this.kind = IqBannerKind.urgent,
    this.title,
    this.action,
    this.showAction = true,
    this.onAction,
    this.visible = true,
    this.margin = EdgeInsets.zero,
  });

  final IqBannerKind kind;
  final String? title;
  final String? action;
  final bool showAction;
  final VoidCallback? onAction;
  final bool visible;
  final EdgeInsetsGeometry margin;

  static const Duration enter = IqDurations.mark;
  static const Duration exit = IqDurations.ink;

  @override
  State<IqBanner> createState() => _IqBannerState();
}

class _IqBannerState extends State<IqBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _show = AnimationController(
    vsync: this,
    duration: IqBanner.enter,
    reverseDuration: IqBanner.exit,
  );
  late final Animation<double> _curve = _show.drive(
    CurveTween(curve: IqCurves.easeOut),
  );
  late final Animation<Offset> _slide = _curve.drive(
    Tween(begin: const Offset(0, -1), end: Offset.zero),
  );

  @override
  void initState() {
    super.initState();
    if (widget.visible) _show.forward();
  }

  @override
  void didUpdateWidget(IqBanner old) {
    super.didUpdateWidget(old);
    if (widget.visible != old.visible) {
      widget.visible ? _show.forward() : _show.reverse();
    }
  }

  @override
  void dispose() {
    _show.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strip = Padding(padding: widget.margin, child: _Strip(widget));
    if (MediaQuery.disableAnimationsOf(context)) {
      return AnimatedBuilder(
        animation: _show,
        child: strip,
        builder: (context, child) => _show.isDismissed
            ? const SizedBox(width: double.infinity)
            : FadeTransition(opacity: _show, child: child),
      );
    }
    return ClipRect(
      child: SizeTransition(
        sizeFactor: _curve,
        alignment: Alignment.bottomCenter,
        child: SlideTransition(position: _slide, child: strip),
      ),
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip(this.banner);

  final IqBanner banner;

  @override
  Widget build(BuildContext context) {
    final (fill, icon, ink, title, action) = switch (banner.kind) {
      IqBannerKind.urgent => (
        IqColors.accentSoft,
        IqIcons.timer,
        IqColors.brand,
        '3 activations close today',
        'See them',
      ),
      IqBannerKind.offline => (
        IqColors.panel,
        IqIcons.offline,
        IqColors.fg2,
        'You’re offline. Showing what loaded last.',
        'Retry',
      ),
      IqBannerKind.error => (
        IqColors.errSoft,
        IqIcons.error,
        IqColors.err,
        'Couldn’t load activations.',
        'Try again',
      ),
    };
    final glyph = IqIcon(icon, size: 22, color: ink);
    // The vertical padding lives on the children so the action's 44 pt hit
    // box fits inside the 46 pt strip without growing it.
    const vertical = EdgeInsets.symmetric(vertical: IqSpace.s3);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(IqRadius.xl),
      ),
      child: Row(
        children: [
          Padding(
            padding: vertical,
            child: banner.kind == IqBannerKind.urgent
                ? _Pulse(child: glyph)
                : glyph,
          ),
          const SizedBox(width: IqSpace.s3),
          Expanded(
            child: Padding(
              padding: vertical,
              child: Text(
                banner.title ?? title,
                style: IqText.smallStrong.copyWith(color: IqColors.fg),
              ),
            ),
          ),
          if (banner.showAction) ...[
            const SizedBox(width: IqSpace.s3),
            IqPressable(
              onTap: banner.onAction,
              semanticLabel: banner.action ?? action,
              builder: (context, pressed) => ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: Align(
                  alignment: Alignment.centerRight,
                  widthFactor: 1,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        banner.action ?? action,
                        style: IqText.smallStrong.copyWith(
                          color: IqColors.primary,
                        ),
                      ),
                      const SizedBox(width: IqSpace.s1),
                      const IqIcon(
                        IqIcons.forward,
                        size: 14,
                        color: IqColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The Countdown Hot halo behind the Urgent clock.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});

  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse>
    with SingleTickerProviderStateMixin, PulseLoop {
  @override
  late final AnimationController pulse = AnimationController(
    vsync: this,
    duration: IqDurations.pulse,
  );

  @override
  PulsePriority get pulsePriority => PulsePriority.urgentBanner;

  @override
  bool get wantsPulse => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncPulse();
  }

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 22,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: pulse,
              builder: (context, _) {
                final t = pulse.value;
                final grow = IqCurves.easeOut.transform(t);
                return Transform.scale(
                  scale: pulsing ? 1 + (IqScale.halo - 1) * grow : 1,
                  child: Opacity(
                    opacity: pulsing
                        ? IqOpacity.halo * (1 - t)
                        : IqOpacity.haloStill,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        color: IqColors.accentStrong,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox.square(dimension: 24),
                    ),
                  ),
                );
              },
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}
