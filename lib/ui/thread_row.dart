import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';

enum IqThreadRowWith { iqly, business }

enum IqThreadRowState { unread, read, resolved }

/// Exp/ThreadRow: one conversation in the support inbox. Who it is with
/// ([avatar], 40) and when it last moved; what it is about; the last
/// message ("You: " for your own). Unread lights the time in brand and
/// counts the replies; Resolved quiets the row to fg3, halves the avatar
/// and ends it with the Resolved pill.
class IqThreadRow extends StatelessWidget {
  const IqThreadRow({
    super.key,
    this.withWhom = IqThreadRowWith.iqly,
    this.state = IqThreadRowState.read,
    required this.avatar,
    this.name = 'iQLY support',
    this.time = '9:13 am',
    this.about = 'Withdrawal to Access Bank',
    this.preview = 'The reference on the receipt is the one Access Bank needs.',
    this.count = 0,
    this.showDivider = true,
    this.onTap,
  });

  final IqThreadRowWith withWhom;
  final IqThreadRowState state;
  final Widget avatar;
  final String name;
  final String time;
  final String about;
  final String preview;

  /// Replies not yet read, on an unread row; none hides the badge.
  final int count;
  final bool showDivider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final unread = state == IqThreadRowState.unread;
    final resolved = state == IqThreadRowState.resolved;
    final row = Container(
      color: IqColors.card,
      padding: const EdgeInsets.all(IqSpace.s3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Opacity(
            opacity: resolved ? 0.5 : 1,
            child: SizedBox.square(dimension: 40, child: avatar),
          ),
          const SizedBox(width: IqSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: IqText.bodyStrong.copyWith(
                          color: resolved ? IqColors.fg3 : IqColors.fg,
                        ),
                      ),
                    ),
                    const SizedBox(width: IqSpace.s2),
                    Text(
                      time,
                      style: unread
                          ? IqText.smallStrong.copyWith(color: IqColors.brand)
                          : IqText.small.copyWith(color: IqColors.fg3),
                    ),
                  ],
                ),
                const SizedBox(height: IqSpace.s0p5),
                Text(
                  about,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: IqText.small.copyWith(
                    color: resolved ? IqColors.fg3 : IqColors.fg2,
                  ),
                ),
                const SizedBox(height: IqSpace.s0p5),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: IqText.small.copyWith(color: IqColors.fg3),
                      ),
                    ),
                    if (unread && count > 0) ...[
                      const SizedBox(width: IqSpace.s2),
                      Container(
                        constraints: const BoxConstraints(minWidth: 20),
                        padding: const EdgeInsets.symmetric(
                          horizontal: IqSpace.s1p5,
                          vertical: IqSpace.s0p5,
                        ),
                        decoration: BoxDecoration(
                          color: IqColors.brand,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$count',
                          textAlign: TextAlign.center,
                          style: IqText.label.copyWith(
                            color: IqColors.primaryFg,
                          ),
                        ),
                      ),
                    ],
                    if (resolved) ...[
                      const SizedBox(width: IqSpace.s2),
                      Container(
                        padding: const EdgeInsets.fromLTRB(
                          IqSpace.s2p5,
                          5,
                          IqSpace.s3,
                          5,
                        ),
                        decoration: BoxDecoration(
                          color: IqColors.okSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const IqIcon(
                              IqIcons.check,
                              size: 14,
                              color: IqColors.ok,
                            ),
                            const SizedBox(width: IqSpace.s1p5),
                            Text(
                              'Resolved',
                              style: IqText.smallStrong.copyWith(
                                color: IqColors.ok,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
    final body = Stack(
      children: [
        row,
        if (showDivider)
          const Positioned(
            left: 64,
            right: 0,
            bottom: 0,
            child: SizedBox(height: 1, child: ColoredBox(color: IqColors.line)),
          ),
      ],
    );
    final tap = onTap;
    if (tap == null) return body;
    return IqPressable(
      semanticLabel: '$name, $about',
      onTap: tap,
      builder: (context, pressed) => PressDim(pressed: pressed, child: body),
    );
  }
}
