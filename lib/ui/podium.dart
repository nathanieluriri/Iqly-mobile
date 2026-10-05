import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'sample_avatar.dart';

/// Exp/Podium: the top three of a brief leaderboard. The centre column is
/// first (amber ring, medal, brand pedestal); second and third step down
/// on lilac pedestals. Rows from fourth place are Exp/LeaderboardRow.
class IqPodium extends StatelessWidget {
  const IqPodium({
    super.key,
    this.name1 = 'Chinedu A.',
    this.amount1 = '₦175k',
    this.name2 = 'Tunde F.',
    this.amount2 = '₦100k',
    this.name3 = 'Anonymous',
    this.amount3 = '₦62.5k',
    this.avatar1 = const IqSampleAvatar(size: 64),
    this.avatar2 = const IqSampleAvatar(
      person: IqSampleAvatarPerson.person2,
      size: 52,
    ),
    this.avatar3 = const IqSampleAvatar(
      person: IqSampleAvatarPerson.person3,
      size: 52,
    ),
  });

  final String name1;
  final String amount1;
  final String name2;
  final String amount2;
  final String name3;
  final String amount3;
  final Widget avatar1;
  final Widget avatar2;
  final Widget avatar3;

  static const double height = 236;
  static const double column = 110;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _Place(
            rank: 2,
            name: name2,
            amount: amount2,
            avatar: avatar2,
            ring: IqColors.line2,
            medal: IqColors.fg3,
            pedestal: 56,
          ),
          const SizedBox(width: IqSpace.s1p5),
          _Place(
            rank: 1,
            name: name1,
            amount: amount1,
            avatar: avatar1,
            ring: IqPrimitives.amber500,
            medal: IqPrimitives.amber500,
            pedestal: 84,
          ),
          const SizedBox(width: IqSpace.s1p5),
          _Place(
            rank: 3,
            name: name3,
            amount: amount3,
            avatar: avatar3,
            ring: IqColors.accentStrong,
            medal: IqColors.accentStrong,
            pedestal: 40,
          ),
        ],
      ),
    );
  }
}

class _Place extends StatelessWidget {
  const _Place({
    required this.rank,
    required this.name,
    required this.amount,
    required this.avatar,
    required this.ring,
    required this.medal,
    required this.pedestal,
  });

  final int rank;
  final String name;
  final String amount;
  final Widget avatar;
  final Color ring;
  final Color medal;
  final double pedestal;

  bool get _first => rank == 1;

  @override
  Widget build(BuildContext context) {
    final face = _first ? 64.0 : 52.0;
    final circle = face + 8;
    return SizedBox(
      width: IqPodium.column,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            width: circle,
            height: circle + 8,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  top: -4,
                  child: Container(
                    width: circle,
                    height: circle,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: ring, width: 3),
                    ),
                  ),
                ),
                Positioned(
                  left: 4,
                  top: 0,
                  child: SizedBox.square(dimension: face, child: avatar),
                ),
                Positioned(
                  left: circle / 2 - 13,
                  top: face - 10,
                  child: Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: medal,
                      shape: BoxShape.circle,
                      border: Border.all(color: IqColors.card, width: 2),
                    ),
                    child: Text(
                      '$rank',
                      style: IqText.label.copyWith(
                        color: _first ? IqColors.brand : IqColors.card,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: IqText.bodyStrong.copyWith(color: IqColors.fg),
          ),
          Text(
            amount,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: IqText.figureSmall.copyWith(color: IqColors.fg),
          ),
          const SizedBox(height: IqSpace.s2),
          Container(
            height: pedestal,
            width: double.infinity,
            padding: const EdgeInsets.only(top: IqSpace.s2p5),
            alignment: Alignment.topCenter,
            decoration: BoxDecoration(
              color: _first ? IqColors.brand : IqColors.tint,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Text(
              '$rank',
              style: IqText.figure.copyWith(
                color: _first ? IqColors.accent : IqColors.brand,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
