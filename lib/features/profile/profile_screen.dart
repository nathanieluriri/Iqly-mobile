import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/flags.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/highlight.dart';
import '../../ui/icon.dart';
import '../../ui/list_row.dart';
import '../../ui/sample_avatar.dart';
import '../../ui/section_title.dart';
import '../more/more_screen.dart';
import '../more/more_state.dart';
import '../more/more_widgets.dart';

/// B7 · Your profile (40:24), trimmed (designer answer 45): the pass header
/// (avatar, name, email, wins), then Your details, Notification
/// preferences (Flags.notificationPreferences) and Sign out, which asks on
/// the Sign out? sheet first.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pass = ref.watch(contributorPassProvider).value;
    final wins = pass?.wins ?? 0;
    return SubPage(
      title: 'Your profile',
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
        children: [
          SizedBox(
            height: 81,
            child: pass == null
                ? null
                : Row(
                    children: [
                      const IqSampleAvatar(size: 64),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pass.user.name,
                              style: IqText.title.copyWith(color: IqColors.fg),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              pass.user.email,
                              style: IqText.small.copyWith(color: IqColors.fg2),
                            ),
                            const SizedBox(height: 2),
                            IqHighlight(
                              text: wins == 1
                                  ? '1 win so far'
                                  : '$wins wins so far',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: IqSpace.s3),
          const IqSectionTitle(
            title: 'Account',
            showCount: false,
            showLink: false,
          ),
          const SizedBox(height: IqSpace.s3),
          RowGroup(
            outlined: true,
            children: [
              IqListRow(
                label: 'Your details',
                description: 'Phone, date of birth, interests',
                icon: IqIcons.profile,
                onTap: () => context.push(Routes.yourDetails),
              ),
              if (Flags.notificationPreferences)
                IqListRow(
                  label: 'Notification preferences',
                  description: 'Closing soon, results, payouts',
                  icon: IqIcons.bell,
                  onTap: () => context.push(Routes.notificationPreferences),
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
