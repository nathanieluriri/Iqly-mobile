import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/flags.dart';
import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../data/profile_service.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/setting_row.dart';
import '../../ui/switch.dart';
import '../../ui/top_bar.dart';
import 'settings_state.dart';

/// The label and one-line description of each switch (Figma 194:9932).
const notificationCopy = {
  NotificationTopic.closingSoon: (
    'Brief closing soon',
    'A day before, and an hour before',
  ),
  NotificationTopic.results: ('Results', 'When the business picks winners'),
  NotificationTopic.payouts: ('Payouts', 'When money lands or fails'),
  NotificationTopic.newBriefs: ('New briefs for you', 'At most once a day'),
  NotificationTopic.polls: ('Polls', 'When a poll opens'),
};

/// B14 · Notification preferences (194:9932), behind
/// Flags.notificationPreferences: five Exp/SettingRow switches. A flip
/// slides the knob (the Switch's own 160 ms) with the select haptic; a flip
/// the account refuses slides back with the error haptic. No stagger: a
/// settings list is not news. The Polls switch follows Flags.polls.
///
/// The row note promises quiet hours; the frame has no control for them
/// (its 100 pt action bar is empty), so none is built.
class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(notificationPreferencesProvider).value;
    final topics = [
      for (final topic in NotificationTopic.values)
        if (topic != NotificationTopic.polls || Flags.polls) topic,
    ];

    Future<void> flip(NotificationTopic topic, IqSwitchState state) async {
      final taken = await ref
          .read(notificationPreferencesProvider.notifier)
          .set(topic, state == IqSwitchState.on);
      if (!taken) errorHaptic();
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: IqColors.bg,
        body: SafeArea(
          child: CenteredContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IqTopBar(
                  variant: IqTopBarVariant.page,
                  title: 'Notification preferences',
                  onBack: () => context.canPop()
                      ? context.pop()
                      : context.go(Routes.profile),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      IqSpace.s4,
                      IqSpace.s4,
                      IqSpace.s4,
                      IqSpace.s4,
                    ),
                    children: [
                      if (preferences != null)
                        for (final (i, topic) in topics.indexed)
                          IqSettingRow(
                            label: notificationCopy[topic]!.$1,
                            description: notificationCopy[topic]!.$2,
                            divider: i < topics.length - 1,
                            state: preferences[topic] ?? false
                                ? IqSwitchState.on
                                : IqSwitchState.off,
                            onChanged: (state) => flip(topic, state),
                          ),
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
