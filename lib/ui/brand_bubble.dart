import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';
import 'vector.dart';

enum IqBrandBubbleState { newPolls, done }

/// Exp/BrandBubble: one bubble per business with open polls, in story
/// grammar. The orange brush ring and [count] mean unanswered polls; the
/// grey ring and check mean all answered. [onTap] opens that business's
/// poll sheet. Figma State=New is [IqBrandBubbleState.newPolls].
class IqBrandBubble extends StatelessWidget {
  const IqBrandBubble({
    super.key,
    this.initial = 'O',
    this.name = 'Orchid Foods',
    this.count = '2',
    this.state = IqBrandBubbleState.newPolls,
    this.onTap,
  });

  final String initial;
  final String name;
  final String count;
  final IqBrandBubbleState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fresh = state == IqBrandBubbleState.newPolls;
    return IqPressable(
      onTap: onTap,
      builder: (context, _) => SizedBox(
        width: 88,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 70,
              height: 70,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 2.3,
                    top: 1.5,
                    width: 65.88,
                    height: 66.36,
                    child: IqVector(
                      'assets/vectors/brand-bubble-loop.svg',
                      color: fresh ? IqColors.accent : IqColors.line2,
                    ),
                  ),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      width: 54,
                      height: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: fresh ? IqColors.accentSoft : IqColors.panel,
                        shape: BoxShape.circle,
                      ),
                      child: ExcludeSemantics(
                        child: Text(
                          initial,
                          style: IqText.title.copyWith(
                            color: fresh ? IqColors.accentStrong : IqColors.fg3,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 50,
                    top: -2,
                    child: fresh
                        ? Container(
                            constraints: const BoxConstraints(
                              minWidth: 22,
                              minHeight: 22,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: IqSpace.s1p5,
                            ),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: IqColors.brand,
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(color: IqColors.bg, width: 2),
                            ),
                            child: Text(
                              count,
                              style: IqText.label.copyWith(
                                color: IqColors.primaryFg,
                              ),
                            ),
                          )
                        : Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: IqColors.okSoft,
                              shape: BoxShape.circle,
                            ),
                            child: const IqIcon(
                              IqIcons.check,
                              size: 14,
                              color: IqColors.ok,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: IqSpace.s1p5),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: IqText.small.copyWith(color: IqColors.fg2),
            ),
          ],
        ),
      ),
    );
  }
}
