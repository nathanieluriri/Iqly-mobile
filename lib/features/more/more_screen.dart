import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/flags.dart';
import '../../core/money.dart';
import '../../core/motion.dart';
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
import '../../ui/quick_action.dart';
import '../../ui/referral_card.dart';
import '../../ui/sample_avatar.dart';
import '../../ui/section_title.dart';
import '../../ui/skeleton.dart';
import '../../ui/top_bar.dart';
import '../discover/app_shell.dart';
import '../profile/profile_state.dart';
import '../referrals/referrals_screen.dart';
import 'more_state.dart';
import 'more_widgets.dart';

/// B7 · More (428:18424, scrolled 428:18663), the fourth tab root: the
/// contributor pass, the invite card, quick links, help and legal, and the
/// app rows. Every row opens a sub page over the shell (no dock); Clear
/// cache and Sign out ask first on an Exp/ConfirmSheet (429:19063,
/// 484:23036).
///
/// Figma over its prop: the Delete account row is Danger with the kit's
/// close glyph, as the frame draws it (its Icon prop says profile).
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

  Future<void> _clearCache(int bytes) async {
    final size = megabytes(bytes);
    final clear = await showIqConfirmSheet(
      Navigator.of(context, rootNavigator: true).context,
      title: 'Clear cached data?',
      body:
          'Removes $size of saved briefs and images from this phone. Your '
          'account and submissions are not affected.',
      confirmLabel: 'Clear $size',
      cancelLabel: 'Keep it',
      confirmKind: IqButtonKind.primary,
    );
    if (clear) await ref.read(cacheProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(unreadNotificationsProvider).value ?? 0;
    final pass = ref.watch(contributorPassProvider).value;
    final cache = ref.watch(cacheProvider).value;
    final ios = defaultTargetPlatform == TargetPlatform.iOS;

    final children = <Widget>[
      SizedBox(
        height: _PassSkeleton.height,
        child: LoadingGate(
          loading: pass == null,
          skeleton: const _PassSkeleton(),
          child: pass == null
              ? const SizedBox.shrink()
              : Column(
                  children: [
                    IqPressable(
                      onTap: () => context.push(Routes.profile),
                      semanticLabel: 'Your profile',
                      builder: (context, pressed) => Center(
                        child: IqAchievementCard(
                          name: pass.user.name,
                          amount: pass.earned,
                          secondary: wholeNumber(pass.points),
                          field1: pass.since,
                          field2: '${pass.submissions}',
                          field3: '${pass.wins}',
                          code: pass.code,
                          avatar: const IqSampleAvatar(size: 44),
                        ),
                      ),
                    ),
                    const SizedBox(height: IqSpace.s3),
                    IqPressable(
                      onTap: () => context.push(Routes.referrals),
                      semanticLabel: 'Referrals',
                      builder: (context, pressed) => Center(
                        child: IqReferralCard(
                          code: pass.code,
                          joined: '${pass.joined} joined',
                          onCopy: () => copyInviteCode(context, pass.code),
                          onInvite: () => context.push(Routes.referrals),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
      const IqSectionTitle(
        title: 'Quick links',
        showCount: false,
        showLink: false,
      ),
      _QuickLinks(
        actions: [
          if (Flags.polls)
            (IqIcons.polls, 'Quick polls', () => context.push(Routes.polls)),
          if (Flags.activations)
            (
              IqIcons.zap,
              'Activations',
              () => context.push(Routes.activations),
            ),
          if (Flags.savedBriefs)
            (
              IqIcons.heart,
              'Saved briefs',
              () => context.push(Routes.moreSavedBriefs),
            ),
          (
            IqIcons.bell,
            'Notifications',
            () => context.push(Routes.notifications),
          ),
          (IqIcons.bank, 'Bank account', () => context.push(Routes.selectBank)),
          (
            IqIcons.profile,
            'Your details',
            () => context.push(Routes.yourDetails),
          ),
        ],
      ),
      const IqSectionTitle(
        title: 'Help & legal',
        showCount: false,
        showLink: false,
      ),
      RowGroup(
        children: [
          IqListRow(
            label: 'Help centre',
            description: 'FAQs, chat with us, report an issue',
            icon: IqIcons.lifebuoy,
            onTap: () => context.push(Routes.helpCentre),
          ),
          IqListRow(
            label: 'Terms and conditions',
            showDescription: false,
            icon: IqIcons.document,
            onTap: () => context.push(Routes.terms),
          ),
          IqListRow(
            label: 'Privacy policy',
            showDescription: false,
            icon: IqIcons.shield,
            divider: false,
            onTap: () => context.push(Routes.privacy),
          ),
        ],
      ),
      const IqSectionTitle(title: 'App', showCount: false, showLink: false),
      RowGroup(
        children: [
          IqListRow(
            label: 'Clear cache',
            description:
                '${megabytes(cache ?? 0)} of saved briefs and images on this '
                'phone',
            icon: IqIcons.eraser,
            onTap: cache == null ? null : () => _clearCache(cache),
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
              onTap: () => context.push(Routes.deleteAccount),
            ),
        ],
      ),
      SizedBox(
        height: 46,
        child: Padding(
          padding: const EdgeInsets.only(top: IqSpace.s2),
          child: Text(
            AppRelease.footer(ios: ios),
            textAlign: TextAlign.center,
            style: IqText.mono.copyWith(color: IqColors.fg2),
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
                  onBell: () => context.push(Routes.notifications),
                ),
                Expanded(
                  child: ListView(
                    controller: _scroll,
                    padding: EdgeInsets.fromLTRB(
                      IqSpace.s4,
                      IqSpace.s4,
                      IqSpace.s4,
                      AppShell.contentInset(context),
                    ),
                    children: [
                      for (final (i, child) in children.indexed) ...[
                        if (i > 0) const SizedBox(height: IqSpace.s3),
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

/// The pass and the invite card while the pass loads on the tab's first
/// visit (spec 2.6): their two cards as tint blocks with the bars of their
/// name, amount and code, pulsing on the screen's beat.
class _PassSkeleton extends StatelessWidget {
  const _PassSkeleton();

  static const double _pass = 240;
  static const double _invite = 140;
  static const double height = _pass + IqSpace.s3 + _invite;

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
    Widget card(double height, List<Widget> bars) => Container(
      width: double.infinity,
      height: height,
      padding: const EdgeInsets.all(IqSpace.s4),
      decoration: BoxDecoration(
        color: IqColors.tint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, b) in bars.indexed) ...[
            if (i > 0) const SizedBox(height: IqSpace.s2p5),
            b,
          ],
        ],
      ),
    );
    return Semantics(
      label: 'Loading',
      child: SkeletonPulse(
        builder: (context, opacity) => Column(
          children: [
            card(_pass, [
              bar(opacity, 44, 44),
              bar(opacity, 140, 14),
              bar(opacity, 200, 28),
              bar(opacity, 120, 12),
            ]),
            const SizedBox(height: IqSpace.s3),
            card(_invite, [
              bar(opacity, 160, 14),
              bar(opacity, 240, 12),
              bar(opacity, 113, 28),
            ]),
          ],
        ),
      ),
    );
  }
}

class _QuickLinks extends StatelessWidget {
  const _QuickLinks({required this.actions});

  final List<(IqIcons, String, VoidCallback)> actions;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: IqSpace.s2,
      runSpacing: IqSpace.s2,
      children: [
        for (final (icon, label, onTap) in actions)
          IqQuickAction(
            kind: IqQuickActionKind.standard,
            icon: icon,
            label: label,
            onTap: onTap,
          ),
      ],
    );
  }
}

/// Sign out? (484:23036): the person confirms, the device forgets the
/// account and the landing takes over.
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
  await signOut(ref);
  if (context.mounted) context.go(Routes.landing);
}
