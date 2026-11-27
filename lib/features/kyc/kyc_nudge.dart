import 'package:flutter/material.dart';

import '../../core/navigation.dart';
import '../../data/kyc_service.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/brand_logo.dart';
import '../../ui/illustration.dart';
import '../../ui/pressable.dart';

enum KycNudgeSurface { discover, submission, withdrawal }

typedef KycNudgeCopy = ({String title, String body});

KycNudgeCopy? kycNudgeCopy({
  KycStatus? status,
  KycRefused? error,
  KycNudgeSurface surface = KycNudgeSurface.discover,
}) {
  if (error != null) {
    return (
      title: 'Verification status unavailable',
      body: 'We couldn’t refresh your verification status. Tap to retry.',
    );
  }
  if (status == null) return null;
  if (status.inReview) {
    return (
      title: 'Verification in review',
      body: 'Your details are being reviewed. Check back soon.',
    );
  }
  if (surface == KycNudgeSurface.submission) {
    if (status.canSubmit) return null;
    return (
      title: 'Verify to submit',
      body: status.ninOnly
          ? 'Confirm your NIN to unlock challenge submissions.'
          : 'Complete identity verification to unlock challenge submissions.',
    );
  }
  if (surface == KycNudgeSurface.withdrawal) {
    if (status.canWithdraw) return null;
    return (
      title: 'Verify to withdraw',
      body: 'Complete Tier ${status.requiredTier} to withdraw.',
    );
  }
  if (status.canSubmit && status.canWithdraw) return null;
  if (!status.canSubmit && !status.canWithdraw) {
    return (
      title: 'Verify to submit and withdraw',
      body: status.ninOnly
          ? 'Confirm your NIN to unlock challenge submissions and withdrawals.'
          : 'Complete identity verification to submit and withdraw.',
    );
  }
  if (!status.canSubmit) {
    return (
      title: 'Verify to submit',
      body: status.ninOnly
          ? 'Confirm your NIN to unlock challenge submissions.'
          : 'Complete identity verification to unlock challenge submissions.',
    );
  }
  return (
    title: 'Verify to withdraw',
    body: 'Complete Tier ${status.requiredTier} to withdraw.',
  );
}

class KycNudge extends StatelessWidget {
  const KycNudge({
    super.key,
    required this.status,
    this.error,
    this.surface = KycNudgeSurface.discover,
  });

  final KycStatus? status;
  final KycRefused? error;
  final KycNudgeSurface surface;

  @override
  Widget build(BuildContext context) {
    final copy = kycNudgeCopy(status: status, error: error, surface: surface);
    if (copy == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(IqSpace.s4, 0, IqSpace.s4, IqSpace.s3),
      child: IqPressable(
        semanticLabel: copy.title,
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
                      copy.title,
                      style: IqText.bodyStrong.copyWith(color: IqColors.fg),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      copy.body,
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
