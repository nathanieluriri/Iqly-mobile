/// Every route an OS surface opens (notifications, widgets, shortcuts, the
/// Live Activity), and the `iqly://app/<route>` form the native side carries.
/// The paths mirror `Routes` so lib/core stays free of the router; a test
/// keeps the two in step. [notificationPattern] is the one route this file
/// adds: the Notification sub page (payout 498:24308, result 498:24590,
/// deadline 498:24830), built by the Notifications lane.
abstract final class DeepLinks {
  static const scheme = 'iqly';
  static const host = 'app';

  static const home = '/home';
  static const polls = '/polls';
  static const pollPattern = '/polls/:id';
  static const submissions = '/submissions';
  static const briefPattern = '/briefs/:id';
  static const submitPattern = '/briefs/:id/submit';
  static const withdrawalPattern = '/wallet/withdrawals/:id';
  static const notificationPattern = '/notifications/:id';

  static String poll(String businessId) => '/polls/$businessId';
  static String brief(String briefId) => '/briefs/$briefId';
  static String submit(String briefId) => '/briefs/$briefId/submit';
  static String withdrawal(String id) => '/wallet/withdrawals/$id';
  static String notification(String id) => '/notifications/$id';

  static const patterns = [
    home,
    polls,
    pollPattern,
    submissions,
    briefPattern,
    submitPattern,
    withdrawalPattern,
    notificationPattern,
  ];

  static Uri uri(String route) => Uri(scheme: scheme, host: host, path: route);

  /// The route a surface link opens, or null when it is not one of ours.
  /// Takes the `iqly://app/...` form or a bare route.
  static String? route(String link) {
    final parsed = Uri.tryParse(link);
    if (parsed == null) return null;
    if (parsed.hasScheme && (parsed.scheme != scheme || parsed.host != host)) {
      return null;
    }
    final segments = parsed.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return null;
    final route = '/${segments.join('/')}';
    return patterns.any((p) => _matches(p, segments)) ? route : null;
  }

  static bool _matches(String pattern, List<String> segments) {
    final parts = pattern.substring(1).split('/');
    if (parts.length != segments.length) return false;
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].startsWith(':')) continue;
      if (parts[i] != segments[i]) return false;
    }
    return true;
  }
}
