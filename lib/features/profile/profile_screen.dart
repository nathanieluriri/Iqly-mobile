import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/flags.dart';
import '../../core/responsive.dart';
import '../../data/profile_service.dart';
import '../../data/repository.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/icon.dart';
import '../../ui/list_row.dart';
import '../../ui/section_title.dart';
import '../../ui/top_bar.dart';
import '../discover/app_shell.dart';
import '../onboarding/onboarding_draft.dart';
import 'profile_motion.dart' as motion;
import 'profile_state.dart';

/// B7 · Profile (40:24), the Profile tab: the name as the title and the
/// email as the greeting, then Account and Session. Saved briefs,
/// Notifications and Delete account sit behind their flags. The rows
/// arrive 40 apart on the first visit in the session (the tab keeps its
/// state, so revisits do not replay it).
///
/// Figma over its own row: Saved briefs has its divider off, so no line
/// separates it from Notifications.
/// Figma has no reaction on Sign out; it ends the session and hands off to
/// the landing (row note: shipped string).
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _signingOut = false;

  /// The device forgets the account at once; the API call that ends the
  /// session there does not hold the hand-off to the landing.
  Future<void> _signOut() async {
    if (_signingOut) return;
    _signingOut = true;
    ref.read(profileServiceProvider).signOut().ignore();
    await forgetAccount(ref);
    if (mounted) context.go(Routes.landing);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(onboardingUserProvider).value;
    final unread = ref.watch(unreadNotificationsProvider).value ?? 0;
    final bank = ref.watch(profileBankProvider).value;

    final account = [
      IqListRow(
        label: 'Your details',
        description: 'Phone, date of birth, interests',
        icon: IqIcons.profile,
        onTap: () => context.push(Routes.yourDetails),
      ),
      IqListRow(
        label: 'Bank account',
        description: bank == null ? '' : bankLine(bank),
        showDescription: bank != null,
        icon: IqIcons.bank,
        onTap: () => context.go(Routes.withdraw),
      ),
      if (Flags.savedBriefs)
        IqListRow(
          label: 'Saved briefs',
          description: 'Available offline',
          icon: IqIcons.search,
          divider: false,
          onTap: () => context.go(Routes.savedBriefs),
        ),
      if (Flags.notificationPreferences)
        IqListRow(
          label: 'Notifications',
          description: 'Closing soon, results, payouts',
          icon: IqIcons.bell,
          divider: false,
          onTap: () => context.push(Routes.notificationPreferences),
        ),
    ];
    final session = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const IqSectionTitle(
          title: 'Session',
          showCount: false,
          showLink: false,
        ),
        IqListRow(
          label: 'Sign out',
          tone: IqListRowTone.danger,
          showDescription: false,
          divider: Flags.deleteAccount,
          onTap: _signOut,
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
    );
    final slots = [
      const IqSectionTitle(title: 'Account', showCount: false, showLink: false),
      ...account,
      session,
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: IqColors.bg,
        body: SafeArea(
          bottom: false,
          child: CenteredContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IqTopBar(
                  title: user?.name ?? '',
                  greeting: user?.email ?? ' ',
                  count: '$unread',
                  showCount: unread > 0,
                  onBell: () => context.push(Routes.notifications),
                ),
                Expanded(
                  child: motion.Entrance(
                    length: motion.Entrance.listLength(slots.length),
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        IqSpace.s4,
                        0,
                        IqSpace.s4,
                        AppShell.contentInset(context),
                      ),
                      children: [
                        for (final (i, slot) in slots.indexed)
                          motion.Cue.arrive(i, child: slot),
                      ],
                    ),
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
