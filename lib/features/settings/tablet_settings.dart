import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/flags.dart';
import '../../data/pin_service.dart' show pinServiceProvider;
import '../../data/referrals_service.dart' show referralsShownProvider;
import '../../data/repository.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/biz_nav_item.dart';
import '../../ui/icon.dart';
import '../shell/tablet_page.dart';

class _Section {
  const _Section(this.label, this.icon, this.location, {this.divider = false});

  final String label;
  final IqIcons icon;
  final String location;
  final bool divider;
}

/// T15 · Settings (Mobile App · tablet, 1852:59891): "Settings" over the
/// 184 sub-navigation beside the open page, in both layouts. Each settings
/// page is the app's own, laid in the content column.
///
/// Figma over the app: Security holds the PIN; the app's other settings
/// (help, legal, cache, delete account) keep their More page, which the
/// sub-navigation links last and which keeps its own full-width layout.
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
    '/pin',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = [
      const _Section('Your details', IqIcons.profile, Routes.yourDetails),
      if (ref.watch(referralsShownProvider))
        const _Section('Referrals', IqIcons.gift, Routes.referrals),
      if (ref.watch(leaderboardShownProvider))
        const _Section('iQL points', IqIcons.medal, Routes.pointsLeaderboard),
      if (Flags.notificationPreferences)
        const _Section(
          'Notifications',
          IqIcons.bell,
          Routes.notificationPreferences,
          divider: true,
        ),
      if (ref.watch(pinServiceProvider) != null)
        const _Section('Security', IqIcons.lock, '/pin'),
      const _Section('More', IqIcons.more, Routes.more),
    ];
    bool open(_Section s) =>
        location == s.location ||
        (location.startsWith('${s.location}/') && s.location != Routes.profile);
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
                        for (final s in sections) ...[
                          if (s.divider)
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: IqSpace.s2,
                              ),
                              child: SizedBox(
                                height: 1,
                                child: ColoredBox(color: IqColors.line),
                              ),
                            ),
                          IqBizNavItem(
                            label: s.label,
                            icon: s.icon,
                            state: open(s)
                                ? IqBizNavItemState.active
                                : IqBizNavItemState.standard,
                            onTap: open(s)
                                ? null
                                : () => context.go(s.location),
                          ),
                          const SizedBox(height: IqSpace.s0p5),
                        ],
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
