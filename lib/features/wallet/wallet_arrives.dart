import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/motion.dart';
import '../../ui/illustration.dart';

/// Exp/Illustration Kind=Wallet arriving in its two layers (spec 5.29): the
/// ink rises 16 and fades in over 320, then the orange strap alone sweeps
/// across, 240 from +160, under the ink as the art stacks them. Reduced
/// motion: the illustration itself.
class WalletArrives extends StatelessWidget {
  const WalletArrives({super.key});

  /// The strap's extent in the art, so the sweep crosses the brush itself
  /// rather than the whole 200 wide frame.
  static const _strap = Rect.fromLTRB(73, 0, 143, IqIllustration.designHeight);

  @override
  Widget build(BuildContext context) {
    const kind = IqIllustrations.wallet;
    if (MediaQuery.disableAnimationsOf(context)) {
      return const IqIllustration(kind);
    }
    return SizedBox(
      width: IqIllustration.designWidth,
      height: IqIllustration.designHeight,
      child: Stack(
        children: [
          Positioned.fromRect(
            rect: _strap,
            child: Wipe(
              delay: IqDurations.stagger * 4,
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minWidth: IqIllustration.designWidth,
                maxWidth: IqIllustration.designWidth,
                child: Transform.translate(
                  offset: Offset(-_strap.left, 0),
                  child: const _Layer(kind, keep: 'accent'),
                ),
              ),
            ),
          ),
          const Arrive(
            distance: IqTravel.riseHero,
            duration: IqDurations.morph,
            child: _Layer(kind, keep: 'ink'),
          ),
        ],
      ),
    );
  }
}

class _Layer extends StatelessWidget {
  const _Layer(this.kind, {required this.keep});

  final IqIllustrations kind;
  final String keep;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      kind.asset,
      width: IqIllustration.designWidth,
      height: IqIllustration.designHeight,
      excludeFromSemantics: true,
      colorMapper: _OnlyLayer(keep),
    );
  }
}

/// Keeps one layer of an illustration, [keep] "ink" or "accent", and clears
/// the other. The accent is always one path named accent, while the ink can
/// be a group whose paths have no id of their own, so the accent layer is
/// that path alone and the ink layer is everything else.
class _OnlyLayer extends ColorMapper {
  const _OnlyLayer(this.keep);

  final String keep;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) => (id == 'accent') == (keep == 'accent') ? color : Colors.transparent;

  @override
  bool operator ==(Object other) => other is _OnlyLayer && other.keep == keep;

  @override
  int get hashCode => keep.hashCode;
}
