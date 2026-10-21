import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/flags.dart';
import '../../data/referrals_service.dart' show referralsShownProvider;
import '../../data/repository.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/biz_nav_item.dart';
import '../../ui/icon.dart';
import '../shell/tablet_page.dart';

class _Section {
  const _Section(this.label, this.icon, this.location, {this.also = const []});

  final String label;
  final IqIcons icon;
  final String location;

  /// Other roots that light this item (Security holds the PIN pages).
  final List<String> also;
}

/// T15 · Settings (Mobile App · tablet, 1852:59891): "Settings" over the
/// 184 sub-navigation beside the open page, in both layouts: Your details,
/// Referrals and iQL points, a rule, then Notifications and Security.
/// Security is the tablet's More page (the PIN, the app's other settings
/// and Sign out), so the sub-navigation has no More item.
class TabletSettings extends ConsumerWidget {
  const TabletSettings({
    super.key,
    required this.location,
    required this.child,
  });

  final String location;
  final Widget child;

  static bool covers(String location) =>
      _roots.any((r) => location == r || location.startsWith('$r/'));

  static const _roots = [
    Routes.profile,
    Routes.referrals,
    Routes.pointsLeaderboard,
    Routes.more,
    '/pin',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final first = [
      const _Section('Your details', IqIcons.profile, Routes.yourDetails),
      if (ref.watch(referralsShownProvider))
        const _Section('Referrals', IqIcons.gift, Routes.referrals),
      if (ref.watch(leaderboardShownProvider))
        const _Section('iQL points', IqIcons.medal, Routes.pointsLeaderboard),
    ];
    final second = [
      if (Flags.notificationPreferences)
        const _Section(
          'Notifications',
          IqIcons.bell,
          Routes.notificationPreferences,
        ),
      const _Section('Security', IqIcons.lock, Routes.more, also: ['/pin']),
    ];
    bool under(String root) =>
        location == root || location.startsWith('$root/');
    bool open(_Section s) =>
        location == s.location ||
        (location.startsWith('${s.location}/') &&
            s.location != Routes.profile) ||
        s.also.any(under);
    Widget item(_Section s) => Padding(
      padding: const EdgeInsets.only(bottom: IqSpace.s0p5),
      child: IqBizNavItem(
        label: s.label,
        icon: s.icon,
        state: open(s) ? IqBizNavItemState.active : IqBizNavItemState.standard,
        onTap: open(s) ? null : () => context.go(s.location),
      ),
    );
    final pad = TabletPage.padding(context);
    return Material(
      color: IqColors.card,
      child: Padding(
        padding: EdgeInsets.fromLTRB(pad.left, pad.top, pad.right, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: IqText.display.copyWith(color: IqColors.brand),
            ),
            const SizedBox(height: IqSpace.s6),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 184,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ...first.map(item),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: IqSpace.s2),
                          child: SizedBox(
                            height: 1,
                            child: ColoredBox(color: IqColors.line),
                          ),
                        ),
                        ...second.map(item),
                      ],
                    ),
                  ),
                  const SizedBox(width: IqSpace.s8),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) => MediaQuery(
                        data: MediaQuery.of(context)
                            .copyWith(size: box.biggest),
                        child: ClipRect(child: child),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
