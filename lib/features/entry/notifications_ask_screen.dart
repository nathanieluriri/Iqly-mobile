import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/transitions.dart';
import '../../data/device.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/illustration.dart';
import 'entry_widgets.dart';

/// B0 Notifications (227:11263), reached from onboarding Done. Turn on asks
/// the phone, whose own prompt is 484:23576 (answer 25); either answer, and
/// Not now, land on Discover, where the first tip shows once.
///
/// Motion (MOTION-SPEC 6.9): it pushes in from Done as the title settles and
/// the Point figure rises in.
class NotificationsAskScreen extends ConsumerStatefulWidget {
  const NotificationsAskScreen({super.key});

  @override
  ConsumerState<NotificationsAskScreen> createState() =>
      _NotificationsAskScreenState();
}

class _NotificationsAskScreenState
    extends ConsumerState<NotificationsAskScreen> {
  bool _asking = false;

  /// Figma keeps the hidden step mark's 44 pt slot over the title.
  static const double _stepSlot = 44;

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
      settle: true,
      onBack: () => goBack(context, Routes.home),
      action: EntryButtons(
        primary: 'Turn on notifications',
        onPrimary: _turnOn,
        primaryLoading: _asking,
        ghost: 'Not now',
        onGhost: () => context.go(Routes.home),
      ),
      children: [
        const SizedBox(height: _stepSlot + IqSpace.s4),
        const StaggerItem(
          index: 0,
          child: EntryTitle('Never miss a brief closing'),
        ),
        const SizedBox(height: IqSpace.s4),
        SizedBox(
          height: 252,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: IqFigure(
              IqFigures.point,
              width: 207.06,
              arrive: arrivalOf(context) == NavDirection.forward,
            ),
          ),
        ),
      ],
    );
  }
}
