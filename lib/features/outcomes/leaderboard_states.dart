import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../theme/theme.dart';
import '../../ui/empty_state.dart';
import '../../ui/illustration.dart';
import '../splash/patch_dialog.dart';
import 'leaderboard_screen.dart';

/// The filling mark while a board loads, the same wait the account uses.
class LeaderboardLoading extends StatelessWidget {
  const LeaderboardLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading the leaderboard',
      liveRegion: true,
      child: const Center(child: IqFillLoader()),
    );
  }
}

/// A board with no one on it yet, or one that could not load ([onRetry]).
class LeaderboardEmpty extends StatelessWidget {
  const LeaderboardEmpty({super.key, this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final failed = onRetry != null;
    return IqEmptyFill(
      child: IqEmptyState(
        art: const IqIllustration(
          IqIllustrations.trophy,
          entrance: IqIllustrationEntrance.rise,
        ),
        title: failed
            ? 'Couldn’t load the leaderboard'
            : 'No one is on the leaderboard yet',
        body: failed
            ? 'Check your connection and try again.'
            : 'The top spot is open. Win a brief to claim it.',
        action: failed ? 'Try again' : null,
        onAction: onRetry,
      ),
    );
  }
}

/// One of the first three on a board that has no one below them.
class LeaderboardSpot {
  const LeaderboardSpot({
    required this.name,
    required this.amount,
    this.detail = '',
    this.you = false,
  });

  final String name;
  final String amount;
  final String detail;
  final bool you;
}

/// A board of one, two or three people, given the room a full podium
/// shares with the rows: one person stands alone under falling confetti,
/// two or three stand on tall pedestals that rise in. Reduced motion: the
/// pedestals stand at full height and the confetti holds still.
class LeaderboardFew extends StatelessWidget {
  const LeaderboardFew({super.key, required this.spots})
    : assert(spots.length > 0 && spots.length <= 3);

  final List<LeaderboardSpot> spots;

  @override
  Widget build(BuildContext context) {
    if (spots.length == 1) return _Solo(spot: spots.first);
    final order = spots.length == 2 ? const [1, 0] : const [1, 0, 2];
    return Padding(
      padding: const EdgeInsets.only(top: IqSpace.s6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (i, rank) in order.indexed) ...[
            if (i > 0) const SizedBox(width: IqSpace.s2),
            Expanded(
              child: _Place(
                rank: rank + 1,
                spot: spots[rank],
                pedestal: const [168.0, 120.0, 88.0][rank],
                delay: IqDurations.stagger * 2 * (spots.length - 1 - rank),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Color _ring(int rank) => switch (rank) {
  1 => IqPrimitives.amber500,
  2 => IqColors.line2,
  _ => IqColors.accentStrong,
};

Color _medal(int rank) => switch (rank) {
  1 => IqPrimitives.amber500,
  2 => IqColors.fg3,
  _ => IqColors.accentStrong,
};

class _Solo extends StatelessWidget {
  const _Solo({required this.spot});

  final LeaderboardSpot spot;

  static const double face = 112;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          ExcludeSemantics(
            child: FallingConfetti(
              asset: IqFigures.cheer.asset,
              width: IqFigure.designWidth,
              height: IqFigure.designHeight,
              showFigure: false,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: IqSpace.s8),
            child: Appear(
              child: Column(
                children: [
                  Text(
                    'Top of the board'.toUpperCase(),
                    style: IqText.mono.copyWith(color: IqColors.fg2),
                  ),
                  const SizedBox(height: IqSpace.s4),
                  _Medalled(
                    rank: 1,
                    face: face,
                    child: leaderboardAvatar(spot.name, face),
                  ),
                  const SizedBox(height: IqSpace.s5),
                  _Caption(spot: spot, large: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Place extends StatelessWidget {
  const _Place({
    required this.rank,
    required this.spot,
    required this.pedestal,
    required this.delay,
  });

  final int rank;
  final LeaderboardSpot spot;
  final double pedestal;
  final Duration delay;

  bool get _first => rank == 1;

  @override
  Widget build(BuildContext context) {
    final rise = motion(context, IqDurations.screen);
    return MergeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Medalled(
            rank: rank,
            face: _first ? 88 : 72,
            child: leaderboardAvatar(spot.name, _first ? 88 : 72),
          ),
          const SizedBox(height: IqSpace.s3),
          _Caption(spot: spot),
          const SizedBox(height: IqSpace.s3),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: rise == Duration.zero ? 1 : 0, end: 1),
            duration: rise + delay,
            curve: Interval(
              rise == Duration.zero
                  ? 0
                  : delay.inMilliseconds / (rise + delay).inMilliseconds,
              1,
              curve: IqCurves.easeOut,
            ),
            builder: (context, t, child) => Container(
              height: pedestal * t,
              width: double.infinity,
              padding: const EdgeInsets.only(top: IqSpace.s3),
              alignment: Alignment.topCenter,
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                color: _first ? IqColors.brand : IqColors.tint,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: child,
            ),
            child: ExcludeSemantics(
              child: Text(
                '$rank',
                style: IqText.headline.copyWith(
                  color: _first ? IqColors.accent : IqColors.brand,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption({required this.spot, this.large = false});

  final LeaderboardSpot spot;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          spot.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: (large ? IqText.title : IqText.bodyStrong).copyWith(
            color: IqColors.fg,
          ),
        ),
        if (spot.you && spot.name != 'You') ...[
          const SizedBox(height: IqSpace.s1),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: IqSpace.s2,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: IqColors.accentSoft,
              borderRadius: BorderRadius.circular(IqRadius.full),
            ),
            child: Text(
              'You'.toUpperCase(),
              style: IqText.mono.copyWith(color: IqColors.brand),
            ),
          ),
        ],
        const SizedBox(height: IqSpace.s1),
        Text(
          spot.amount,
          maxLines: 1,
          textAlign: TextAlign.center,
          style: (large ? IqText.figure : IqText.figureSmall).copyWith(
            color: IqColors.fg,
          ),
        ),
        if (spot.detail.isNotEmpty) ...[
          const SizedBox(height: IqSpace.s1),
          Text(
            large ? spot.detail : spot.detail.replaceAll(' · ', '\n'),
            maxLines: large ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: IqText.small.copyWith(color: IqColors.fg2),
          ),
        ],
      ],
    );
  }
}

/// An avatar in its rank's ring with the rank's medal on its foot.
class _Medalled extends StatelessWidget {
  const _Medalled({required this.rank, required this.face, this.child});

  final int rank;
  final double face;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final circle = face + 10;
    final medal = face < 100 ? 28.0 : 36.0;
    return SizedBox(
      width: circle,
      height: circle + medal / 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: circle,
            height: circle,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _ring(rank), width: 4),
            ),
          ),
          Positioned(
            left: 5,
            top: 5,
            child: SizedBox.square(dimension: face, child: child),
          ),
          Positioned(
            left: circle / 2 - medal / 2,
            top: circle - medal / 2 - 2,
            child: Container(
              width: medal,
              height: medal,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _medal(rank),
                shape: BoxShape.circle,
                border: Border.all(color: IqColors.card, width: 2),
              ),
              child: ExcludeSemantics(
                child: Text(
                  '$rank',
                  style: IqText.label.copyWith(
                    color: rank == 1 ? IqColors.brand : IqColors.card,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
