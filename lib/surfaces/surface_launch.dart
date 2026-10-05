/// Holds the route a surface tap asked for until the app can show it: past
/// splash and entry, signed in. Then it is pushed over the tab the person
/// lands on, so Back returns there (designer answer 26).
class SurfaceLaunchQueue {
  SurfaceLaunchQueue({required this.readyRoots});

  /// Locations where a pending route may be pushed: the tab roots.
  final Set<String> readyRoots;

  String? _pending;

  String? get pending => _pending;

  /// Returns the route to push now, or null when it was queued.
  String? offer(
    String route, {
    required String location,
    required bool signedIn,
  }) {
    if (signedIn && readyRoots.contains(location)) {
      _pending = null;
      return route;
    }
    _pending = route;
    return null;
  }

  /// Called on every navigation; returns the queued route once it can go.
  String? onLocation(String location, {required bool signedIn}) {
    final route = _pending;
    if (route == null || !signedIn || !readyRoots.contains(location)) {
      return null;
    }
    _pending = null;
    return route;
  }
}
