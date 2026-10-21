import 'package:flutter/material.dart';

import '../../core/responsive.dart';
import '../../theme/theme.dart';
import '../../ui/biz_crumb.dart';

class TabletCrumb {
  const TabletCrumb(this.label, [this.onTap]);

  final String label;
  final VoidCallback? onTap;
}

/// A page on the tablet panel, as the tablet frames lay it out: 32 in from
/// the panel in portrait, 40 (32 on top) in landscape, the trail of
/// crumbs, then the Mob/Display title in brand with its subtitle and the
/// page's actions on the right, then [children] 24 apart. [bottomBar]
/// stays pinned under the scroll (Exp/Tablet/ActionBar).
class TabletPage extends StatelessWidget {
  const TabletPage({
    super.key,
    this.title,
    this.subtitle,
    this.crumbs = const [],
    this.crumbTrail,
    this.actions = const [],
    this.children = const [],
    this.bottomBar,
    this.controller,
    this.gap = IqSpace.s6,
    this.maxWidth,
  });

  final String? title;
  final String? subtitle;
  final List<TabletCrumb> crumbs;

  /// Shown on the crumbs' row, at its right end ("Saved just now").
  final Widget? crumbTrail;
  final List<Widget> actions;
  final List<Widget> children;
  final Widget? bottomBar;
  final ScrollController? controller;
  final double gap;

  /// Centres the content at this width, for the calm one-column pages.
  final double? maxWidth;

  static EdgeInsets padding(BuildContext context) => Layout.isExpanded(context)
      ? const EdgeInsets.fromLTRB(
          IqSpace.s10,
          IqSpace.s8,
          IqSpace.s10,
          IqSpace.s10,
        )
      : const EdgeInsets.all(IqSpace.s8);

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    final subtitle = this.subtitle;
    final head = <Widget>[
      if (crumbs.isNotEmpty)
        Row(
          children: [
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: IqSpace.s1,
                children: [
                  for (final (i, c) in crumbs.indexed)
                    IqBizCrumb(
                      label: c.label,
                      state: i == crumbs.length - 1
                          ? IqBizCrumbState.current
                          : IqBizCrumbState.link,
                      onTap: c.onTap,
                    ),
                ],
              ),
            ),
            ?crumbTrail,
          ],
        ),
      if (title != null)
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: IqText.display.copyWith(color: IqColors.brand),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: IqSpace.s1),
                    Text(
                      subtitle,
                      style: IqWebText.bodySmall.copyWith(color: IqColors.fg2),
                    ),
                  ],
                ],
              ),
            ),
            for (final (i, a) in actions.indexed) ...[
              SizedBox(width: i == 0 ? IqSpace.s4 : IqSpace.s3),
              a,
            ],
          ],
        ),
    ];
    final all = [...head, ...children];
    final pad = padding(context);
    Widget body = ListView.separated(
      controller: controller,
      padding: pad,
      itemCount: all.length,
      separatorBuilder: (context, i) => SizedBox(
        height: i < head.length - 1 && crumbs.isNotEmpty && i == 0
            ? IqSpace.s2
            : gap,
      ),
      itemBuilder: (context, i) => all[i],
    );
    final maxWidth = this.maxWidth;
    if (maxWidth != null) {
      body = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth + pad.horizontal),
          child: body,
        ),
      );
    }
    return Material(
      color: IqColors.card,
      child: Column(
        children: [
          Expanded(child: body),
          ?bottomBar,
        ],
      ),
    );
  }
}
