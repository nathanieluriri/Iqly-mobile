import '../../core/tablet_layout.dart';
import '../../router.dart';
import '../../ui/icon.dart';
import '../../ui/tablet_nav.dart';

class TabletTab {
  const TabletTab(this.location, this.destination);

  final String location;
  final IqTabletNavDestination destination;
}

/// Where the tablet nav goes and which item a page lights (T1 · Shell):
/// a brief and its submit sit under Discover, results under Submissions,
/// a withdrawal under Wallet, help under Support. Settings and the
/// notifications page light none.
abstract final class TabletRoutes {
  static const discover = TabletTab(
    Routes.home,
    IqTabletNavDestination(label: 'Discover', icon: IqIcons.discover),
  );
  static const submissions = TabletTab(
    Routes.submissions,
    IqTabletNavDestination(
      label: 'Submissions',
      sidebarLabel: 'My submissions',
      icon: IqIcons.submissions,
    ),
  );
  static const polls = TabletTab(
    Routes.polls,
    IqTabletNavDestination(label: 'Polls', icon: IqIcons.polls),
  );
  static const activations = TabletTab(
    Routes.activations,
    IqTabletNavDestination(label: 'Activations', icon: IqIcons.zap),
  );
  static const wallet = TabletTab(
    Routes.wallet,
    IqTabletNavDestination(label: 'Wallet', icon: IqIcons.wallet),
  );
  static const support = IqTabletNavDestination(
    label: 'Support',
    icon: IqIcons.headset,
  );

  static List<TabletTab> tabs({
    required bool polls,
    required bool activations,
  }) => [
    discover,
    submissions,
    if (polls) TabletRoutes.polls,
    if (activations) TabletRoutes.activations,
    wallet,
  ];

  static bool hasChrome(String location) =>
      location.isNotEmpty && !chromelessLocation(location);

  /// Whether [location] is a tab root the shell switches to.
  static bool isTab(String location) =>
      location == Routes.home ||
      location == Routes.submissions ||
      location == Routes.wallet ||
      location == Routes.more;

  static bool _under(String location, String root) =>
      location == root || location.startsWith('$root/');

  /// The nav item [location] lights, as its location, or null.
  static String? tabOf(String location) {
    if (_under(location, Routes.home) ||
        _under(location, '/briefs') ||
        _under(location, Routes.moreSavedBriefs) ||
        _under(location, Routes.pickBrief)) {
      return Routes.home;
    }
    if (_under(location, Routes.submissions) ||
        _under(location, Routes.drafts)) {
      return Routes.submissions;
    }
    if (_under(location, Routes.polls)) return Routes.polls;
    if (_under(location, Routes.activations)) return Routes.activations;
    if (_under(location, Routes.wallet) || _under(location, '/pin')) {
      return Routes.wallet;
    }
    if (_under(location, Routes.support) ||
        _under(location, Routes.helpCentre) ||
        _under(location, Routes.help)) {
      return Routes.support;
    }
    return null;
  }
}
