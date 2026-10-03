import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../data/submit_data.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/highlight.dart';
import 'submit_widgets.dart';

/// B3 · Submit · sent (34:269), a moment (MOTION-SPEC §7.4): the Bulb
/// arrives, the title appears at +80, the line under it at +120, the count
/// at +160 with its green Highlight wiping from +240; the buttons are there
/// from the first frame. The screen plays the success haptic as it lands.
/// "You're 1 of 29 so far" counts the entries with this one, when the API
/// says how many there are.
class SentMoment extends StatelessWidget {
  const SentMoment({
    super.key,
    required this.receipt,
    required this.onView,
    required this.onDiscover,
  });

  final SubmitReceipt receipt;
  final VoidCallback onView;
  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context) {
    final entries = receipt.entries;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const BulbArrival(),
                        const SizedBox(height: IqSpace.s4),
                        Appear(
                          delay: IqDurations.stagger * 2,
                          child: Text(
                            "You've submitted to this brief.",
                            textAlign: TextAlign.center,
                            style: IqText.title.copyWith(color: IqColors.fg),
                          ),
                        ),
                        const SizedBox(height: IqSpace.s4),
                        Appear(
                          delay: IqDurations.stagger * 3,
                          child: Text(
                            'Results land in My submissions.',
                            textAlign: TextAlign.center,
                            style: IqText.body.copyWith(color: IqColors.fg2),
                          ),
                        ),
                        if (entries != null) ...[
                          const SizedBox(height: IqSpace.s4),
                          Appear(
                            delay: IqDurations.stagger * 4,
                            child: _Count(entries: entries),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        SubmitActionBar(
          children: [
            IqButton(
              label: 'View submission',
              width: double.infinity,
              onTap: onView,
            ),
            IqButton(
              label: 'Back to Discover',
              kind: IqButtonKind.ghost,
              showIcon: false,
              onTap: onDiscover,
            ),
          ],
        ),
      ],
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.entries});

  final int entries;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("You're", style: IqText.body.copyWith(color: IqColors.fg2)),
          const SizedBox(width: IqSpace.s2),
          DelayedHighlight(
            text: '1 of $entries',
            tone: IqHighlightTone.green,
            at: IqDurations.mark,
          ),
          const SizedBox(width: IqSpace.s2),
          Text('so far', style: IqText.small.copyWith(color: IqColors.fg3)),
        ],
      ),
    );
  }
}
