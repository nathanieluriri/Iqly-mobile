import 'package:flutter/widgets.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'cover_with_logo.dart';
import 'meta.dart';
import 'pressable.dart';
import 'sample_cover.dart';
import 'sample_logo.dart';

enum IqSubmissionCardStatus { underReview, winner, notSelected }

/// Exp/SubmissionCard: one submission. The brief photo with the business
/// logo floating on it, your title, the business and brief on one line, the
/// status chip and when you sent it. The Winner chip carries the amount;
/// Not selected dims the photo to .6.
///
/// [statusLabel] overrides the chip text ("Won ₦50,000") and [statusKind]
/// its Exp/Meta kind, as the B4 frames do (Deadline "Closes in 20 days").
/// The chip and the sent line wrap (gap 8, rows 6 apart).
class IqSubmissionCard extends StatelessWidget {
  const IqSubmissionCard({
    super.key,
    this.status = IqSubmissionCardStatus.underReview,
    this.title = 'Bring the shop to the hostel',
    this.brief = 'Unibooks · How should a campus bookshop sell online?',
    this.sent = '1 day ago',
    this.statusLabel,
    this.statusKind,
    this.cover = const IqSampleCover(IqSampleLogoBrand.unibooks, shot: 2),
    this.logo = const IqSampleLogo(IqSampleLogoBrand.unibooks),
    this.onTap,
  });

  final IqSubmissionCardStatus status;
  final String title;
  final String brief;
  final String sent;
  final String? statusLabel;
  final IqMetaKind? statusKind;
  final Widget cover;
  final Widget logo;
  final VoidCallback? onTap;

  IqMeta get _status => switch (status) {
    IqSubmissionCardStatus.underReview => IqMeta(
      kind: statusKind ?? IqMetaKind.time,
      label: statusLabel ?? 'Under review',
    ),
    IqSubmissionCardStatus.winner => IqMeta(
      kind: statusKind ?? IqMetaKind.done,
      label: statusLabel ?? 'Won ₦50,000',
    ),
    IqSubmissionCardStatus.notSelected => IqMeta(
      kind: statusKind ?? IqMetaKind.plain,
      label: statusLabel ?? 'Not selected',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return IqPressable(
      onTap: onTap,
      semanticLabel: title,
      builder: (context, pressed) => AnimatedScale(
        scale: pressed && !reduced ? IqScale.cardPress : 1,
        duration: pressMotion(context, pressed),
        curve: IqCurves.easeOut,
        child: LineCard(
          inset: true,
          child: Padding(
            padding: const EdgeInsets.all(IqSpace.s3),
            child: Row(
              children: [
                CoverWithLogo(
                  size: const Size.square(72),
                  radius: IqRadius.xl,
                  cover: cover,
                  logo: logo,
                  coverOpacity: status == IqSubmissionCardStatus.notSelected
                      ? 0.6
                      : 1,
                  logoOffset: const Offset(50, 50),
                  logoSize: 28,
                  logoInset: 2,
                ),
                const SizedBox(width: IqSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: IqText.bodyStrong.copyWith(color: IqColors.fg),
                      ),
                      const SizedBox(height: IqSpace.s1),
                      Text(
                        brief,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: IqText.small.copyWith(color: IqColors.fg2),
                      ),
                      const SizedBox(height: IqSpace.s1),
                      Padding(
                        padding: const EdgeInsets.only(top: IqSpace.s1),
                        child: Wrap(
                          spacing: IqSpace.s2,
                          runSpacing: IqSpace.s1p5,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _status,
                            Text(
                              sent,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: IqText.small.copyWith(color: IqColors.fg3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
