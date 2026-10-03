import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../../theme/theme.dart';
import '../../ui/tip_card.dart';

/// B0 Home first tip (227:11321): wrap any Discover screen in it. Until
/// the session has seen the tip, Discover sits under a 60% ink scrim with
/// the TipCard; "OK, got it" is the only way out and marks it seen.
class FirstTipOverlay extends ConsumerWidget {
  const FirstTipOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seen = ref.watch(sessionProvider.select((s) => s.firstTipSeen));
    return Stack(
      children: [
        ExcludeSemantics(excluding: !seen, child: child),
        if (!seen)
          Positioned.fill(
            child: _Tip(
              onDone: () =>
                  ref.read(sessionProvider.notifier).setFirstTipSeen(true),
            ),
          ),
      ],
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.onDone});

  final VoidCallback onDone;

  static const double _frameHeight = 844;
  static const double _cardTop = 280;

  @override
  Widget build(BuildContext context) {
    final fade = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: fade,
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Material(type: MaterialType.transparency, child: child),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final free = constraints.maxHeight - 200;
          final top = (free * _cardTop / (_frameHeight - 200)).clamp(0.0, free);
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: ColoredBox(
                    color: IqColors.brand.withValues(alpha: 0.6),
                  ),
                ),
              ),
              Positioned(
                top: top,
                left: 0,
                right: 0,
                child: Center(
                  child: Semantics(
                    liveRegion: true,
                    child: IqTipCard(onAction: onDone),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
