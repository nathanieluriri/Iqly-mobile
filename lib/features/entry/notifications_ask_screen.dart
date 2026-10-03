import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/device.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/icon.dart';
import '../../ui/step_mark.dart';
import 'entry_widgets.dart';

/// B0 Notifications (227:11263), reached from onboarding Done. Both answers
/// land on Discover, where the first tip shows once.
class NotificationsAskScreen extends ConsumerStatefulWidget {
  const NotificationsAskScreen({super.key});

  @override
  ConsumerState<NotificationsAskScreen> createState() =>
      _NotificationsAskScreenState();
}

class _NotificationsAskScreenState
    extends ConsumerState<NotificationsAskScreen> {
  bool _asking = false;

  Future<void> _turnOn() async {
    if (_asking) return;
    setState(() => _asking = true);
    await ref.read(deviceServiceProvider).requestNotificationPermission();
    if (mounted) context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    return EntryScaffold(
      hasFields: false,
      onBack: () => goBack(context, Routes.onboardingDone),
      action: EntryButtons(
        primary: 'Turn on notifications',
        onPrimary: _turnOn,
        primaryLoading: _asking,
        ghost: 'Not now',
        onGhost: () => context.go(Routes.home),
      ),
      children: const [
        Align(
          alignment: Alignment.centerLeft,
          child: IqStepMark(step: IqStepMarkStep.single, icon: IqIcons.bell),
        ),
        SizedBox(height: IqSpace.s4),
        EntryTitle('Never miss a brief closing'),
      ],
    );
  }
}
