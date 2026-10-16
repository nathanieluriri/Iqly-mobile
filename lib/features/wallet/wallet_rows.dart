import 'package:flutter/widgets.dart';

import '../../core/money.dart';
import '../../core/navigation.dart';
import '../../core/relative_time.dart';
import '../../data/models.dart';
import '../../theme/theme.dart';
import '../../ui/brand_logo.dart';
import '../../ui/sample_logo.dart';
import '../../ui/wallet_row.dart';
import 'wallet_routes.dart';
import 'wallet_state.dart';

/// The hidden row figures of 331:15080.
const hiddenCredit = '+₦ • • • •';
const hiddenDebit = '−₦ • • • •';
const hiddenAmount = '₦ • • • •';

/// "−₦10,000.00": Figma sets the true minus sign.
String debit(int kobo) => '−${naira(kobo.abs())}';

IqWalletRowStatus rowStatus(Withdrawal w) => switch (w.status) {
  WithdrawalStatus.pending ||
  WithdrawalStatus.processing => IqWalletRowStatus.pending,
  WithdrawalStatus.completed => IqWalletRowStatus.completed,
  WithdrawalStatus.failed => IqWalletRowStatus.failed,
  WithdrawalStatus.reversed => IqWalletRowStatus.reversed,
};

/// One Exp/WalletRow for [item]: rewards name the business (or "Private
/// business", or "Referral bonus") and the brief; withdrawals the bank.
class WalletActivityRow extends StatelessWidget {
  const WalletActivityRow({
    super.key,
    required this.item,
    required this.briefs,
    required this.now,
    required this.hidden,
    required this.divider,
  });

  final ActivityItem item;

  /// From [rewardBriefsProvider]: the brief behind each submission reward.
  final Map<String, Brief> briefs;
  final DateTime now;
  final bool hidden;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final award = item.award;
    if (award != null) {
      final (title, detail, logo) = _reward(award);
      return IqWalletRow(
        kind: IqWalletRowKind.award,
        title: title,
        detail: 'Reward · $detail',
        amount: hidden ? hiddenCredit : '+${naira(award.amountKobo)}',
        when: timeAgo(award.createdAt, now),
        logo: logo,
        divider: divider,
      );
    }
    final w = item.withdrawal!;
    final status = rowStatus(w);
    final returned =
        status == IqWalletRowStatus.failed ||
        status == IqWalletRowStatus.reversed;
    return IqWalletRow(
      kind: IqWalletRowKind.withdrawal,
      title: 'To ${w.bankName ?? ''}',
      status: status,
      amount: hidden
          ? (returned ? hiddenAmount : hiddenDebit)
          : returned
          ? naira(w.amountKobo)
          : debit(w.amountKobo),
      when: timeAgo(w.createdAt, now),
      divider: divider,
      onTap: () => context.open(withdrawalPath(w.id)),
    );
  }

  (String, String, Widget) _reward(LedgerEntry award) {
    switch (award.source) {
      case RewardSource.submission:
        final brief = briefs[award.submissionId];
        final business = brief?.businessName;
        return (
          business ?? 'Private business',
          brief?.title ?? '',
          _logo(business),
        );
      case RewardSource.activation:
        return (
          award.business ?? 'Activation',
          award.note ?? 'activation',
          _logo(award.business),
        );
      case RewardSource.referral:
        return (
          'Referral bonus',
          award.note ?? 'referral',
          const IqBrandLogo(
            mark: IqBrandMark.logomark,
            tone: IqBrandTone.onDark,
            width: 40,
            height: 40,
          ),
        );
    }
  }

  static Widget _logo(String? business) {
    final brand = business == null
        ? IqSampleLogoBrand.private
        : IqSampleLogoBrand.values
                  .where((b) => business.startsWith(b.label))
                  .firstOrNull ??
              IqSampleLogoBrand.private;
    return IqSampleLogo(brand, size: 40);
  }
}

/// The white activity card of the B5 frames: line border, radius 18, 4
/// above and below the rows.
class ActivityCard extends StatelessWidget {
  const ActivityCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: IqSpace.s1),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: IqColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: IqColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
