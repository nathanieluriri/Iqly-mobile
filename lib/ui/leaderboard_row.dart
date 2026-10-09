import 'package:flutter/widgets.dart';

import '../core/motion.dart';
import '../theme/theme.dart';

/// Figma State: [you] is the signed-in contributor's own row.
enum IqLeaderboardRowState { standard, you }

/// Exp/LeaderboardRow: rank disc, contributor name (contributorName or
/// "Anonymous"), entry title and amount awarded. 56 tall, no divider; stack
/// rows with an 8 px gap.
///
/// Figma over brief: on You the rank number stays brand ink on the orange disc.
///
/// [rankDelay] pops the rank disc in after that long (MOTION-SPEC §5.33:
/// the You row's disc at its arrive + 120); null shows it at once.
class IqLeaderboardRow extends StatelessWidget {
  const IqLeaderboardRow({
    super.key,
    this.rank = '1',
    this.name = 'Chinedu A.',
    this.entry = 'Bundles reset on Sunday',
    this.showEntry = true,
    this.amount = '₦25,000',
    this.showAmount = true,
    this.state = IqLeaderboardRowState.standard,
    this.accentRank = false,
    this.rankDelay,
  });

  final String rank;
  final String name;
  final String entry;
  final bool showEntry;
  final String amount;
  final bool showAmount;
  final IqLeaderboardRowState state;

  /// Not a Figma prop: every board frame (B13 193:9779, 225:10747,
  /// 548:25018) overrides each row's disc to accent with a card number.
  final bool accentRank;
  final Duration? rankDelay;

  static const double height = 56;
  static const double gap = IqSpace.s2;

  @override
  Widget build(BuildContext context) {
    final you = state == IqLeaderboardRowState.you;
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: IqSpace.s3),
      decoration: BoxDecoration(
        color: you ? IqColors.tint : IqColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _pop(
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: you || accentRank
                    ? IqColors.accent
                    : IqColors.tintStrong,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                rank,
                style: IqText.label.copyWith(
                  color: accentRank ? IqColors.card : IqColors.brand,
                ),
              ),
            ),
          ),
          const SizedBox(width: IqSpace.s3),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: IqText.bodyStrong.copyWith(color: IqColors.fg),
                ),
                if (showEntry)
                  Text(
                    entry,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: IqText.small.copyWith(color: IqColors.fg3),
                  ),
              ],
            ),
          ),
          if (showAmount) ...[
            const SizedBox(width: IqSpace.s3),
            Text(
              amount,
              style: IqText.figureSmall.copyWith(color: IqColors.fg),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pop(Widget disc) {
    final delay = rankDelay;
    return delay == null ? disc : Pop(delay: delay, child: disc);
  }
}
