import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion.dart';
import '../../core/session.dart';
import '../../core/transitions.dart';
import '../../ui/tip_card.dart';

/// B0 Home first tip (227:11321): wrap any Discover screen in it. Until
/// the session has seen the tip, Discover sits under a 60% ink scrim with
/// the TipCard, which arrive once Home has (spec 3.8); "OK, got it" is the
/// only way out and marks it seen.
class FirstTipOverlay extends ConsumerWidget {
  const FirstTipOverlay({super.key, required this.child});

  final Widget child;

  static const double _frameHeight = 844;
  static const double _cardTop = 280;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seen = ref.watch(sessionProvider.select((s) => s.firstTipSeen));
    return Stack(
      children: [
        ExcludeSemantics(excluding: !seen, child: child),
        Positioned.fill(
          child: IqOverlay(
            shown: !seen,
            scrim: IqScrim.tip,
            delay: IqDurations.tipWait,
            top: (constraints) {
              final free = constraints.maxHeight - 200;
              return (free * _cardTop / (_frameHeight - 200)).clamp(0.0, free);
            },
            card: Semantics(
              liveRegion: true,
              child: IqTipCard(
                onAction: () =>
                    ref.read(sessionProvider.notifier).setFirstTipSeen(true),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
