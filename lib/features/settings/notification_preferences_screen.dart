import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../data/device.dart';
import '../../data/profile_service.dart';
import '../../data/repository.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/setting_row.dart';
import '../../ui/switch.dart';
import '../../ui/top_bar.dart';
import '../more/more_widgets.dart';
import 'settings_state.dart';

/// The label and one-line description of each switch (Figma 194:9932).
const notificationCopy = {
  NotificationTopic.closingSoon: (
    'Brief closing soon',
    'A day before, and an hour before',
  ),
  NotificationTopic.results: ('Results', 'When the business picks winners'),
  NotificationTopic.payouts: ('Withdrawals', 'When money lands or fails'),
  NotificationTopic.newBriefs: ('New briefs for you', 'At most once a day'),
  NotificationTopic.polls: ('Polls', 'When a poll opens'),
};

/// B14 · Notification preferences (194:9932), behind
/// Flags.notificationPreferences: five Exp/SettingRow switches. When the
/// phone does not let iQLY notify, the Urgent banner says so above them
/// with Open settings (484:23502, designer answer 25). A flip
/// slides the knob (the Switch's own 160 ms) with the select haptic; a flip
/// the account refuses slides back with the error haptic. No stagger: a
/// settings list is not news. The Polls switch shows only
/// where polls do (Flags.polls, preview launches).
///
/// Switches that cannot load show the error banner and Try again, as the
/// other pages do (the frame has no failed state); opening the page again
/// reads them again.
///
/// The row note promises quiet hours; the frame has no control for them
/// (its 100 pt action bar is empty), so none is built.
class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final switches = ref.watch(notificationPreferencesProvider);
    final preferences = switches.value;
    final allowed = ref.watch(notificationsAllowedProvider).value ?? true;
    final topics = [
      for (final topic in NotificationTopic.values)
        if (topic != NotificationTopic.polls || ref.watch(pollsShownProvider))
          topic,
    ];

    Future<void> flip(NotificationTopic topic, IqSwitchState state) async {
      final taken = await ref
          .read(notificationPreferencesProvider.notifier)
          .set(topic, state == IqSwitchState.on);
      if (!taken) errorHaptic();
    }

    return _Rechecks(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
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
                    onBack: () => goBack(context),
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
                        IqBanner(
                          title:
                              'Notifications are off for iQLY on this phone.',
                          action: 'Open settings',
                          visible: !allowed,
                          margin: const EdgeInsets.only(bottom: IqSpace.s3),
                          onAction: () => ref
                              .read(deviceServiceProvider)
                              .openNotificationSettings(),
                        ),
                        IqBanner(
                          kind: IqBannerKind.error,
                          title: 'Couldn’t load. Check your connection.',
                          action: 'Try again',
                          visible: preferences == null && switches.hasError,
                          onAction: () => ref
                              .read(notificationPreferencesProvider.notifier)
                              .retry(),
                        ),
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
      ),
    );
  }
}

/// Opening the page reads the switches again when their last read failed,
/// and coming back from the phone's settings checks the permission again,
/// so the banner goes as soon as notifications are allowed.
class _Rechecks extends ConsumerStatefulWidget {
  const _Rechecks({required this.child});

  final Widget child;

  @override
  ConsumerState<_Rechecks> createState() => _RechecksState();
}

class _RechecksState extends ConsumerState<_Rechecks> {
  late final _lifecycle = AppLifecycleListener(
    onResume: () => ref.invalidate(notificationsAllowedProvider),
  );

  @override
  void initState() {
    super.initState();
    _lifecycle;
    if (!ref.read(notificationPreferencesProvider).hasError) return;
    // After the first frame: invalidating a provider while the page mounts
    // would mark the ProviderScope above it dirty mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(notificationPreferencesProvider.notifier).retry();
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
