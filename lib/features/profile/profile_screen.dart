import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/flags.dart';
import '../../core/motion.dart';
import '../../core/navigation.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/avatar.dart';
import '../../ui/icon.dart';
import '../../ui/list_row.dart';
import '../../ui/pressable.dart';
import '../avatar/avatar_state.dart';
import '../avatar/choose_avatar.dart';
import '../more/more_screen.dart';
import '../more/more_state.dart';
import '../more/more_widgets.dart';
import '../referrals/referrals_screen.dart';

/// B7 · Your profile (40:24; 7 Oct, settings style): the big centred avatar
/// with its pencil (both open Choose your avatar), the name and the invite
/// code with copy, then one card: Invite friends, Your details,
/// Notification preferences (Flags.notificationPreferences) and Sign out,
/// which asks on the Sign out? sheet first. No email and no wins.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const double avatarSize = 112;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pass = ref.watch(contributorPassProvider).value;
    final avatar = ref.watch(avatarProvider.select((a) => a.spec));
    return SubPage(
      title: 'Your profile',
      hasFields: false,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
        children: [
          Padding(
            padding: const EdgeInsets.only(top: IqSpace.s1, bottom: IqSpace.s3),
            child: Column(
              children: [
                IqPressable(
                  onTap: () => chooseAvatar(context),
                  semanticLabel: 'Change your avatar',
                  builder: (context, pressed) => PressDim(
                    pressed: pressed,
                    child: SizedBox.square(
                      dimension: avatarSize,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IqAvatar(avatar, size: avatarSize),
                          Positioned(
                            left: 80,
                            top: 78,
                            child: Container(
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: IqColors.accent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: IqColors.bg,
                                  width: 3,
                                  strokeAlign: BorderSide.strokeAlignOutside,
                                ),
                              ),
                              child: const IqIcon(
                                IqIcons.pencil,
                                size: 18,
                                color: IqColors.brand,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: IqSpace.s2p5),
                SizedBox(
                  height: 52,
                  child: pass == null
                      ? null
                      : Column(
                          children: [
                            Text(
                              pass.user.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: IqText.title.copyWith(color: IqColors.fg),
                            ),
                            const SizedBox(height: IqSpace.s1p5),
                            IqPressable(
                              onTap: () => copyInviteCode(context, pass.code),
                              semanticLabel: 'Copy invite code ${pass.code}',
                              haptic: IqHaptics.select,
                              builder: (context, pressed) => PressDim(
                                pressed: pressed,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Invite code: ${pass.code}',
                                      style: IqText.body.copyWith(
                                        color: IqColors.fg2,
                                      ),
                                    ),
                                    const SizedBox(width: IqSpace.s2),
                                    const IqIcon(
                                      IqIcons.copy,
                                      size: 20,
                                      color: IqColors.brand,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: IqSpace.s5),
          RowGroup(
            outlined: true,
            children: [
              IqListRow(
                label: 'Invite friends',
                description: '₦500 when a friend wins a brief',
                icon: IqIcons.gift,
                onTap: () => context.open(Routes.referrals),
              ),
              IqListRow(
                label: 'Your details',
                description: 'Phone, date of birth, interests',
                icon: IqIcons.profile,
                onTap: () => context.open(Routes.yourDetails),
              ),
              if (Flags.notificationPreferences)
                IqListRow(
                  label: 'Notification preferences',
                  description: 'Closing soon, results, payouts',
                  icon: IqIcons.bell,
                  onTap: () => context.open(Routes.notificationPreferences),
                ),
              IqListRow(
                label: 'Sign out',
                showDescription: false,
                icon: IqIcons.logout,
                onTap: () => confirmSignOut(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
