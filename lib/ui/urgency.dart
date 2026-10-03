import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'icon.dart';

enum IqUrgencyTone {
  hot,
  warm,
  calm,
  closed;

  /// The deadlineLabel() ladder: Hot under 24 h, Warm under 7 days, Calm
  /// otherwise or with no deadline, Closed once the brief has closed.
  static IqUrgencyTone of(Duration? remaining, {bool closed = false}) {
    if (closed || (remaining != null && remaining <= Duration.zero)) {
      return IqUrgencyTone.closed;
    }
    if (remaining == null) return IqUrgencyTone.calm;
    if (remaining < const Duration(hours: 24)) return IqUrgencyTone.hot;
    if (remaining < const Duration(days: 7)) return IqUrgencyTone.warm;
    return IqUrgencyTone.calm;
  }
}

/// Exp/Urgency: the deadline chip, a clock and the brief's own deadline
/// words on a pill that hugs its text.
class IqUrgency extends StatelessWidget {
  const IqUrgency({
    super.key,
    this.text = 'Closes in 6h',
    this.tone = IqUrgencyTone.hot,
  });

  final String text;
  final IqUrgencyTone tone;

  @override
  Widget build(BuildContext context) {
    final (fill, ink, iconInk) = switch (tone) {
      IqUrgencyTone.hot => (IqColors.accent, IqColors.brand, IqColors.brand),
      IqUrgencyTone.warm => (
        IqColors.accentSoft,
        IqColors.brand,
        IqColors.brand,
      ),
      IqUrgencyTone.calm => (IqColors.panel, IqColors.fg2, IqColors.fg2),
      IqUrgencyTone.closed => (
        IqColors.fg3,
        IqColors.primaryFg,
        IqColors.primaryFg,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(IqRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IqIcon(IqIcons.clock, size: 14, color: iconInk),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: IqText.smallStrong.copyWith(color: ink),
            ),
          ),
        ],
      ),
    );
  }
}
