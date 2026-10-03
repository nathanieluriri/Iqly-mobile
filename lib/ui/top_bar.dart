import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';

enum IqTopBarVariant { home, page, sheet }

/// Exp/TopBar. Home: greeting, display title and the bell with an unread
/// count. Page: round back, centred title, optional trailing action. Sheet:
/// grabber, title and a 44 pt close. Fills the width; the status bar and
/// safe area belong to the screen.
class IqTopBar extends StatelessWidget implements PreferredSizeWidget {
  const IqTopBar({
    super.key,
    this.variant = IqTopBarVariant.home,
    this.title = 'Discover',
    this.greeting = 'Good afternoon, Adaeze',
    this.count = '2',
    this.showCount = true,
    this.showTrailing = false,
    this.trailingIcon = IqIcons.filter,
    this.onBell,
    this.onBack,
    this.onTrailing,
    this.onClose,
  });

  final IqTopBarVariant variant;
  final String title;
  final String greeting;
  final String count;
  final bool showCount;
  final bool showTrailing;
  final IqIcons trailingIcon;
  final VoidCallback? onBell;
  final VoidCallback? onBack;
  final VoidCallback? onTrailing;
  final VoidCallback? onClose;

  @override
  Size get preferredSize => Size.fromHeight(switch (variant) {
    IqTopBarVariant.home => 96,
    IqTopBarVariant.page => 56,
    IqTopBarVariant.sheet => 76,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: preferredSize.height,
      width: double.infinity,
      child: ClipRect(
        child: switch (variant) {
          IqTopBarVariant.home => _home(),
          IqTopBarVariant.page => _page(),
          IqTopBarVariant.sheet => _sheet(),
        },
      ),
    );
  }

  Widget _home() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: IqSpace.s5,
        vertical: IqSpace.s2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  greeting,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: IqText.small.copyWith(color: IqColors.fg2),
                ),
              ),
              _RoundButton(
                onTap: onBell,
                semanticLabel: 'Notifications',
                fill: IqColors.card,
                stroke: IqColors.line,
                radius: 22,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    const IqIcon(IqIcons.bell, size: 24, color: IqColors.brand),
                    if (showCount)
                      Positioned(
                        left: 16,
                        top: -14,
                        child: _CountBadge(count: count),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: IqSpace.s0p5),
          Text(
            title,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: IqText.display.copyWith(color: IqColors.brand),
          ),
        ],
      ),
    );
  }

  Widget _page() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: IqSpace.s3),
      child: Row(
        children: [
          _RoundButton(
            onTap: onBack,
            semanticLabel: 'Back',
            fill: IqColors.card,
            stroke: IqColors.line,
            radius: 22,
            child: const IqIcon(IqIcons.back, size: 22, color: IqColors.brand),
          ),
          const SizedBox(width: IqSpace.s2),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: IqText.cardTitle.copyWith(color: IqColors.brand),
            ),
          ),
          const SizedBox(width: IqSpace.s2),
          if (showTrailing)
            _RoundButton(
              onTap: onTrailing,
              radius: 22,
              child: IqIcon(trailingIcon, size: 22, color: IqColors.brand),
            )
          else
            const SizedBox.square(dimension: 44),
        ],
      ),
    );
  }

  Widget _sheet() {
    return Stack(
      children: [
        Positioned(
          top: 6,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: IqColors.line2,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            IqSpace.s5,
            IqSpace.s2 + 14,
            IqSpace.s5,
            IqSpace.s2,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: IqText.title.copyWith(color: IqColors.brand),
                ),
              ),
              _RoundButton(
                onTap: onClose,
                semanticLabel: 'Close',
                fill: IqColors.panel,
                radius: 20,
                child: const IqIcon(
                  IqIcons.close,
                  size: 20,
                  color: IqColors.brand,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.child,
    required this.radius,
    this.onTap,
    this.semanticLabel,
    this.fill,
    this.stroke,
  });

  final Widget child;
  final double radius;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final Color? fill;
  final Color? stroke;

  @override
  Widget build(BuildContext context) {
    return IqPressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      builder: (context, pressed) => Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(radius),
          border: stroke == null ? null : Border.all(color: stroke!),
        ),
        child: child,
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final String count;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: IqColors.brand,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: IqColors.bg, width: 2),
      ),
      child: Text(
        count,
        maxLines: 1,
        softWrap: false,
        style: IqText.label.copyWith(color: IqColors.primaryFg),
      ),
    );
  }
}
