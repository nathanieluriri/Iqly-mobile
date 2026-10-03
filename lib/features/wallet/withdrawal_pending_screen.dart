import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../core/responsive.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/highlight.dart';
import '../../ui/illustration.dart';
import '../../ui/top_bar.dart';
import 'wallet_motion.dart';
import 'wallet_state.dart';

/// B5 · Withdrawal pending (38:147), a moment: the Wallet illustration
/// arrives (ink rises 16 over 320, the strap sweeps in from +160), the
/// title appears at +80, the amount line at +120 with its Highlight wiping
/// from +240, AVAILABLE AFTER at +160. The success haptic plays as the
/// sheet hands over (MOTION-SPEC §7.1).
///
/// Figma: the Page bar has no back button, and "Back to wallet" is the
/// only way on; AVAILABLE AFTER is what is available once this one is on
/// hold (₦12,500.00 − ₦5,000.00 = ₦7,500.00).
class WithdrawalPendingScreen extends ConsumerWidget {
  const WithdrawalPendingScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(walletProvider).value;
    final withdrawal = data?.withdrawal(id);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: IqColors.bg,
        body: SafeArea(
          child: CenteredContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const IqTopBar(
                  variant: IqTopBarVariant.page,
                  title: 'Withdraw',
                  showBack: false,
                ),
                Expanded(
                  child: withdrawal == null || data == null
                      ? const SizedBox.shrink()
                      : Choreography(
                          length: WalletDurations.moment,
                          child: Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: IqSpace.s4,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Center(child: _WalletArrives()),
                                  const SizedBox(height: IqSpace.s4),
                                  Cue(
                                    at: WalletDurations.stagger * 2,
                                    length: WalletDurations.appear,
                                    rise: WalletTravel.rise,
                                    child: Text(
                                      'Withdrawal pending',
                                      textAlign: TextAlign.center,
                                      style: IqText.title.copyWith(
                                        color: IqColors.fg,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: IqSpace.s4),
                                  Cue(
                                    at: WalletDurations.stagger * 3,
                                    length: WalletDurations.appear,
                                    rise: WalletTravel.rise,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Cue(
                                          at: WalletDurations.mark,
                                          length: WalletDurations.mark,
                                          rise: 0,
                                          fade: false,
                                          remount: true,
                                          child: IqHighlight(
                                            text: naira(withdrawal.amountKobo),
                                          ),
                                        ),
                                        const SizedBox(width: IqSpace.s2),
                                        Flexible(
                                          child: Text(
                                            'to ${withdrawal.destination ?? ''}',
                                            style: IqText.body.copyWith(
                                              color: IqColors.fg2,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: IqSpace.s4),
                                  Cue(
                                    at: WalletDurations.stagger * 4,
                                    length: WalletDurations.appear,
                                    rise: WalletTravel.rise,
                                    child: _Fact(
                                      label: 'Available after',
                                      value: naira(
                                        data.totals.withdrawableKobo,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    IqSpace.s4,
                    IqSpace.s3,
                    IqSpace.s4,
                    IqSpace.s3,
                  ),
                  child: IqButton(
                    label: 'Back to wallet',
                    kind: IqButtonKind.secondary,
                    width: double.infinity,
                    onTap: () => context.go(Routes.wallet),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The fact row of 38:147: a hairline over a 43 tall row.
class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ColoredBox(
            color: IqColors.line,
            child: SizedBox(height: 1, width: double.infinity),
          ),
          SizedBox(
            height: 43,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    style: IqText.mono.copyWith(color: IqColors.fg3),
                  ),
                ),
                const SizedBox(width: IqSpace.s3),
                Text(
                  value,
                  style: IqText.figureSmall.copyWith(color: IqColors.fg),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Exp/Illustration Kind=Wallet arriving in its two layers (MOTION-SPEC
/// §5.29): the ink rises 16 and fades in over 320, the orange strap sweeps
/// in from +160. Reduced motion: the illustration itself.
class _WalletArrives extends StatelessWidget {
  const _WalletArrives();

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
          Cue(
            length: WalletDurations.morph,
            rise: WalletTravel.riseHero,
            child: _Layer(kind, keep: 'ink'),
          ),
          CueWipe(
            at: WalletDurations.stagger * 4,
            child: _Layer(kind, keep: 'accent'),
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

/// Keeps one named layer of an illustration and clears the other.
class _OnlyLayer extends ColorMapper {
  const _OnlyLayer(this.id);

  final String id;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) => id == null || id == this.id ? color : Colors.transparent;

  @override
  bool operator ==(Object other) => other is _OnlyLayer && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
