import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion.dart';
import '../../core/session.dart';
import '../../core/transitions.dart';
import '../../ui/tip_card.dart';

/// B0 Home first tip (227:11321): wrap any Discover screen in it. Until
/// the session has seen the tip, Discover sits under a 60% ink scrim with
/// the TipCard, which arrive once Home has (spec 3.8); "OK, got it" is the
/// only way out, marks it seen and sends both away (card 160 ms, scrim 200
/// ms, ease-in) while the screen beneath takes taps at once.
///
/// Brief over Figma: Figma draws the status bar's dark glyphs above the
/// scrim; the status bar turns light while the scrim is up, so it reads on
/// the ink.
class FirstTipOverlay extends ConsumerWidget {
  const FirstTipOverlay({super.key, required this.child});

  final Widget child;

  static const double _frameHeight = 844;
  static const double _cardTop = 280;

  /// The card hugging the Figma title at the default text size.
  static const double _cardHeight = 225;

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
            statusBar: SystemUiOverlayStyle.light,
            top: (constraints) {
              final free = math.max(0.0, constraints.maxHeight - _cardHeight);
              return free * _cardTop / (_frameHeight - _cardHeight);
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
