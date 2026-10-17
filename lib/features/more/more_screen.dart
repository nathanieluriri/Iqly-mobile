import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/flags.dart';
import '../../core/money.dart';
import '../../core/motion.dart';
import '../../core/navigation.dart';
import '../../core/responsive.dart';
import '../../data/cache_service.dart';
import '../../data/repository.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/achievement_card.dart';
import '../../ui/button.dart';
import '../../ui/confirm_sheet.dart';
import '../../ui/icon.dart';
import '../../ui/list_row.dart';
import '../../ui/pressable.dart';
import '../../ui/referral_card.dart';
import '../../ui/skeleton.dart';
import '../../ui/top_bar.dart';
import '../avatar/avatar_state.dart';
import '../avatar/choose_avatar.dart';
import '../discover/app_shell.dart';
import '../onboarding/onboarding_draft.dart';
import '../profile/profile_state.dart';
import '../profile/leaving.dart';
import '../referrals/referrals_screen.dart';
import 'more_state.dart';
import 'more_widgets.dart';

/// B7 · More (428:18424, scrolled 428:18663; 7 Oct), the fourth tab root:
/// the summary card and the invite card, then three plain lists (the
/// shortcuts, help and legal, the app) and the version line. No headings,
/// no descriptions. The card opens Your profile, its avatar or pencil the
/// avatar picker and its rank the iQL points board. Every row opens a sub
/// page over the shell (no dock); Clear cache and Sign out ask first on an
/// Exp/ConfirmSheet (429:19063, 484:23036).
///
/// Figma over its prop: the Delete account row is Danger with the kit's
/// close glyph, as the frame draws it (its Icon prop says profile).
///
/// A live launch has no iQL points or referrals yet
/// ([pointsAndReferralsProvider]): the card shows the name alone, and the
/// invite card and the Leaderboard row go (no frame draws More without
/// them). Its Clear cache names what the phone keeps for the person, in KB
/// under a megabyte; the frame's 42 MB is the preview's.
class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// The size as it is now: the phone keeps more as the person browses.
  /// One the store cannot count goes unnamed.
  Future<void> _clearCache() async {
    final bytes = await ref.refresh(cacheProvider.future);
    if (!mounted) return;
    final size = bytes == null ? null : storageSize(bytes);
    final clear = await showIqConfirmSheet(
      Navigator.of(context, rootNavigator: true).context,
      title: 'Clear cached data?',
      body:
          'Removes ${size == null ? '' : '$size of '}saved briefs and images '
          'from this phone. Your account and submissions are not affected.',
      confirmLabel: size == null ? 'Clear' : 'Clear $size',
      cancelLabel: 'Keep it',
      confirmKind: IqButtonKind.primary,
    );
    if (clear) await ref.read(cacheProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(unreadNotificationsProvider).value ?? 0;
    final pass = ref.watch(contributorPassProvider).value;
    final extras = ref.watch(pointsAndReferralsProvider);
    final code = pass?.code;
    final cache = ref.watch(cacheProvider);
    final ios = defaultTargetPlatform == TargetPlatform.iOS;

    final avatar = ref.watch(avatarProvider.select((a) => a.spec));
    final children = <Widget>[
      SizedBox(
        height: _PassSkeleton.heightFor(pointsAndReferrals: extras),
        child: LoadingGate(
          loading: pass == null,
          skeleton: _PassSkeleton(pointsAndReferrals: extras),
          child: pass == null
              ? const SizedBox.shrink()
              : Column(
                  children: [
                    _CardPress(
                      onTap: () => context.open(Routes.profile),
                      label: 'Your profile',
                      child: IqAchievementCard(
                        name: ref.watch(accountNameProvider) ?? pass.user.name,
                        points: switch (pass.points) {
                          final points? => wholeNumber(points),
                          null => '',
                        },
                        rank: pass.rank == null ? '' : '#${pass.rank}',
                        avatar: avatar,
                        onAvatarTap: () => chooseAvatar(context),
                        onRankTap: () => context.open(Routes.pointsLeaderboard),
                      ),
                    ),
                    if (code != null) ...[
                      const SizedBox(height: IqSpace.s3),
                      _CardPress(
                        onTap: () => context.open(Routes.referrals),
                        label: 'Referrals',
                        child: IqReferralCard(
                          code: code,
                          onCopy: () => copyInviteCode(context, code),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
      RowGroup(
        children: [
          if (ref.watch(pollsShownProvider))
            IqListRow(
              label: 'Quick polls',
              showDescription: false,
              icon: IqIcons.polls,
              onTap: () => context.open(Routes.polls),
            ),
          if (ref.watch(activationsShownProvider))
            IqListRow(
              label: 'Activations',
              showDescription: false,
              icon: IqIcons.zap,
              onTap: () => context.open(Routes.activations),
            ),
          if (Flags.savedBriefs)
            IqListRow(
              label: 'Saved briefs',
              showDescription: false,
              icon: IqIcons.heart,
              onTap: () => context.open(Routes.moreSavedBriefs),
            ),
          if (extras)
            IqListRow(
              label: 'Leaderboard',
              showDescription: false,
              icon: IqIcons.trophy,
              onTap: () => context.open(Routes.pointsLeaderboard),
            ),
          IqListRow(
            label: 'Bank account',
            showDescription: false,
            icon: IqIcons.bank,
            divider: false,
            onTap: () => context.open(Routes.selectBank),
          ),
        ],
      ),
      RowGroup(
        children: [
          IqListRow(
            label: 'Help centre',
            showDescription: false,
            icon: IqIcons.lifebuoy,
            onTap: () => context.open(Routes.helpCentre),
          ),
          IqListRow(
            label: 'Terms and conditions',
            showDescription: false,
            icon: IqIcons.document,
            onTap: () => context.open(Routes.terms),
          ),
          IqListRow(
            label: 'Privacy policy',
            showDescription: false,
            icon: IqIcons.shield,
            divider: false,
            onTap: () => context.open(Routes.privacy),
          ),
        ],
      ),
      RowGroup(
        children: [
          IqListRow(
            label: 'Clear cache',
            showDescription: false,
            icon: IqIcons.eraser,
            onTap: cache.hasValue ? _clearCache : null,
          ),
          IqListRow(
            label: 'Sign out',
            showDescription: false,
            icon: IqIcons.logout,
            divider: Flags.deleteAccount,
            onTap: () => confirmSignOut(context, ref),
          ),
          if (Flags.deleteAccount)
            IqListRow(
              label: 'Delete account',
              tone: IqListRowTone.danger,
              showDescription: false,
              divider: false,
              onTap: () => context.open(Routes.deleteAccount),
            ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: IqSpace.s2),
        child: GestureDetector(
          onLongPress: () {
            IqHaptics.hold.play();
            context.open(Routes.tryNotifications);
          },
          child: Text(
            (ref.watch(buildInfoProvider).value ?? BuildInfo.sample).footer(
              ios: ios,
            ),
            textAlign: TextAlign.center,
            style: IqText.mono.copyWith(color: IqColors.fg3),
          ),
        ),
      ),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: IqColors.bg,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          bottom: false,
          child: CenteredContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IqTopBar(
                  title: 'More',
                  count: '$unread',
                  showCount: unread > 0,
                  showWallet: false,
                  onBell: () => context.open(Routes.notifications),
                ),
                Expanded(
                  child: ListView(
                    controller: _scroll,
                    padding: EdgeInsets.fromLTRB(
                      IqSpace.s4,
                      IqSpace.s5,
                      IqSpace.s4,
                      AppShell.contentInset(context),
                    ),
                    children: [
                      for (final (i, child) in children.indexed) ...[
                        if (i > 0) const SizedBox(height: IqSpace.s4),
                        child,
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The summary and invite cards while the pass loads on the tab's first
/// visit (spec 2.6): their two cards as tint blocks with the bars of the
/// avatar, the name, the points and the code, pulsing on the screen's beat.
/// Without [pointsAndReferrals], the summary card with the name alone.
class _PassSkeleton extends StatelessWidget {
  const _PassSkeleton({required this.pointsAndReferrals});

  final bool pointsAndReferrals;

  static double heightFor({required bool pointsAndReferrals}) =>
      IqAchievementCard.size.height +
      (pointsAndReferrals ? IqSpace.s3 + IqReferralCard.size.height : 0);

  @override
  Widget build(BuildContext context) {
    Widget bar(Animation<double> opacity, double width, double height) =>
        FadeTransition(
          opacity: opacity,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: IqColors.brandSoft,
              borderRadius: BorderRadius.circular(height / 2),
            ),
          ),
        );
    Widget card(Size size, Color colour, Widget lead, List<Widget> bars) =>
        Container(
          width: double.infinity,
          height: size.height,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: colour,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              lead,
              const SizedBox(width: 14),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, b) in bars.indexed) ...[
                    if (i > 0) const SizedBox(height: IqSpace.s2),
                    b,
                  ],
                ],
              ),
            ],
          ),
        );
    return Semantics(
      label: 'Loading',
      child: SkeletonPulse(
        builder: (context, opacity) => Column(
          children: [
            card(IqAchievementCard.size, IqColors.tint, bar(opacity, 60, 60), [
              bar(opacity, 140, 14),
              if (pointsAndReferrals) bar(opacity, 96, 12),
            ]),
            if (pointsAndReferrals) ...[
              const SizedBox(height: IqSpace.s3),
              card(
                IqReferralCard.size,
                IqColors.accentSoft,
                bar(opacity, 52, 52),
                [bar(opacity, 180, 14), bar(opacity, 86, 12)],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A card that opens a page: it sinks to the card press scale while held.
class _CardPress extends StatelessWidget {
  const _CardPress({
    required this.onTap,
    required this.label,
    required this.child,
  });

  final VoidCallback onTap;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IqPressable(
      onTap: onTap,
      semanticLabel: label,
      builder: (context, pressed) => Center(
        child: AnimatedScale(
          scale: pressed && !MediaQuery.disableAnimationsOf(context)
              ? IqScale.cardPress
              : 1,
          duration: pressMotion(context, pressed),
          curve: IqCurves.easeOut,
          child: child,
        ),
      ),
    );
  }
}

/// Sign out? (484:23036): the person confirms, the filling mark covers the
/// screen as the sheet goes down while the device forgets the account, and
/// the landing takes over.
Future<void> confirmSignOut(BuildContext context, WidgetRef ref) async {
  final out = await showIqConfirmSheet(
    Navigator.of(context, rootNavigator: true).context,
    title: 'Sign out?',
    body:
        'Your drafts stay on this phone. Sign back in any time with the same '
        'email.',
    confirmLabel: 'Sign out',
    cancelLabel: 'Stay signed in',
  );
  if (!out || !context.mounted) return;
  await leaveUnderLoader(
    context,
    label: 'Signing out',
    work: () => forgetAccount(ref),
    to: Routes.landing,
  );
}
