import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';
import 'sticker.dart';

enum IqProviderButtonKind {
  apple('Continue with Apple'),
  google('Continue with Google'),
  email('Continue with email');

  const IqProviderButtonKind(this.label);

  final String label;
}

/// Exp/ProviderButton: a 358 x 56 sign-in pill. Apple and Google carry the
/// official marks, never recoloured; Email is the house primary on the
/// orange sticker. Labels are fixed per kind. Email presses like the
/// primary Button (the pill drops onto its sticker, 120 ms, with the commit
/// haptic); Apple and Google take the Secondary pressed fill, 120 ms in and
/// 160 out. [width] defaults to 358.
///
/// Figma over brief: the Apple and Google borders are 1.5 pt Color/fg (near
/// black), not the ink brand; Google matched Apple in the 5 Oct update.
class IqProviderButton extends StatelessWidget {
  const IqProviderButton({
    super.key,
    this.kind = IqProviderButtonKind.apple,
    this.onTap,
    this.width = 358,
  });

  final IqProviderButtonKind kind;
  final VoidCallback? onTap;
  final double width;

  static const double height = 56;
  static const double radius = 28;

  @override
  Widget build(BuildContext context) {
    return IqPressable(
      onTap: onTap,
      semanticLabel: kind.label,
      haptic: kind == IqProviderButtonKind.email
          ? IqHaptics.commit
          : IqHaptics.tap,
      builder: (context, pressed) {
        final email = kind == IqProviderButtonKind.email;
        final ink = email ? IqColors.card : IqColors.fg;
        final pill = AnimatedContainer(
          duration: pressMotion(context, pressed),
          curve: IqCurves.easeOut,
          decoration: BoxDecoration(
            color: switch (kind) {
              IqProviderButtonKind.email =>
                pressed ? IqColors.brandDark : IqColors.brand,
              _ => pressed ? IqColors.panel : IqColors.card,
            },
            borderRadius: BorderRadius.circular(radius),
            border: switch (kind) {
              IqProviderButtonKind.apple || IqProviderButtonKind.google =>
                Border.all(color: IqColors.fg, width: 1.5),
              IqProviderButtonKind.email => null,
            },
          ),
        );
        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Sticker(
                  radius: radius,
                  visible: email,
                  pressed: pressed && email,
                  child: SizedBox.expand(child: pill),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: IqSpace.s6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _mark(),
                      const SizedBox(width: IqSpace.s2p5),
                      Flexible(
                        child: Text(
                          kind.label,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: IqText.button.copyWith(color: ink),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _mark() => switch (kind) {
    IqProviderButtonKind.apple => SvgPicture.asset(
      'assets/brand/apple-mark.svg',
      width: 16.28,
      height: 20,
    ),
    IqProviderButtonKind.google => SvgPicture.asset(
      'assets/brand/google-g.svg',
      width: 20,
      height: 20,
    ),
    IqProviderButtonKind.email => const IqIcon(
      IqIcons.mail,
      size: 22,
      color: IqColors.card,
    ),
  };
}
