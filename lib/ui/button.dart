import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';
import 'sticker.dart';
import 'vector.dart';

enum IqButtonKind { primary, secondary, danger, ghost, inverse }

/// Exp/Button: the 52 pt sticker pill. Press drops the pill onto its shadow
/// (Figma draws it at 3,3; label and icon hold their place), 120 ms
/// ease-out; Ghost is text and the brush arrow. [width] defaults to the
/// Figma 200; pass double.infinity to fill.
///
/// Figma over brief: Danger keeps a sticker shadow (err-soft).
/// Figma over brief: Ghost shows the brush arrow by default.
/// Figma over brief: Secondary has its own brand-line2 sticker shadow.
/// Figma over brief: Loading uses the web-kit spinner, not a brush icon.
class IqButton extends StatelessWidget {
  const IqButton({
    super.key,
    this.label = 'Withdraw',
    this.kind = IqButtonKind.primary,
    this.showIcon = true,
    this.onTap,
    this.disabled = false,
    this.loading = false,
    this.width = 200,
  });

  final String label;
  final IqButtonKind kind;
  final bool showIcon;
  final VoidCallback? onTap;
  final bool disabled;
  final bool loading;
  final double width;

  static const double height = 52;
  static const double radius = 26;

  @override
  Widget build(BuildContext context) {
    return IqPressable(
      onTap: onTap,
      enabled: !disabled && !loading,
      semanticLabel: label,
      builder: (context, pressed) => SizedBox(
        width: width,
        height: height,
        child: _body(context, _ButtonLook.of(kind, disabled, pressed), pressed),
      ),
    );
  }

  Widget _body(BuildContext context, _ButtonLook look, bool pressed) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : Sticker.duration;
    final content = loading
        ? _Spinner(color: look.ink)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: IqText.button.copyWith(color: look.ink),
                ),
              ),
              if (showIcon) ...[
                const SizedBox(width: IqSpace.s2),
                IqIcon(IqIcons.arrow, size: 20, color: look.iconInk),
              ],
            ],
          );
    final pill = AnimatedContainer(
      duration: duration,
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: look.fill,
        borderRadius: BorderRadius.circular(radius),
        border: look.stroke == null
            ? null
            : Border.all(color: look.stroke!, width: 1.5),
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Sticker(
            radius: radius,
            color: look.shadow ?? IqColors.accent,
            visible: look.shadow != null,
            pressed: pressed && kind != IqButtonKind.ghost,
            child: SizedBox.expand(child: pill),
          ),
        ),
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: kind == IqButtonKind.ghost
                  ? IqSpace.s1p5
                  : IqSpace.s6,
            ),
            child: Center(child: content),
          ),
        ),
      ],
    );
  }
}

class _ButtonLook {
  const _ButtonLook({
    required this.fill,
    required this.ink,
    this.stroke,
    this.shadow,
    Color? iconInk,
  }) : iconInk = iconInk ?? ink;

  final Color? fill;
  final Color ink;
  final Color iconInk;
  final Color? stroke;
  final Color? shadow;

  static _ButtonLook of(IqButtonKind kind, bool disabled, bool pressed) {
    switch (kind) {
      case IqButtonKind.primary:
        if (disabled) return _disabled;
        return _ButtonLook(
          fill: pressed ? IqColors.brandDark : IqColors.brand,
          ink: IqColors.primaryFg,
          shadow: IqColors.accent,
        );
      case IqButtonKind.secondary:
        if (disabled) {
          return const _ButtonLook(
            fill: IqColors.panel,
            ink: IqColors.fg3,
            stroke: IqColors.line,
          );
        }
        return _ButtonLook(
          fill: pressed ? IqColors.panel : IqColors.card,
          ink: IqColors.brand,
          stroke: IqColors.brand,
          shadow: IqColors.brandLine2,
        );
      case IqButtonKind.danger:
        if (disabled) return _disabled;
        return const _ButtonLook(
          fill: IqColors.errStrong,
          ink: IqColors.primaryFg,
          shadow: IqColors.errSoft,
        );
      case IqButtonKind.ghost:
        return _ButtonLook(
          fill: null,
          ink: disabled ? IqColors.fg3 : IqColors.brand,
        );
      case IqButtonKind.inverse:
        if (disabled) {
          return _ButtonLook(
            fill: IqColors.bg.withValues(alpha: 0.6),
            ink: IqColors.brand,
            iconInk: IqColors.brand.withValues(alpha: 0.6),
          );
        }
        return _ButtonLook(
          fill: pressed ? IqColors.tint : IqColors.bg,
          ink: IqColors.brand,
          shadow: IqColors.accent,
        );
    }
  }

  static const _disabled = _ButtonLook(fill: IqColors.panel, ink: IqColors.fg3);
}

/// The web-kit Spinner (lucide loader-circle, 16 px, 1.33 stroke), turning
/// once a second; still under reduced motion.
class _Spinner extends StatefulWidget {
  const _Spinner({required this.color});

  final Color color;

  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
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
    return RotationTransition(
      turns: _turn,
      child: IqVector(
        'assets/vectors/button-spinner.svg',
        color: widget.color,
        width: 16,
        height: 16,
      ),
    );
  }
}
