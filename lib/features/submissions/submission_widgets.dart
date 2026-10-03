import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../core/motion.dart';
import '../../core/relative_time.dart';
import '../../data/models.dart';
import '../../theme/theme.dart';
import '../../ui/highlight.dart';
import '../../ui/pressable.dart';
import '../../ui/skeleton.dart';
import 'submissions_state.dart';

/// The status as a highlighter chip: Under review lilac, Winner green, Not
/// selected plain fg3 text. [wipe] false shows the marker at once.
class SubmissionStatusMark extends StatelessWidget {
  const SubmissionStatusMark({
    super.key,
    required this.status,
    this.wipe = true,
  });

  final SubmissionStatus status;
  final bool wipe;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      SubmissionStatus.pending || SubmissionStatus.scored => IqHighlight(
        text: status.label,
        tone: IqHighlightTone.lilac,
        wipe: wipe,
      ),
      SubmissionStatus.winner => IqHighlight(
        text: status.label,
        tone: IqHighlightTone.green,
        wipe: wipe,
      ),
      SubmissionStatus.filteredOut => Text(
        status.label,
        style: IqText.small.copyWith(color: IqColors.fg3),
      ),
    };
  }
}

/// The status mark as the element a submission's row and its detail header
/// share (spec 4.4, build extension): it flies with the push (300 ms, back
/// in 240, ease-in-out) and never wipes again in flight. Off under reduced
/// motion, with the push.
class SubmissionStatusHero extends StatelessWidget {
  const SubmissionStatusHero({
    super.key,
    required this.id,
    required this.status,
    this.wipe = true,
  });

  final String id;
  final SubmissionStatus status;
  final bool wipe;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: ('submission-status', id),
      curve: IqCurves.easeInOut,
      createRectTween: (begin, end) => RectTween(begin: begin, end: end),
      flightShuttleBuilder: (context, animation, direction, from, to) =>
          Material(
            type: MaterialType.transparency,
            child: SubmissionStatusMark(status: status, wipe: false),
          ),
      child: SubmissionStatusMark(status: status, wipe: wipe),
    );
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
      builder: (context, pressed) => Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -IqSpace.s2,
            right: -IqSpace.s2,
            top: 0,
            bottom: 0,
            child: AnimatedContainer(
              duration: pressed ? IqDurations.dim : IqDurations.release,
              curve: IqCurves.easeOut,
              decoration: BoxDecoration(
                color: pressed
                    ? IqColors.tint
                    : IqColors.tint.withValues(alpha: 0),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Padding(
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
                        // The naira sign comes from the fallback font, whose
                        // taller line would push the row down a point.
                        Text(
                          meta.toUpperCase(),
                          strutStyle: _monoStrut,
                          style: IqText.mono.copyWith(color: IqColors.fg3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: IqSpace.s3),
                  SubmissionStatusHero(id: item.id, status: item.status),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final _monoStrut = StrutStyle.fromTextStyle(
  IqText.mono,
  forceStrutHeight: true,
);

class Hairline extends StatelessWidget {
  const Hairline({super.key});

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: IqColors.line,
    child: SizedBox(height: 1, width: double.infinity),
  );
}

/// The standalone Figma "Skeleton" (113:3524) the list loading frames use:
/// a Color/panel card, radius 20, pulsing on the screen's skeleton beat like
/// Exp/Skeleton (spec 5.15). It has no spec in the design system yet, so it
/// lives with the row.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.height = 96, this.radius = 20});

  final double height;

  /// The Wallet failed frame (165:8792) sets 12 on its 64 tall rows.
  final double radius;

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      builder: (context, opacity) => FadeTransition(
        opacity: opacity,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: IqColors.panel,
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
    );
  }
}
