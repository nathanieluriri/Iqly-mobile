import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import '../core/motion.dart';
import 'icon.dart';
import 'pressable.dart';

enum IqChatHeaderWith { iqly, business }

/// A 44 round white button with a line, as the Page top bar's back.
class IqChatRoundButton extends StatelessWidget {
  const IqChatRoundButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    this.onTap,
  });

  final IqIcons icon;
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IqPressable(
      semanticLabel: semanticLabel,
      onTap: onTap,
      builder: (context, pressed) => AnimatedContainer(
        duration: pressMotion(context, pressed),
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: pressed ? IqColors.panel : IqColors.card,
          shape: BoxShape.circle,
          border: Border.all(color: IqColors.line),
        ),
        child: IqIcon(icon, size: 22, color: IqColors.brand),
      ),
    );
  }
}

/// Exp/ChatHeader: a thread's bar. Back, who it is with ([avatar], 40) and
/// their name; on iQLY the reply promise under it, never on a business
/// (owner decision). Mark as resolved is the round check, gone once
/// resolved. Under it the [about] chip names what the thread is about and
/// opens it when it can ([onAbout]).
class IqChatHeader extends StatelessWidget {
  const IqChatHeader({
    super.key,
    this.withWhom = IqChatHeaderWith.iqly,
    required this.avatar,
    this.title = 'iQLY support',
    this.subtitle,
    this.about = 'About: Withdrawal to Access Bank',
    this.aboutIcon = IqIcons.wallet,
    this.onBack,
    this.onResolve,
    this.onAbout,
    this.resolving = false,
  });

  final IqChatHeaderWith withWhom;
  final Widget avatar;
  final String title;
  final String? subtitle;
  final String about;
  final IqIcons aboutIcon;
  final VoidCallback? onBack;

  /// Null hides Mark as resolved.
  final VoidCallback? onResolve;
  final VoidCallback? onAbout;
  final bool resolving;

  @override
  Widget build(BuildContext context) {
    final subtitle = withWhom == IqChatHeaderWith.iqly ? this.subtitle : null;
    final resolve = onResolve;
    final chip = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: IqSpace.s2p5,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: IqColors.secondary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          IqIcon(aboutIcon, size: 16, color: IqColors.brand),
          const SizedBox(width: IqSpace.s1p5),
          Expanded(
            child: Text(
              about,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: IqText.smallStrong.copyWith(color: IqColors.fg),
            ),
          ),
          if (onAbout != null) ...[
            const SizedBox(width: IqSpace.s1p5),
            const IqIcon(IqIcons.forward, size: 16, color: IqColors.fg3),
          ],
        ],
      ),
    );
    return Container(
      decoration: const BoxDecoration(
        color: IqColors.bg,
        border: Border(bottom: BorderSide(color: IqColors.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: IqSpace.s3,
              vertical: IqSpace.s2,
            ),
            child: Row(
              children: [
                IqChatRoundButton(
                  icon: IqIcons.back,
                  semanticLabel: 'Back',
                  onTap: onBack,
                ),
                const SizedBox(width: IqSpace.s2p5),
                SizedBox.square(dimension: 40, child: avatar),
                const SizedBox(width: IqSpace.s2p5),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: IqText.cardTitle.copyWith(color: IqColors.brand),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: IqText.small.copyWith(color: IqColors.fg3),
                        ),
                    ],
                  ),
                ),
                if (resolve != null) ...[
                  const SizedBox(width: IqSpace.s2p5),
                  IqChatRoundButton(
                    icon: IqIcons.check,
                    semanticLabel: 'Mark as resolved',
                    onTap: resolving ? null : resolve,
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              IqSpace.s3,
              0,
              IqSpace.s3,
              IqSpace.s2p5,
            ),
            child: onAbout == null
                ? chip
                : IqPressable(
                    semanticLabel: about,
                    onTap: onAbout,
                    builder: (context, pressed) =>
                        PressDim(pressed: pressed, child: chip),
                  ),
          ),
        ],
      ),
    );
  }
}
