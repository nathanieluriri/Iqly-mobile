import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../core/motion.dart';
import '../../core/relative_time.dart';
import '../../data/models.dart';
import '../../theme/theme.dart';
import '../../ui/highlight.dart';
import '../../ui/pressable.dart';
import 'submissions_state.dart';

/// The status as a highlighter chip: Under review lilac, Winner green, Not
/// selected plain fg3 text.
class SubmissionStatusMark extends StatelessWidget {
  const SubmissionStatusMark({super.key, required this.status});

  final SubmissionStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      SubmissionStatus.pending || SubmissionStatus.scored => IqHighlight(
        text: status.label,
        tone: IqHighlightTone.lilac,
      ),
      SubmissionStatus.winner => IqHighlight(
        text: status.label,
        tone: IqHighlightTone.green,
      ),
      SubmissionStatus.filteredOut => Text(
        status.label,
        style: IqText.small.copyWith(color: IqColors.fg3),
      ),
    };
  }
}

class SubmissionRow extends StatelessWidget {
  const SubmissionRow({
    super.key,
    required this.item,
    required this.now,
    this.onTap,
  });

  final SubmissionItem item;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final sent = 'Sent ${timeAgoShort(item.submission.createdAt, now)}';
    final award = item.awardKobo;
    final meta = award == null ? sent : '$sent · ${naira(award)} awarded';
    return IqPressable(
      onTap: onTap,
      semanticLabel:
          '${item.submission.title}, ${item.briefLine}, ${item.status.label}',
      builder: (context, pressed) => Padding(
        padding: const EdgeInsets.symmetric(vertical: IqSpace.s3),
        child: ExcludeSemantics(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.submission.title,
                      style: IqText.cardTitle.copyWith(color: IqColors.fg),
                    ),
                    const SizedBox(height: IqSpace.s1),
                    Text(
                      item.briefLine,
                      style: IqText.small.copyWith(color: IqColors.fg2),
                    ),
                    const SizedBox(height: IqSpace.s1),
                    Text(
                      meta.toUpperCase(),
                      style: IqText.mono.copyWith(color: IqColors.fg3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: IqSpace.s3),
              SubmissionStatusMark(status: item.status),
            ],
          ),
        ),
      ),
    );
  }
}

class Hairline extends StatelessWidget {
  const Hairline({super.key});

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: IqColors.line,
    child: SizedBox(height: 1, width: double.infinity),
  );
}

/// The standalone Figma "Skeleton" (113:3524) the list loading frames use:
/// a Color/panel card, radius 20, pulsing like Exp/Skeleton. It has no spec
/// in the design system yet, so it lives with the row.
class SkeletonCard extends StatefulWidget {
  const SkeletonCard({super.key, this.height = 96, this.radius = 20});

  final double height;

  /// The Wallet failed frame (165:8792) sets 12 on its 64 tall rows.
  final double radius;

  @override
  State<SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: IqDurations.skeletonPulse,
  );
  late final Animation<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.5, end: 1), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 1, end: 0.5), weight: 1),
  ]).chain(CurveTween(curve: IqCurves.easeInOut)).animate(_pulse);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
      _pulse.value = 0.5;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final card = Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: IqColors.panel,
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    );
    if (still) return card;
    return FadeTransition(opacity: _opacity, child: card);
  }
}
