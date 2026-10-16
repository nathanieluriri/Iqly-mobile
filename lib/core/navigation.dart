import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// A page is open at most once (owner, 16 Oct). A link to a page already
/// open goes back to it, closing the pages above it as Back would, so two
/// pages that link to each other never pile up and a second tap on a link
/// does nothing. A link to a tab, or to a page inside a tab, switches tabs.
extension OpenPage on BuildContext {
  /// Opens [location] by the rule above. Completes with what the page pops
  /// when it was pushed, and at once when it was already open.
  Future<T?> open<T extends Object?>(String location, {Object? extra}) =>
      GoRouter.of(this).open<T>(location, extra: extra);

  /// Puts [location] in place of the top page, or closes back to it when it
  /// is already open lower down.
  void openInstead(String location, {Object? extra}) =>
      GoRouter.of(this).openInstead(location, extra: extra);
}

extension OpenPageOnRouter on GoRouter {
  Future<T?> open<T extends Object?>(String location, {Object? extra}) {
    if (_closeBackTo(location)) return Future.value();
    final found = configuration.findMatch(Uri.parse(location));
    if (!found.isError &&
        found.matches.last is ShellRouteMatch &&
        found.last.route.parentNavigatorKey == null) {
      go(location, extra: extra);
      return Future.value();
    }
    return push<T>(location, extra: extra);
  }

  void openInstead(String location, {Object? extra}) {
    if (!_closeBackTo(location)) replace(location, extra: extra);
  }

  /// Closes the pages above [location] when it is open; false when it is
  /// not.
  bool _closeBackTo(String location) {
    final stack = routerDelegate.currentConfiguration;
    final pages = openPages(stack);
    final target = Uri.parse(location);
    final at = pages.lastIndexWhere((p) => _same(p.location, target));
    if (at < 0) return false;
    if (at < pages.length - 1) restore(stack.remove(pages[at + 1].match));
    return true;
  }
}

typedef OpenPageEntry = ({Uri location, RouteMatchBase match});

/// The pages open on [stack], bottom to top: those the last `go` built,
/// the shell's as the tab shows them, then each push. Removing an entry's
/// match closes it and every page above it.
List<OpenPageEntry> openPages(RouteMatchList stack) {
  final pages = <OpenPageEntry>[];
  void visit(List<RouteMatchBase> matches) {
    for (final match in matches) {
      switch (match) {
        case ShellRouteMatch():
          visit(match.matches);
        case ImperativeRouteMatch():
          pages.add((location: match.matches.uri, match: match));
        case RouteMatch():
          final path = match.matchedLocation;
          pages.add((
            location: path == stack.uri.path ? stack.uri : Uri(path: path),
            match: match,
          ));
      }
    }
  }

  visit(stack.matches);
  return pages;
}

bool _same(Uri a, Uri b) =>
    a.path == b.path && mapEquals(a.queryParameters, b.queryParameters);
