import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/backend.dart';
import '../../data/device.dart';
import '../../surfaces/notification_sounds.dart';
import '../../surfaces/surface_samples.dart';
import '../../data/repository.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/icon.dart';
import '../../ui/list_row.dart';
import '../../ui/toast.dart';
import '../settings/settings_state.dart';
import 'mode_switch.dart';
import 'more_widgets.dart';

/// B14 · Try notifications (1336:28442; owner, 16 Oct), opened by holding
/// the version line on More. Each row posts its B18 or B19 notification on
/// this phone [NotificationTrial.landsAfter] after the tap, so the lock
/// screen can be checked; the payout then moves on to Sent and Arrived.
/// Refresh the widgets republishes the home screen widgets from the sample
/// data. When the phone does not let iQLY notify, the banner from 484:23502
/// comes first. The Remind me row and the Sounds group are not in Figma:
/// they try the timed close reminder and the candidate iQLY sounds. The
/// last row, not in Figma either, says what this launch runs on and when
/// the API last answered its health check; holding it opens the sheet that
/// switches between Live and Preview ([pickLaunchMode]).
class TryNotificationsScreen extends ConsumerWidget {
  const TryNotificationsScreen({super.key});

  static const caption =
      'Each one lands 3 seconds after you tap, so you can lock the phone '
      'first.';
  static const soundsCaption =
      'Sounds. Each one plays on its own notification, so turn the ringer '
      'on.';
  static const coming = 'Coming in 3 seconds';
  static const refreshed = 'Widgets refreshed';
  static const noWidgets = 'This build has no widgets yet';

  /// "profile, briefs. Health checked 17 Oct, 09:41."
  static String backendLine(Backend backend, DateTime? checkedAt) => [
    if (!backend.isPreview) '${backend.names.join(', ')}.',
    checkedAt == null
        ? 'Health not checked yet.'
        : 'Health checked ${DateFormat('d MMM, HH:mm').format(checkedAt)}.',
  ].join(' ');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trial = ref.watch(notificationTrialProvider);
    final allowed = ref.watch(notificationsAllowedProvider).value ?? true;
    final backend = ref.watch(backendProvider);
    final checkedAt = ref.watch(backendProvider.notifier).checkedAt;

    void land(Future<void> Function(NotificationTrial) post) {
      if (trial == null) return;
      IqToast.show(context, coming);
      unawaited(post(trial));
    }

    Future<void> widgets() async {
      if (trial == null) return;
      final drawn = await trial.widgets();
      if (!context.mounted) return;
      IqToast.show(
        context,
        drawn ? refreshed : noWidgets,
        kind: drawn ? IqToastKind.success : IqToastKind.error,
      );
    }

    final rows = [
      (
        IqIcons.wallet,
        '₦10,000.00 on its way',
        'Requested, then Sent, then Arrived',
        (NotificationTrial t) => t.payout(),
      ),
      if (ref.watch(pollsShownProvider))
        (
          IqIcons.polls,
          'New poll from Orchid Foods',
          'With Vote now and Remind me later',
          (NotificationTrial t) => t.poll(),
        ),
      (
        IqIcons.trophy,
        'You won ₦12,500.00',
        'With the business picture',
        (NotificationTrial t) => t.won(),
      ),
      (
        IqIcons.pencil,
        'Your Sunline draft is waiting',
        'Counts down to the close',
        (NotificationTrial t) => t.draft(),
      ),
      (
        IqIcons.timer,
        'Sunline closes in 1 hour',
        'Remind me: counts down from an hour',
        (NotificationTrial t) => t.reminder(),
      ),
    ];
    const sounds = IqSound.values;

    return SubPage(
      title: 'Try notifications',
      hasFields: false,
      body: ListView(
        padding: const EdgeInsets.all(IqSpace.s4),
        children: [
          IqBanner(
            title: 'Notifications are off for iQLY on this phone.',
            action: 'Open settings',
            visible: !allowed,
            margin: const EdgeInsets.only(bottom: IqSpace.s3),
            onAction: () =>
                ref.read(deviceServiceProvider).openNotificationSettings(),
          ),
          Text(caption, style: IqText.body.copyWith(color: IqColors.fg2)),
          const SizedBox(height: IqSpace.s3),
          RowGroup(
            children: [
              for (final (i, (icon, label, description, post)) in rows.indexed)
                IqListRow(
                  icon: icon,
                  label: label,
                  description: description,
                  divider: i < rows.length - 1,
                  onTap: () => land(post),
                ),
            ],
          ),
          const SizedBox(height: IqSpace.s4),
          Text(soundsCaption, style: IqText.body.copyWith(color: IqColors.fg2)),
          const SizedBox(height: IqSpace.s3),
          RowGroup(
            children: [
              for (final (i, sound) in sounds.indexed)
                IqListRow(
                  icon: sound.isSiren ? IqIcons.zap : IqIcons.bell,
                  label: '${sound.isSiren ? 'Siren' : 'Bing'}: ${sound.label}',
                  description: sound.description,
                  divider: i < sounds.length - 1,
                  onTap: () => land((t) => t.sound(sound)),
                ),
            ],
          ),
          const SizedBox(height: IqSpace.s3),
          RowGroup(
            children: [
              IqListRow(
                icon: IqIcons.smartphone,
                label: 'Refresh the widgets',
                description: 'Closing soon and Polls, from the sample data',
                divider: false,
                onTap: widgets,
              ),
            ],
          ),
          const SizedBox(height: IqSpace.s3),
          GestureDetector(
            onLongPress: () => pickLaunchMode(context, ref),
            child: RowGroup(
              children: [
                IqListRow(
                  icon: IqIcons.info,
                  label: backend.isPreview ? 'Preview' : 'Live',
                  description: backendLine(backend, checkedAt),
                  descriptionMaxLines: 3,
                  showChevron: false,
                  divider: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
