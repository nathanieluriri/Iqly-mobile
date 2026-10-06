import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';
import 'sticker.dart';
import 'vector.dart';

enum IqNextFabState { disabled, enabled }

/// Exp/NextFab: the round next button for one-question screens, disabled
/// until the field is valid. Enabled is the ink disc with the white brush
/// chevron on the orange sticker.
///
/// Motion (MOTION-SPEC 5.3): turning enabled peels it, the disc and the
/// chevron crossfading to their enabled colours over 160 ms ease-out while
/// the sticker slides out and the disc grows from .92 over 200; turning
/// disabled tucks it back in 120 ease-in. Press drops the disc onto the
/// sticker (120 ms, brand-dark) with the commit haptic. While [loading]
/// the chevron crossfades to a 16 px spinner (150) and taps are ignored.
/// [onTapDisabled] hears taps while disabled, so a screen can point at what
/// is missing. Reduced motion: colours cut, the sticker shows at once and
/// the spinner stands still.
///
/// Not in Figma: the Loading look (Figma has no such state) and the
/// pressed fill, which borrows the Primary Button's brand-dark.
class IqNextFab extends StatefulWidget {
  const IqNextFab({
    super.key,
    this.state = IqNextFabState.disabled,
    this.onTap,
    this.semanticLabel = 'Next',
    this.loading = false,
    this.onTapDisabled,
  });

  final IqNextFabState state;
  final VoidCallback? onTap;
  final String semanticLabel;
  final bool loading;
  final VoidCallback? onTapDisabled;

  static const double size = 56;

  /// Whether [look] (an [IqNextFab]) is the lit one, for a crossfade that
  /// lets it fade over the unlit look.
  static bool lit(Widget look) =>
      (look as IqNextFab).state == IqNextFabState.enabled;

  @override
  State<IqNextFab> createState() => _IqNextFabState();
}

class _IqNextFabState extends State<IqNextFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _grow = AnimationController(
    vsync: this,
    duration: IqDurations.swap,
    value: 1,
  );
  late final Animation<double> _scale = _grow.drive(
    Tween<double>(
      begin: IqScale.peel,
      end: 1,
    ).chain(CurveTween(curve: IqCurves.easeOut)),
  );

  bool get _enabled => widget.state == IqNextFabState.enabled;

  @override
  void didUpdateWidget(IqNextFab old) {
    super.didUpdateWidget(old);
    final was = old.state == IqNextFabState.enabled;
    if (_enabled && !was && !MediaQuery.disableAnimationsOf(context)) {
      _grow.forward(from: 0);
    } else if (!_enabled) {
      _grow.value = 1;
    }
  }

  @override
  void dispose() {
    _grow.dispose();
    super.dispose();
  }

  Duration _ink(BuildContext context) =>
      motion(context, _enabled ? IqDurations.tick : IqDurations.press);

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    final curve = enabled ? IqCurves.easeOut : IqCurves.easeIn;
    final fab = IqPressable(
      onTap: widget.onTap,
      enabled: enabled && !widget.loading,
      semanticLabel: widget.semanticLabel,
      haptic: IqHaptics.commit,
      builder: (context, pressed) => SizedBox.square(
        dimension: IqNextFab.size,
        child: Sticker(
          radius: IqNextFab.size / 2,
          visible: enabled,
          pressed: pressed,
          child: ScaleTransition(
            scale: _scale,
            child: AnimatedContainer(
              duration: enabled && pressed ? IqDurations.press : _ink(context),
              curve: curve,
              width: IqNextFab.size,
              height: IqNextFab.size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: switch ((enabled, pressed)) {
                  (false, _) => IqColors.line,
                  (true, true) => IqColors.brandDark,
                  (true, false) => IqColors.brand,
                },
                shape: BoxShape.circle,
              ),
              child: AnimatedSwitcher(
                duration: motion(context, IqDurations.crossfade),
                switchInCurve: IqCurves.easeOut,
                switchOutCurve: IqCurves.easeOut,
                child: widget.loading
                    ? const _Spinner(key: ValueKey('spinner'))
                    : TweenAnimationBuilder<Color?>(
                        key: const ValueKey('chevron'),
                        tween: ColorTween(
                          end: enabled ? IqColors.card : IqColors.fg3,
                        ),
                        duration: _ink(context),
                        curve: curve,
                        builder: (context, color, _) => IqIcon(
                          IqIcons.forward,
                          size: 24,
                          color: color ?? IqColors.fg3,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
    // One tree shape lit or not: a wrapper that came and went would rebuild
    // the disc straight at its new look, so it would light without peeling.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: enabled ? null : widget.onTapDisabled,
      child: fab,
    );
  }
}

/// The Button's web-kit spinner at 16 px in the chevron's white, turning
/// once a second; still under reduced motion.
class _Spinner extends StatefulWidget {
  const _Spinner({super.key});

  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: IqDurations.spinnerTurn,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _turn.stop();
    } else if (!_turn.isAnimating) {
      _turn.repeat();
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: RotationTransition(
        turns: _turn,
        child: const IqVector(
          'assets/vectors/button-spinner.svg',
          color: IqColors.card,
          width: 16,
          height: 16,
        ),
      ),
    );
  }
}
