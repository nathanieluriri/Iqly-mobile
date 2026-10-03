import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/highlight.dart';
import '../../ui/illustration.dart';
import '../../ui/top_bar.dart';
import 'wallet_state.dart';

/// B5 · Withdrawal pending (38:147), a moment: the Wallet illustration
/// arrives (ink rises 16 over 320, the strap sweeps in from +160), the
/// title appears at +80, the amount line at +120 with its Highlight wiping
/// from +240, AVAILABLE AFTER at +160. The success haptic plays as the
/// sheet hands over (spec 7.1, 5.29).
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
                      : Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: IqSpace.s4,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Center(child: _WalletArrives()),
                                const SizedBox(height: IqSpace.s4),
                                Appear(
                                  delay: IqDurations.stagger * 2,
                                  child: Text(
                                    'Withdrawal pending',
                                    textAlign: TextAlign.center,
                                    style: IqText.title.copyWith(
                                      color: IqColors.fg,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: IqSpace.s4),
                                Appear(
                                  delay: IqDurations.stagger * 3,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _FreshAt(
                                        at: IqDurations.mark,
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
                                Appear(
                                  delay: IqDurations.stagger * 4,
                                  child: _Fact(
                                    label: 'Available after',
                                    value: naira(data.totals.withdrawableKobo),
                                  ),
                                ),
                              ],
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

/// Exp/Illustration Kind=Wallet arriving in its two layers (spec 5.29): the
/// ink rises 16 and fades in over 320, then the orange strap alone sweeps
/// across, 240 from +160, under the ink as the art stacks them. Reduced
/// motion: the illustration itself.
class _WalletArrives extends StatelessWidget {
  const _WalletArrives();

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

/// Builds [child] afresh at [at], so a part that moves on its own (the
/// Highlight's wipe) starts then; until then it holds its place unseen.
class _FreshAt extends StatefulWidget {
  const _FreshAt({required this.at, required this.child});

  final Duration at;
  final Widget child;

  @override
  State<_FreshAt> createState() => _FreshAtState();
}

class _FreshAtState extends State<_FreshAt> {
  Timer? _timer;
  bool _fresh = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_fresh || _timer != null) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _fresh = true;
      return;
    }
    _timer = Timer(widget.at, () {
      if (mounted) setState(() => _fresh = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_fresh) {
      return KeyedSubtree(key: const ValueKey(true), child: widget.child);
    }
    return Opacity(
      opacity: 0,
      child: KeyedSubtree(key: const ValueKey(false), child: widget.child),
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
