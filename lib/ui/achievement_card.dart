import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'avatar.dart';
import 'icon.dart';
import 'pressable.dart';
import 'vector.dart';

/// Exp/AchievementCard: the contributor summary at the top of More. The
/// avatar with its pencil chip, the name, the iQL points and this month's
/// rank with one orange spark. The card opens Your profile (the screen
/// wraps it); the avatar or pencil opens the avatar picker
/// ([onAvatarTap]) and the rank the iQL points leaderboard ([onRankTap]).
/// An empty [rank] (not on this month's board yet) leaves the rank out.
class IqAchievementCard extends StatelessWidget {
  const IqAchievementCard({
    super.key,
    this.name = 'Adaeze Okafor',
    this.points = '1,240',
    this.rank = '#7',
    this.avatar = const IqPersonAvatar(IqAvatarPresets.person1),
    this.onAvatarTap,
    this.onRankTap,
  });

  final String name;
  final String points;
  final String rank;
  final IqAvatarSpec avatar;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onRankTap;

  static const Size size = Size(358, 88);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size.width,
      height: size.height,
      padding: const EdgeInsets.fromLTRB(14, 14, 18, 14),
      decoration: BoxDecoration(
        color: IqColors.tint,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          _Tappable(
            onTap: onAvatarTap,
            label: 'Change your avatar',
            child: SizedBox.square(
              dimension: 60,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: IqColors.bg,
                        width: 3,
                        strokeAlign: BorderSide.strokeAlignOutside,
                      ),
                    ),
                    child: IqAvatar(avatar, size: 60),
                  ),
                  Positioned(
                    left: 40,
                    top: 40,
                    child: Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: IqColors.accent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: IqColors.tint,
                          width: 2.5,
                          strokeAlign: BorderSide.strokeAlignOutside,
                        ),
                      ),
                      child: const IqIcon(
                        IqIcons.pencil,
                        size: 13,
                        color: IqColors.brand,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: IqText.cardTitle.copyWith(color: IqColors.fg),
                ),
                const SizedBox(height: IqSpace.s1),
                Row(
                  children: [
                    Text(
                      points,
                      style: IqText.smallStrong.copyWith(color: IqColors.fg),
                    ),
                    const SizedBox(width: IqSpace.s1),
                    Flexible(
                      child: Text(
                        'iQL points',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: IqText.small.copyWith(color: IqColors.fg2),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (rank.isNotEmpty) ...[
            const SizedBox(width: 14),
            _Tappable(
              onTap: onRankTap,
              label: '$rank this month',
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        rank,
                        style: IqText.figure.copyWith(color: IqColors.brand),
                      ),
                      Text(
                        'this month',
                        style: IqText.label.copyWith(color: IqColors.fg2),
                      ),
                    ],
                  ),
                  const Positioned(
                    left: 58.5,
                    top: -6.5,
                    child: IqVector(
                      'assets/vectors/achievement-card-spark.svg',
                      color: IqColors.accent,
                      width: 19,
                      height: 21,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tappable extends StatelessWidget {
  const _Tappable({
    required this.onTap,
    required this.label,
    required this.child,
  });

  final VoidCallback? onTap;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final onTap = this.onTap;
    if (onTap == null) return child;
    return IqPressable(
      onTap: onTap,
      semanticLabel: label,
      builder: (context, pressed) => PressDim(pressed: pressed, child: child),
    );
  }
}
