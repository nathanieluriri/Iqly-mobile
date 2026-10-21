import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'gift_button.dart';
import 'icon.dart';
import 'pressable.dart';

/// Exp/Web/AppBar (local, sync to DS; 1721:13959) as the tablet top bar:
/// the round search field, then the gift, the bell with the unread count
/// and the account chip, every target 44 or more. The key hint stays off
/// on tablets (spec, Shell): search opens with the keyboard instead.
class IqWebAppBar extends StatelessWidget {
  const IqWebAppBar({
    super.key,
    required this.name,
    required this.avatar,
    this.unread = '',
    this.showUnread = false,
    this.showGift = true,
    this.giftTwinkle = false,
    this.placeholder = 'Search briefs, polls and activations',
    this.onSearch,
    this.onGift,
    this.onNotifications,
    this.onAccount,
  });

  final String name;

  /// The person's avatar, drawn 36 across.
  final Widget avatar;
  final String unread;
  final bool showUnread;
  final bool showGift;
  final bool giftTwinkle;
  final String placeholder;
  final VoidCallback? onSearch;
  final VoidCallback? onGift;
  final VoidCallback? onNotifications;
  final VoidCallback? onAccount;

  static const double height = 64;
  static const double searchMaxWidth = 440;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: searchMaxWidth),
                child: _Search(placeholder: placeholder, onTap: onSearch),
              ),
            ),
          ),
          const SizedBox(width: IqSpace.s3),
          if (showGift) ...[
            IqGiftButton(twinkle: giftTwinkle, onTap: onGift),
            const SizedBox(width: IqSpace.s2),
          ],
          _Bell(unread: unread, showUnread: showUnread, onTap: onNotifications),
          const SizedBox(width: IqSpace.s2),
          _Account(name: name, avatar: avatar, onTap: onAccount),
        ],
      ),
    );
  }
}

class _Search extends StatelessWidget {
  const _Search({required this.placeholder, this.onTap});

  final String placeholder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IqPressable(
      onTap: onTap,
      tactile: false,
      semanticLabel: placeholder,
      builder: (context, pressed) => Container(
        height: 44,
        padding: const EdgeInsets.only(left: IqSpace.s4, right: IqSpace.s2),
        decoration: BoxDecoration(
          color: pressed ? IqColors.panel : IqColors.card,
          borderRadius: BorderRadius.circular(IqRadius.full),
          border: Border.all(color: IqColors.line),
        ),
        child: Row(
          children: [
            const IqIcon(IqIcons.search, size: 16, color: IqColors.fg3),
            const SizedBox(width: IqSpace.s2),
            Expanded(
              child: Text(
                placeholder,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: IqWebText.bodySmall.copyWith(color: IqColors.fg3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bell extends StatelessWidget {
  const _Bell({required this.unread, required this.showUnread, this.onTap});

  final String unread;
  final bool showUnread;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IqPressable(
      onTap: onTap,
      semanticLabel: showUnread
          ? 'Notifications, $unread unread'
          : 'Notifications',
      builder: (context, pressed) => SizedBox.square(
        dimension: 44,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: pressed ? IqColors.panel : IqColors.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: IqColors.line),
                ),
              ),
            ),
            const Center(
              child: IqIcon(IqIcons.bell, size: 22, color: IqColors.brand),
            ),
            if (showUnread)
              Positioned(
                left: 27,
                top: -2,
                child: Container(
                  height: 18,
                  constraints: const BoxConstraints(minWidth: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: IqColors.brand,
                    borderRadius: BorderRadius.circular(IqRadius.full),
                    border: Border.all(
                      color: IqColors.card,
                      width: 2,
                      strokeAlign: BorderSide.strokeAlignOutside,
                    ),
                  ),
                  child: Text(
                    unread,
                    style: IqWebText.labelBadge.copyWith(
                      color: IqColors.primaryFg,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Account extends StatelessWidget {
  const _Account({required this.name, required this.avatar, this.onTap});

  final String name;
  final Widget avatar;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IqPressable(
      onTap: onTap,
      semanticLabel: 'Account, $name',
      builder: (context, pressed) => Container(
        height: 46,
        padding: const EdgeInsets.fromLTRB(
          IqSpace.s1,
          IqSpace.s1,
          IqSpace.s3,
          IqSpace.s1,
        ),
        decoration: BoxDecoration(
          color: pressed ? IqColors.panel : IqColors.card,
          borderRadius: BorderRadius.circular(IqRadius.full),
          border: Border.all(color: IqColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: Container(
                width: 36,
                height: 36,
                color: IqColors.tint,
                child: avatar,
              ),
            ),
            const SizedBox(width: IqSpace.s2),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: IqWebText.bodySmallStrong.copyWith(color: IqColors.fg),
              ),
            ),
            const SizedBox(width: IqSpace.s2),
            const IqIcon(IqIcons.down, size: 16, color: IqColors.fg2),
          ],
        ),
      ),
    );
  }
}
