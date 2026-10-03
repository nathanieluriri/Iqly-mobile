import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'pressable.dart';

/// Figma State=Default is [standard].
enum IqBarButtonState { standard, disabled }

/// Exp/BarButton: the full-width bottom bar action for interstitials, 88
/// tall with its own home indicator (replaces the screen's indicator).
/// [width] defaults to the Figma 390; pass double.infinity to fill.
///
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

  @override
  Widget build(BuildContext context) {
    return IqPressable(
      onTap: onTap,
      enabled: state == IqBarButtonState.standard,
      semanticLabel: label,
      builder: (context, pressed) => AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        width: width,
        height: height,
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
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 134,
                  height: 5,
                  decoration: BoxDecoration(
                    color: IqColors.card,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
