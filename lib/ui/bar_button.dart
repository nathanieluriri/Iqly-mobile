import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'pressable.dart';

/// Figma State=Default is [standard].
enum IqBarButtonState { standard, disabled }

/// Exp/BarButton: the full-width bottom bar action for interstitials, a 54
/// pt label band over the bottom safe area (88 in Figma with a 34 inset).
/// [width] defaults to the Figma 390; pass double.infinity to fill.
///
/// Figma over brief: the drawn home indicator placeholder becomes the OS inset (34 minimum).
/// Figma over brief: Disabled looks exactly like Default in Figma, so only the tap is switched off.
class IqBarButton extends StatelessWidget {
  const IqBarButton({
    super.key,
    this.label = 'Continue',
    this.state = IqBarButtonState.standard,
    this.onTap,
    this.width = 390,
  });

  final String label;
  final IqBarButtonState state;
  final VoidCallback? onTap;
  final double width;

  static const double height = 88;
  static const double band = 54;
  static const double homeIndicator = 34;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    return IqPressable(
      tactile: false,
      onTap: onTap,
      enabled: state == IqBarButtonState.standard,
      semanticLabel: label,
      builder: (context, pressed) => SizedBox(
        width: width,
        height: band + math.max(inset, homeIndicator),
        child: AnimatedContainer(
          duration: pressMotion(context, pressed),
          curve: IqCurves.easeOut,
          color: pressed ? IqColors.brandDark : IqColors.brand,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 22,
                height: 20,
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: IqText.button.copyWith(color: IqColors.card),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
