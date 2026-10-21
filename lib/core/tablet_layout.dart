import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'responsive.dart';

/// What the tablet frame tells the pages under it: the window class and,
/// while the chrome shows, where the page panel sits.
class TabletChrome extends InheritedWidget {
  const TabletChrome({
    super.key,
    required this.size,
    required this.panel,
    this.decorate,
    required super.child,
  });

  final WindowSize size;

  /// Lays a group's frame around its pages inside the panel (the settings
  /// sub-navigation); the location's page otherwise fills the panel.
  final Widget Function(String location, Widget page)? decorate;

  /// The panel's distance from each window edge.
  final EdgeInsets panel;

  static const double radius = 18;

  static TabletChrome? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TabletChrome>();

  @override
  bool updateShouldNotify(TabletChrome oldWidget) =>
      size != oldWidget.size || panel != oldWidget.panel;
}

/// The pages that run before the shell, or take over the whole app: on a
/// tablet they draw their own full-screen layout, with no nav or top bar.
bool chromelessLocation(String location) {
  if (location.isEmpty) return false;
  const roots = [
    '/splash',
    '/update',
    '/landing',
    '/invite',
    '/sign-up',
    '/sign-in',
    '/verify-email',
    '/forgot-password',
    '/turn-on-notifications',
    '/onboarding',
    '/account-closing',
    '/restore-account',
    '/terms',
    '/privacy',
  ];
  return roots.any((r) => location == r || location.startsWith('$r/'));
}

/// One route's page on a tablet. With chrome, the page draws inside the
/// frame's white panel: clipped to it, with the panel as its media size
/// and no safe areas of its own (the frame keeps them), and the keyboard
/// counted from the panel's foot. Without chrome it takes the window.
/// Pages nested in a page that already sits in the panel pass through.
class TabletPane extends StatelessWidget {
  const TabletPane({super.key, required this.location, required this.child});

  /// Where the route sits, as go_router matched it.
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final chrome = TabletChrome.maybeOf(context);
    if (context.getInheritedWidgetOfExactType<_Placed>() != null) {
      if (chrome == null || !chrome.size.isTablet) return child;
      return chrome.decorate?.call(location, child) ?? child;
    }
    if (chrome == null || !chrome.size.isTablet) return child;
    if (chromelessLocation(location)) {
      return _Placed(child: chrome.decorate?.call(location, child) ?? child);
    }
    final media = MediaQuery.of(context);
    final panel = chrome.panel;
    final size = Size(
      (media.size.width - panel.horizontal).clamp(0, double.infinity),
      (media.size.height - panel.vertical).clamp(0, double.infinity),
    );
    final keyboard = (media.viewInsets.bottom - panel.bottom).clamp(
      0.0,
      double.infinity,
    );
    return _Placed(
      child: Padding(
        padding: panel,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(TabletChrome.radius),
          child: MediaQuery(
            data: media.copyWith(
              size: size,
              padding: EdgeInsets.zero,
              viewPadding: EdgeInsets.zero,
              viewInsets: EdgeInsets.only(bottom: keyboard),
            ),
            child: chrome.decorate?.call(location, child) ?? child,
          ),
        ),
      ),
    );
  }
}

class _Placed extends InheritedWidget {
  const _Placed({required super.child});

  @override
  bool updateShouldNotify(_Placed oldWidget) => false;
}

/// Follows the root navigator for the frame: whether a dialog or a sheet
/// is on top, when the chrome must not take taps. One per router.
class TabletRouteWatch extends NavigatorObserver with ChangeNotifier {
  final _routes = <Route<dynamic>>[];

  static final _byRouter = Expando<TabletRouteWatch>();

  static TabletRouteWatch of(GoRouter router) =>
      _byRouter[router] ??= TabletRouteWatch();

  /// Registers [watch] as [router]'s, before the router builds.
  static void attach(GoRouter router, TabletRouteWatch watch) =>
      _byRouter[router] = watch;

  bool get popupOnTop =>
      _routes.any((r) => r.isCurrent && r is TransitionRoute && !r.opaque);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    notifyListeners();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    notifyListeners();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    notifyListeners();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final at = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (newRoute != null) {
      at < 0 ? _routes.add(newRoute) : _routes[at] = newRoute;
    } else if (at >= 0) {
      _routes.removeAt(at);
    }
    notifyListeners();
  }
}
