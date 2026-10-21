import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'brand_logo.dart';
import 'icon.dart';
import 'tablet_icon.dart';
import 'tablet_nav_item.dart';

enum IqTabletNavLayout { rail, sidebar }

/// One place the nav opens. The rail shows [label]; the sidebar shows
/// [sidebarLabel] when it differs (Submissions, My submissions).
class IqTabletNavDestination {
  const IqTabletNavDestination({
    required this.label,
    required this.icon,
    String? sidebarLabel,
  }) : sidebarLabel = sidebarLabel ?? label;

  final String label;
  final String sidebarLabel;
  final IqIcons icon;
}

/// Exp/Tablet/Nav (local, sync to DS; 1807:34532). Rail: 88 wide, the
/// logomark over the labelled items, Support and the toggle at the foot.
/// Sidebar: 232 wide, the logo over the items. Portrait has no toggle
/// ([showToggle] off); landscape collapses the sidebar to the rail with
/// Collapse sidebar and opens it again from the rail toggle.
class IqTabletNav extends StatelessWidget {
  const IqTabletNav({
    super.key,
    required this.destinations,
    this.layout = IqTabletNavLayout.rail,
    this.selected,
    this.support,
    this.supportSelected = false,
    this.showToggle = false,
    this.onSelect,
    this.onSupport,
    this.onToggle,
  });

  final List<IqTabletNavDestination> destinations;
  final IqTabletNavLayout layout;

  /// The open destination, or none (Settings, Notifications).
  final int? selected;

  /// Support at the foot; null hides it.
  final IqTabletNavDestination? support;
  final bool supportSelected;
  final bool showToggle;
  final ValueChanged<int>? onSelect;
  final VoidCallback? onSupport;
  final VoidCallback? onToggle;

  static const double railWidth = 88;
  static const double sidebarWidth = 232;

  bool get _rail => layout == IqTabletNavLayout.rail;

  IqTabletNavItemLayout get _itemLayout =>
      _rail ? IqTabletNavItemLayout.rail : IqTabletNavItemLayout.sidebar;

  static IqTabletNavItemState _state(bool on) =>
      on ? IqTabletNavItemState.selected : IqTabletNavItemState.standard;

  @override
  Widget build(BuildContext context) {
    final support = this.support;
    return SizedBox(
      width: _rail ? railWidth : sidebarWidth,
      child: Padding(
        padding: _rail
            ? const EdgeInsets.symmetric(
                horizontal: IqSpace.s1,
                vertical: IqSpace.s4,
              )
            : const EdgeInsets.fromLTRB(
                IqSpace.s2,
                IqSpace.s5,
                IqSpace.s2,
                IqSpace.s4,
              ),
        child: Column(
          crossAxisAlignment: _rail
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            if (_rail)
              const IqBrandLogo(mark: IqBrandMark.logomark, width: 32)
            else
              const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: IqSpace.s3,
                  vertical: IqSpace.s1,
                ),
                child: IqBrandLogo(height: 28),
              ),
            const SizedBox(height: IqSpace.s6),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: box.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: _rail
                            ? CrossAxisAlignment.center
                            : CrossAxisAlignment.start,
                        children: [
                          for (final (i, d) in destinations.indexed) ...[
                            if (i > 0) const SizedBox(height: IqSpace.s1),
                            IqTabletNavItem(
                              label: _rail ? d.label : d.sidebarLabel,
                              icon: d.icon,
                              layout: _itemLayout,
                              state: _state(i == selected),
                              onTap: onSelect == null
                                  ? null
                                  : () => onSelect!(i),
                            ),
                          ],
                          const Spacer(),
                          if (support != null)
                            IqTabletNavItem(
                              label: _rail
                                  ? support.label
                                  : support.sidebarLabel,
                              icon: support.icon,
                              layout: _itemLayout,
                              state: _state(supportSelected),
                              onTap: onSupport,
                            ),
                          if (showToggle) ...[
                            const SizedBox(height: IqSpace.s1),
                            IqTabletNavItem(
                              label: _rail
                                  ? 'Expand sidebar'
                                  : 'Collapse sidebar',
                              tabletIcon: _rail
                                  ? IqTabletIcons.sidebarExpand
                                  : IqTabletIcons.sidebarCollapse,
                              layout: _itemLayout,
                              showLabel: !_rail,
                              onTap: onToggle,
                            ),
                          ],
                        ],
                      ),
                    ),
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
