import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'button.dart';
import 'cover_with_logo.dart';
import 'icon.dart';
import 'pressable.dart';

enum IqWebPollRowStatus { open, answered }

/// Exp/Web/PollRow (local, sync to DS; 1737:19279): a business's quick
/// poll in the list, 24 in. The cover with the logo, the business over the
/// first question and the poll's length, when it closes, then Answer or,
/// once answered, Answered over See results. The whole row takes the tap.
class IqWebPollRow extends StatelessWidget {
  const IqWebPollRow({
    super.key,
    required this.business,
    required this.question,
    required this.detail,
    required this.closes,
    required this.cover,
    required this.logo,
    this.status = IqWebPollRowStatus.open,
    this.onTap,
  });

  final String business;
  final String question;
  final String detail;
  final String closes;
  final Widget cover;
  final Widget logo;
  final IqWebPollRowStatus status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final open = status == IqWebPollRowStatus.open;
    return IqPressable(
      onTap: onTap,
      tactile: false,
      semanticLabel: '$business, $question',
      builder: (context, pressed) => Container(
        color: pressed ? IqColors.secondary : IqColors.card,
        padding: const EdgeInsets.symmetric(
          horizontal: IqSpace.s6,
          vertical: IqSpace.s4,
        ),
        child: Row(
          children: [
            CoverWithLogo(
              size: const Size.square(64),
              radius: IqRadius.xl,
              cover: cover,
              logo: logo,
              logoOffset: const Offset(44, 44),
              logoSize: 28,
              logoInset: 2,
            ),
            const SizedBox(width: IqSpace.s6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    business,
                    style: IqWebText.metaCaption.copyWith(color: IqColors.fg3),
                  ),
                  const SizedBox(height: IqSpace.s0p5),
                  Text(
                    question,
                    style: IqWebText.headingCardSection.copyWith(
                      color: IqColors.fg,
                    ),
                  ),
                  const SizedBox(height: IqSpace.s0p5),
                  Text(
                    detail,
                    style: IqWebText.metaCaption.copyWith(color: IqColors.fg2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: IqSpace.s6),
            const IqIcon(IqIcons.timer, size: 14, color: IqColors.brand),
            const SizedBox(width: IqSpace.s1p5),
            SizedBox(
              width: 120,
              child: Text(
                closes,
                style: IqWebText.bodySmall.copyWith(color: IqColors.fg),
              ),
            ),
            const SizedBox(width: IqSpace.s6),
            SizedBox(
              width: 120,
              child: open
                  ? IqButton(
                      label: 'Answer',
                      kind: IqButtonKind.secondary,
                      showIcon: false,
                      width: 120,
                      height: 44,
                      onTap: onTap,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const IqIcon(
                              IqIcons.check,
                              size: 14,
                              color: IqColors.ok,
                            ),
                            const SizedBox(width: IqSpace.s1p5),
                            Text(
                              'Answered',
                              style: IqWebText.bodySmall.copyWith(
                                color: IqColors.fg2,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'See results',
                          style: IqWebText.metaCaption.copyWith(
                            color: IqColors.primary,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
