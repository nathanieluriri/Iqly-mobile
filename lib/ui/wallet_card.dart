import 'package:flutter/widgets.dart';

import '../core/motion.dart';
import '../theme/theme.dart';

enum IqWalletCardBalance { available, onItsWay, earned }

enum IqWalletCardVisibility { shown, hidden }

/// Exp/WalletCard: the flat wallet. The balance tabs under it switch
/// [balance]; the eye in the header hides the figures. No dark slab, no
/// stacked stats. Wallet figures keep two decimals.
///
/// Owner over Figma (18 Oct): the Wallet screen drops the breakdown line
/// ([showBreakdown] false); the balance tabs already carry those figures.
///
/// Figma over brief: the card's own tab row and eye are hidden layers in
/// every variant; the screen carries both.
///
/// Motion (designer answer 28): a balance or visibility change crossfades
/// the figures, 200 ms; under reduced motion it cuts.
class IqWalletCard extends StatelessWidget {
  const IqWalletCard({
    super.key,
    this.balance = IqWalletCardBalance.available,
    this.visibility = IqWalletCardVisibility.shown,
    this.amount,
    this.label,
    this.caption,
    this.breakdown,
    this.showBreakdown = true,
  });

  final IqWalletCardBalance balance;
  final IqWalletCardVisibility visibility;
  final String? amount;
  final String? label;
  final String? caption;
  final String? breakdown;
  final bool showBreakdown;

  static const double height = 142;
  static const String hiddenAmount = '₦ • • • • •';

  String get _label =>
      label ??
      switch (balance) {
        IqWalletCardBalance.available => 'Available to withdraw',
        IqWalletCardBalance.onItsWay => 'On its way to your bank',
        IqWalletCardBalance.earned => 'Earned so far',
      };

  String get _amount =>
      amount ??
      switch (balance) {
        IqWalletCardBalance.available => '₦12,500.00',
        IqWalletCardBalance.onItsWay => '₦10,000.00',
        IqWalletCardBalance.earned => '₦62,500.00',
      };

  String get _caption =>
      caption ??
      switch (balance) {
        IqWalletCardBalance.available =>
          'Ready to withdraw to Access Bank ••6789',
        IqWalletCardBalance.onItsWay =>
          'To Access Bank ••6789 · usually arrives in minutes',
        IqWalletCardBalance.earned => 'From 2 winning submissions',
      };

  String get _breakdown =>
      breakdown ??
      switch (balance) {
        IqWalletCardBalance.available =>
          '₦10,000.00 on its way · ₦62,500.00 earned so far',
        IqWalletCardBalance.onItsWay =>
          '₦12,500.00 available · ₦62,500.00 earned so far',
        IqWalletCardBalance.earned =>
          '₦12,500.00 available · ₦10,000.00 on its way',
      };

  @override
  Widget build(BuildContext context) {
    final hidden = visibility == IqWalletCardVisibility.hidden;
    final fade = motion(context, IqDurations.swap);
    return Container(
      height: height,
      padding: const EdgeInsets.all(IqSpace.s5),
      decoration: BoxDecoration(
        color: IqColors.tint,
        borderRadius: BorderRadius.circular(IqRadius.xl2),
      ),
      child: AnimatedSwitcher(
        duration: fade,
        layoutBuilder: (current, previous) => Stack(
          alignment: AlignmentDirectional.topStart,
          children: [...previous, ?current],
        ),
        child: Column(
          key: ValueKey((balance, hidden, _amount)),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: IqText.smallStrong.copyWith(color: IqColors.fg2),
            ),
            const SizedBox(height: IqSpace.s1p5),
            Semantics(
              label: hidden ? 'Balance hidden' : null,
              excludeSemantics: hidden,
              child: Text(
                hidden ? hiddenAmount : _amount,
                maxLines: 1,
                style: IqText.figure.copyWith(color: IqColors.fg),
              ),
            ),
            const SizedBox(height: IqSpace.s1p5),
            Text(
              _caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: IqText.small.copyWith(color: IqColors.fg2),
            ),
            if (showBreakdown) ...[
              const SizedBox(height: IqSpace.s1p5),
              Text(
                _breakdown,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: IqText.small.copyWith(color: IqColors.fg3),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
