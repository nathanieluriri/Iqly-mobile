import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../data/submit_data.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/illustration.dart';
import 'submit_widgets.dart';

/// B3 · Submit · sent (34:269), a moment: the Sender figure arrives, then
/// the title and the line settle in one after another; the buttons are
/// there from the first frame. Without a [receipt] the entry waits on the
/// phone for the network (contract 13.4): the same moment says so and
/// offers Discover only (no frame draws it).
class SentMoment extends StatelessWidget {
  const SentMoment({
    super.key,
    required this.receipt,
    required this.onView,
    required this.onDiscover,
  });

  final SubmitReceipt? receipt;
  final VoidCallback? onView;
  final VoidCallback onDiscover;

  static const double figureWidth = 188.24;

  @override
  Widget build(BuildContext context) {
    final queued = receipt == null;
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
                        const IqFigure(
                          IqFigures.sender,
                          width: figureWidth,
                          arrive: true,
                        ),
                        const SizedBox(height: IqSpace.s4),
                        Appear(
                          delay: IqDurations.stagger * 2,
                          child: Text(
                            queued ? 'Saved to send.' : 'Submitted. Good luck!',
                            textAlign: TextAlign.center,
                            style: IqText.title.copyWith(color: IqColors.fg),
                          ),
                        ),
                        const SizedBox(height: IqSpace.s4),
                        Appear(
                          delay: IqDurations.stagger * 3,
                          child: Text(
                            queued
                                ? 'No connection right now. It goes by itself '
                                      'once you’re back online.'
                                : 'You will get notified if your submission is selected.',
                            textAlign: TextAlign.center,
                            style: IqText.body.copyWith(color: IqColors.fg2),
                          ),
                        ),
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
            if (onView case final onView?)
              IqButton(
                label: 'View submission',
                showIcon: false,
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
