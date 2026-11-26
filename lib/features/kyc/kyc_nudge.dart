import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/brand_logo.dart';
import '../../ui/illustration.dart';
import '../../ui/pressable.dart';
import 'kyc_status.dart';

class KycNudge extends StatelessWidget {
  const KycNudge({super.key, required this.status});

  final KycStatus status;

  @override
  Widget build(BuildContext context) {
    if (!status.needsCheck) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(IqSpace.s4, 0, IqSpace.s4, IqSpace.s3),
      child: IqPressable(
        semanticLabel: 'Verify your account',
        onTap: () => context.open(Routes.kyc),
        builder: (context, pressed) => Container(
          padding: const EdgeInsets.all(IqSpace.s3),
          decoration: BoxDecoration(
            color: pressed ? IqColors.tintStrong : IqColors.brandSoft,
            borderRadius: BorderRadius.circular(IqRadius.xl2),
          ),
          child: Row(
            children: [
              const IqBrandLogo(
                mark: IqBrandMark.logomark,
                width: 40,
                height: 40,
              ),
              const SizedBox(width: IqSpace.s2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verify your account',
                      style: IqText.bodyStrong.copyWith(color: IqColors.fg),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status.inReview
                          ? 'Your details are being reviewed.'
                          : 'Complete tier C${status.requiredTier} to withdraw.',
                      style: IqText.small.copyWith(color: IqColors.fg2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: IqSpace.s2),
              const IqFigure(IqFigures.writer, width: 72),
            ],
          ),
        ),
      ),
    );
  }
}
