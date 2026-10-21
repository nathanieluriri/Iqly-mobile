import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import '../../ui/pressable.dart';

/// A popover dropped from [anchor] (filters, sort): it opens under the
/// anchor's bottom edge, lined up with its [alignRight] or left edge, over
/// a clear barrier that closes it. Rotation keeps it open, as its state
/// lives in the page.
class TabletPopover extends StatefulWidget {
  const TabletPopover({
    super.key,
    required this.open,
    required this.onClose,
    required this.anchor,
    required this.popover,
    this.alignRight = true,
    this.gap = IqSpace.s2,
  });

  final bool open;
  final VoidCallback onClose;
  final Widget anchor;
  final Widget popover;
  final bool alignRight;
  final double gap;

  @override
  State<TabletPopover> createState() => _TabletPopoverState();
}

class _TabletPopoverState extends State<TabletPopover> {
  final _link = LayerLink();
  final _portal = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    // The portal stays shown and draws nothing while closed, as it cannot
    // be shown or hidden during a build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _portal.show();
    });
  }

  @override
  Widget build(BuildContext context) {
    final right = widget.alignRight;
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (context) => !widget.open
            ? const SizedBox.shrink()
            : Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onClose,
                    ),
                  ),
                  CompositedTransformFollower(
                    link: _link,
                    targetAnchor: right
                        ? Alignment.bottomRight
                        : Alignment.bottomLeft,
                    followerAnchor: right
                        ? Alignment.topRight
                        : Alignment.topLeft,
                    offset: Offset(0, widget.gap),
                    child: Align(
                      alignment: right ? Alignment.topRight : Alignment.topLeft,
                      child: Material(
                        type: MaterialType.transparency,
                        child: widget.popover,
                      ),
                    ),
                  ),
                ],
              ),
        child: widget.anchor,
      ),
    );
  }
}

/// A short list of choices in a white card, radius 14: the picked one in
/// fg Medium on grey, each row 44 tall (sort, status, date range).
class TabletMenu<T> extends StatelessWidget {
  const TabletMenu({
    super.key,
    required this.options,
    required this.label,
    required this.selected,
    required this.onPick,
    this.width = 240,
  });

  final List<T> options;
  final String Function(T) label;
  final T selected;
  final ValueChanged<T> onPick;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(IqSpace.s2),
      decoration: BoxDecoration(
        color: IqColors.card,
        borderRadius: BorderRadius.circular(IqRadius.xl),
        border: Border.all(color: IqColors.line),
        boxShadow: IqShadows.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final option in options)
            IqPressable(
              onTap: () => onPick(option),
              tactile: false,
              semanticLabel: label(option),
              builder: (context, pressed) {
                final on = option == selected;
                return Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: IqSpace.s3),
                  decoration: BoxDecoration(
                    color: on || pressed ? IqColors.secondary : null,
                    borderRadius: BorderRadius.circular(IqRadius.md),
                  ),
                  child: Text(
                    label(option),
                    style:
                        (on ? IqWebText.bodySmallStrong : IqWebText.bodySmall)
                            .copyWith(color: on ? IqColors.fg : IqColors.fg2),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
