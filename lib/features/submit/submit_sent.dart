import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../data/submit_data.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/illustration.dart';
import 'submit_widgets.dart';

/// "29 people have submitted so far, including you." (34:269), from the
/// entries the API counts with this one.
String submittedSoFar(int entries) =>
    '$entries ${entries == 1 ? 'person has' : 'people have'} submitted so '
    'far, including you.';

/// B3 · Submit · sent (34:269), a moment: the Sender figure arrives, then
/// the title, the line and the count settle in one after another; the
/// buttons are there from the first frame.
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

  static const double figureWidth = 188.24;

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
                        const IqFigure(
                          IqFigures.sender,
                          width: figureWidth,
                          arrive: true,
                        ),
                        const SizedBox(height: IqSpace.s4),
                        Appear(
                          delay: IqDurations.stagger * 2,
                          child: Text(
                            'Submitted. Good luck!',
                            textAlign: TextAlign.center,
                            style: IqText.title.copyWith(color: IqColors.fg),
                          ),
                        ),
                        const SizedBox(height: IqSpace.s4),
                        Appear(
                          delay: IqDurations.stagger * 3,
                          child: Text(
                            "Winners are picked after the brief closes. We'll tell you.",
                            textAlign: TextAlign.center,
                            style: IqText.body.copyWith(color: IqColors.fg2),
                          ),
                        ),
                        if (entries != null) ...[
                          const SizedBox(height: IqSpace.s4),
                          Appear(
                            delay: IqDurations.stagger * 4,
                            child: Text(
                              submittedSoFar(entries),
                              textAlign: TextAlign.center,
                              style: IqText.body.copyWith(color: IqColors.fg2),
                            ),
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
