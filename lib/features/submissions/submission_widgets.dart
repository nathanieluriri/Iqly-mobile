import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import '../../ui/skeleton.dart';

/// 165:8524's skeleton row: a SubmissionCard's shape (card, 1 line, radius
/// 18, 16 padding) with the 72 photo and three bars, on the skeleton beat.
class SkeletonSubmissionCard extends StatelessWidget {
  const SkeletonSubmissionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      builder: (context, opacity) {
        Widget bar(double width, double height, double radius) =>
            FadeTransition(
              opacity: opacity,
              child: Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: IqColors.panel,
                  borderRadius: BorderRadius.circular(radius),
                ),
              ),
            );
        return Container(
          height: 106,
          padding: const EdgeInsets.all(IqSpace.s4),
          decoration: BoxDecoration(
            color: IqColors.card,
            border: Border.all(color: IqColors.line),
            borderRadius: BorderRadius.circular(IqRadius.xl2),
          ),
          child: Row(
            children: [
              bar(72, 72, IqRadius.xl),
              const SizedBox(width: IqSpace.s3),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bar(110, 12, 6),
                  const SizedBox(height: IqSpace.s2),
                  bar(200, 14, 7),
                  const SizedBox(height: IqSpace.s2),
                  bar(130, 24, 12),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
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
