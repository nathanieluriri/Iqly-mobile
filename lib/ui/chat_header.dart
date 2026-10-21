import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import '../core/motion.dart';
import 'icon.dart';
import 'pressable.dart';
import 'skeleton.dart';
import 'spinner.dart';

enum IqChatHeaderWith { iqly, business }

/// A shown thread or inbox reading again: [updating] while it does,
/// [failed] when it could not, [none] once it has.
enum IqChatSync { none, updating, failed }

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

/// Under a thread's name, or beside the inbox's title, while what shows is
/// read again: the spinner and Updating, or Couldn't update and Try again
/// ([onRetry]). Nothing once it is up to date. [compact] fits beside a
/// title: Couldn't update with the refresh mark, the whole line Try again.
/// No frame draws it: the app's own, in Mob/Small.
class IqChatSyncLine extends StatelessWidget {
  const IqChatSyncLine({
    super.key,
    required this.sync,
    this.onRetry,
    this.compact = false,
  });

  final IqChatSync sync;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (sync == IqChatSync.updating) {
      return Semantics(
        liveRegion: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const IqSpinner(color: IqColors.fg3, size: 13),
            const SizedBox(width: IqSpace.s1p5),
            Text('Updating', style: IqText.small.copyWith(color: IqColors.fg3)),
          ],
        ),
      );
    }
    if (sync == IqChatSync.none) return const SizedBox.shrink();
    if (compact) {
      return IqPressable(
        semanticLabel: 'Couldn’t update. Try again',
        onTap: onRetry,
        builder: (context, pressed) => PressDim(
          pressed: pressed,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Couldn’t update',
                style: IqText.small.copyWith(color: IqColors.err),
              ),
              const SizedBox(width: IqSpace.s1),
              const IqIcon(IqIcons.refresh, size: 14, color: IqColors.brand),
            ],
          ),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            'Couldn’t update',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: IqText.small.copyWith(color: IqColors.err),
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(width: IqSpace.s2),
          IqPressable(
            semanticLabel: 'Try again',
            onTap: onRetry,
            builder: (context, pressed) => PressDim(
              pressed: pressed,
              child: Text(
                'Try again',
                style: IqText.smallStrong.copyWith(color: IqColors.brand),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Exp/ChatHeader: a thread's bar. Back, who it is with ([avatar], 40) and
/// their name; on iQLY the reply promise under it, never on a business
/// (owner decision). Mark as resolved is the round check, gone once
/// resolved. Under it the [about] chip names what the thread is about and
/// opens it when it can ([onAbout]).
///
/// Not in Figma, the app's own: while the thread reads again ([sync]) the
/// line under the name says so ([IqChatSyncLine]) in place of the reply
/// promise, the bar keeping its height; and until the topic is known
/// ([about] null) the chip holds a skeleton line, never a bare "About:".
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
    this.sync = IqChatSync.none,
    this.onRetry,
  });

  final IqChatHeaderWith withWhom;
  final Widget avatar;
  final String title;
  final String? subtitle;

  /// Null while the thread's topic is not known yet.
  final String? about;
  final IqIcons aboutIcon;
  final VoidCallback? onBack;

  /// Null hides Mark as resolved.
  final VoidCallback? onResolve;
  final VoidCallback? onAbout;
  final bool resolving;
  final IqChatSync sync;

  /// Reads the thread again after [IqChatSync.failed].
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final subtitle = withWhom == IqChatHeaderWith.iqly ? this.subtitle : null;
    final about = this.about;
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
            child: about == null
                ? Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Opacity(
                        opacity: 0,
                        child: Text('About', style: IqText.smallStrong),
                      ),
                      const IqSkeleton(kind: IqSkeletonKind.line, width: 160),
                    ],
                  )
                : Text(
                    about,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: IqText.smallStrong.copyWith(color: IqColors.fg),
                  ),
          ),
          if (onAbout != null && about != null) ...[
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
                      if (sync != IqChatSync.none)
                        IqChatSyncLine(sync: sync, onRetry: onRetry)
                      else if (subtitle != null)
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
            child: onAbout == null || about == null
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
