import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';

enum IqBannerKind { urgent, offline, error }

/// Exp/Banner: a marker strip at the top of a list, one sentence and one
/// action. It slides down from under the top bar on appear (240 ms
/// ease-out) pushing the list, and slides back up when [visible] turns
/// false (180 ms ease-in); under reduced motion it fades. The Urgent clock
/// pulses like Countdown Hot (halo 1 to 1.8, .35 to 0, every 1.4 s; a
/// static .2 halo under reduced motion).
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
  });

  final IqBannerKind kind;
  final String? title;
  final String? action;
  final bool showAction;
  final VoidCallback? onAction;
  final bool visible;

  static const Duration enter = Duration(milliseconds: 240);
  static const Duration exit = Duration(milliseconds: 180);

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
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _show,
    curve: Curves.easeOut,
    reverseCurve: Curves.easeIn,
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
    _curve.dispose();
    _show.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strip = _Strip(widget);
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
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(_curve),
          child: strip,
        ),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: IqRadius.xl,
        vertical: IqSpace.s3,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(IqRadius.xl),
      ),
      child: Row(
        children: [
          if (banner.kind == IqBannerKind.urgent)
            _Pulse(child: glyph)
          else
            glyph,
          const SizedBox(width: IqSpace.s3),
          Expanded(
            child: Text(
              banner.title ?? title,
              style: IqText.smallStrong.copyWith(color: IqColors.fg),
            ),
          ),
          if (banner.showAction) ...[
            const SizedBox(width: IqSpace.s3),
            IqPressable(
              onTap: banner.onAction,
              semanticLabel: banner.action ?? action,
              builder: (context, pressed) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    banner.action ?? action,
                    style: IqText.smallStrong.copyWith(color: IqColors.primary),
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

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _beat = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _beat.stop();
    } else if (!_beat.isAnimating) {
      _beat.repeat();
    }
  }

  @override
  void dispose() {
    _beat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return SizedBox.square(
      dimension: 22,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _beat,
            builder: (context, _) {
              final t = Curves.easeOut.transform(_beat.value);
              return Transform.scale(
                scale: still ? 1 : 1 + 0.8 * t,
                child: Opacity(
                  opacity: still ? 0.2 : 0.35 * (1 - t),
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
          widget.child,
        ],
      ),
    );
  }
}
