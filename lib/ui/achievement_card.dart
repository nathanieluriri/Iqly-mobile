import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'perforation.dart';
import 'sample_avatar.dart';
import 'vector.dart';

/// Exp/AchievementCard: the contributor pass in the wallet-pass idiom. An
/// ink top with the pass line, the name and avatar, the lifetime amount as
/// the primary field on a highlighter mark; a perforation with side
/// notches; a paper bottom with three fields and a barcode with the member
/// code. Mono labels are upper case.
class IqAchievementCard extends StatelessWidget {
  const IqAchievementCard({
    super.key,
    this.eyebrow = 'iQLY · Contributor pass',
    this.name = 'Adaeze Okafor',
    this.amountLabel = 'Lifetime earned',
    this.amount = '₦62,500',
    this.secondaryLabel = 'Last win',
    this.secondary = 'Volt Riders',
    this.field1Label = 'Since',
    this.field1 = 'Sep 2026',
    this.field2Label = 'Submissions',
    this.field2 = '5',
    this.field3Label = 'Wins',
    this.field3 = '2',
    this.code = 'ADAEZE24',
    this.avatar = const IqSampleAvatar(size: 44),
  });

  final String eyebrow;
  final String name;
  final String amountLabel;
  final String amount;
  final String secondaryLabel;
  final String secondary;
  final String field1Label;
  final String field1;
  final String field2Label;
  final String field2;
  final String field3Label;
  final String field3;
  final String code;
  final Widget avatar;

  static const Size size = Size(358, 240);

  /// The hand-drawn barcode's bar widths, left to right.
  static const List<double> bars = [
    2, 1, 3, 1, 2, 1, 3, 2, 1, 2, 3, 1, 2, 1, 2, 3, 1, 2, 1, 2, 1, //
  ];

  @override
  Widget build(BuildContext context) {
    final onInk = IqText.mono.copyWith(
      color: IqColors.primaryFg.withValues(alpha: 0.7),
    );
    return SizedBox.fromSize(
      size: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: ColoredBox(
              color: IqColors.card,
              child: Column(
                children: [
                  Container(
                    height: 157,
                    color: IqColors.primary,
                    padding: const EdgeInsets.all(IqSpace.s5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    eyebrow.toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: onInk,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: IqText.headline.copyWith(
                                      color: IqColors.primaryFg,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: IqSpace.s3),
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: IqColors.primaryFg,
                                  width: 2,
                                  strokeAlign: BorderSide.strokeAlignOutside,
                                ),
                              ),
                              child: avatar,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(amountLabel.toUpperCase(), style: onInk),
                                const SizedBox(height: IqSpace.s1),
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    const Positioned(
                                      left: -2,
                                      top: 11,
                                      right: -6,
                                      height: 18,
                                      child: IqVector(
                                        'assets/vectors/achievement-card-marker.svg',
                                        color: IqColors.accent,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: IqSpace.s1,
                                        right: 6,
                                      ),
                                      child: Text(
                                        amount,
                                        maxLines: 1,
                                        style: IqText.figure.copyWith(
                                          color: IqColors.primaryFg,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Spacer(),
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: IqSpace.s1,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    secondaryLabel.toUpperCase(),
                                    textAlign: TextAlign.right,
                                    style: onInk,
                                  ),
                                  const SizedBox(height: IqSpace.s1),
                                  Text(
                                    secondary,
                                    maxLines: 1,
                                    textAlign: TextAlign.right,
                                    style: IqText.bodyStrong.copyWith(
                                      color: IqColors.primaryFg,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(
                    height: 1,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: IqSpace.s5),
                      child: RotatedBox(
                        quarterTurns: 1,
                        child: IqPerforation(
                          color: IqColors.line,
                          roundCap: false,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        IqSpace.s5,
                        IqSpace.s4,
                        IqSpace.s5,
                        18,
                      ),
                      child: Row(
                        children: [
                          _field(field1Label, field1),
                          const SizedBox(width: IqSpace.s4),
                          _field(field2Label, field2),
                          const SizedBox(width: IqSpace.s4),
                          _field(field3Label, field3),
                          const Spacer(),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                height: 28,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    for (var i = 0; i < bars.length; i++) ...[
                                      if (i > 0) const SizedBox(width: 1.5),
                                      SizedBox(
                                        width: bars[i],
                                        child: const ColoredBox(
                                          color: IqColors.fg,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: IqSpace.s1),
                              Text(
                                code.toUpperCase(),
                                style: IqText.mono.copyWith(
                                  color: IqColors.fg2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          for (final left in [-10.0, size.width - 10])
            Positioned(
              left: left,
              top: 147,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: IqColors.bg,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _field(String label, String value) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: IqText.mono.copyWith(color: IqColors.fg3),
        ),
        const SizedBox(height: 3),
        Text(value, style: IqText.bodyStrong.copyWith(color: IqColors.fg)),
      ],
    );
  }
}
