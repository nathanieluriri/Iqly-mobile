import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'icon.dart';

/// Status tag tones from the Figma description: Completed ok, Pending warn,
/// Failed err.
enum IqReceiptCardTone { ok, warn, err }

/// Exp/ReceiptCard: the withdrawal receipt with amount, destination, Paystack
/// reference, date and a status tag, and a dashed tear line at the foot.
/// Share receipt exports this card.
///
/// Figma over brief: only the Completed tone is drawn; the tone is picked from the status word.
/// Figma over brief: the status tag has radius 6 (a tag), not a full pill.
/// Brief over Figma: [showAmount] hides the Amount row on the tracker; Figma has no such prop.
class IqReceiptCard extends StatelessWidget {
  const IqReceiptCard({
    super.key,
    this.amount = '₦40,000.00',
    this.to = 'Access Bank ••6789 · ADAEZE OKAFOR',
    this.reference = 'IQ-WD-240923-7F3K',
    this.date = 'Tue, 23 Sep · 4:12 pm',
    this.status = 'Completed',
    this.showAmount = true,
  });

  final String amount;
  final String to;
  final String reference;
  final String date;
  final String status;
  final bool showAmount;

  static const double width = 358;

  static IqReceiptCardTone toneOf(String status) =>
      switch (status.toLowerCase()) {
        'completed' => IqReceiptCardTone.ok,
        'failed' || 'reversed' => IqReceiptCardTone.err,
        _ => IqReceiptCardTone.warn,
      };

  @override
  Widget build(BuildContext context) {
    final (fill, ink) = switch (toneOf(status)) {
      IqReceiptCardTone.ok => (IqColors.okSoft, IqColors.ok),
      IqReceiptCardTone.warn => (IqColors.warnSoft, IqColors.warn),
      IqReceiptCardTone.err => (IqColors.errSoft, IqColors.errStrong),
    };
    final strong = IqText.bodyStrong.copyWith(color: IqColors.fg);
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: IqColors.card,
        border: Border.all(color: IqColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              IqSpace.s5,
              IqSpace.s5,
              IqSpace.s5,
              IqSpace.s6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    children: [
                      const IqIcon(
                        IqIcons.receipt,
                        size: 20,
                        color: IqColors.brand,
                      ),
                      const SizedBox(width: IqSpace.s2p5),
                      Text(
                        'Withdrawal receipt'.toUpperCase(),
                        style: IqText.mono.copyWith(color: IqColors.fg2),
                      ),
                      const SizedBox(width: 30),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: IqSpace.s2,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: fill,
                            borderRadius: BorderRadius.circular(IqRadius.sm),
                          ),
                          child: Text(
                            status,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: IqText.smallStrong.copyWith(color: ink),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (showAmount)
                  _Row(
                    label: 'Amount',
                    value: Text(
                      amount,
                      textAlign: TextAlign.right,
                      style: strong,
                    ),
                  ),
                _Row(
                  label: 'To',
                  value: Text(to, textAlign: TextAlign.right, style: strong),
                ),
                _Row(
                  label: 'Reference',
                  value: Text(
                    reference.toUpperCase(),
                    textAlign: TextAlign.right,
                    style: IqText.mono.copyWith(color: IqColors.fg),
                  ),
                ),
                _Row(
                  label: 'Date',
                  divider: false,
                  value: Text(date, textAlign: TextAlign.right, style: strong),
                ),
              ],
            ),
          ),
          const Positioned(
            left: IqSpace.s5 - 1,
            right: IqSpace.s5 - 1,
            bottom: 10.25,
            height: 1.5,
            child: CustomPaint(painter: _TearPainter()),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.divider = true});

  final String label;
  final Widget value;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: divider
            ? const Border(bottom: BorderSide(color: IqColors.line))
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.only(top: IqSpace.s3, bottom: divider ? 11 : 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: IqText.small.copyWith(color: IqColors.fg3)),
            Expanded(child: value),
          ],
        ),
      ),
    );
  }
}

class _TearPainter extends CustomPainter {
  const _TearPainter();

  static const double dash = 4;
  static const double gap = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = IqColors.line2
      ..strokeWidth = size.height;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + dash).clamp(0, size.width), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_TearPainter oldDelegate) => false;
}
