import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'tablet_layout.dart';

/// The Material window size classes the tablet design follows (Mobile App ·
/// tablet, 21 Oct): under 600 the phone design, 600 to 839 the portrait
/// (medium) layout, 840 and up the landscape (expanded) layout.
enum WindowSize {
  compact,
  medium,
  expanded;

  bool get isTablet => this != compact;
}

/// Phone-first layout. A tablet window takes the tablet layouts; any other
/// wide window (Windows desktop) centres the content column at phone width.
abstract final class Layout {
  static const double frameWidth = 390;
  static const double contentMaxWidth = 430;
  static const double wideBreakpoint = 600;
  static const double mediumBreakpoint = 600;
  static const double expandedBreakpoint = 840;

  /// A phone on its side is 840 or more wide but under 480 tall: it keeps
  /// the phone design, as the Material height class reads it.
  static const double compactHeight = 480;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width > wideBreakpoint;

  static WindowSize sizeFor(Size window) {
    if (window.width < mediumBreakpoint || window.height < compactHeight) {
      return WindowSize.compact;
    }
    return window.width < expandedBreakpoint
        ? WindowSize.medium
        : WindowSize.expanded;
  }

  /// The class of the whole window, also inside a tablet page whose media
  /// query reads the page's own size.
  static WindowSize windowSize(BuildContext context) =>
      WindowScope.maybeOf(context) ?? sizeFor(MediaQuery.sizeOf(context));

  static bool isTablet(BuildContext context) => windowSize(context).isTablet;

  static bool isExpanded(BuildContext context) =>
      windowSize(context) == WindowSize.expanded;
}

/// Holds the window's size class for everything under it.
class WindowScope extends InheritedWidget {
  const WindowScope({super.key, required this.size, required super.child});

  final WindowSize size;

  static WindowSize? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WindowScope>()?.size;

  @override
  bool updateShouldNotify(WindowScope oldWidget) => size != oldWidget.size;
}

class CenteredContent extends StatelessWidget {
  const CenteredContent({
    super.key,
    required this.child,
    this.tablet = false,
    this.tabletWidth = tabletColumn,
  });

  final Widget child;

  /// The column's width on a tablet, wider for a page that splits in two.
  final double tabletWidth;

  /// The child draws its own tablet layout, so a tablet gives it the
  /// whole panel.
  final bool tablet;

  /// A phone page in the tablet panel reads as one calm column, 560 wide on
  /// white, as the tablet frames centre the app's own pages.
  static const double tabletColumn = 560;

  @override
  Widget build(BuildContext context) {
    if (tablet && Layout.isTablet(context)) return child;
    if (Layout.isTablet(context) &&
        (TabletLocation.maybeOf(context)?.onCard ?? false)) {
      return ColoredBox(
        color: IqColors.card,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: tabletWidth),
            child: child,
          ),
        ),
      );
    }
    if (!Layout.isWide(context)) return child;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Layout.contentMaxWidth),
        child: child,
      ),
    );
  }
}
