import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../data/models.dart';
import '../../theme/theme.dart';
import '../../ui/receipt_card.dart';
import '../../ui/timeline_row.dart';
import '../wallet/wallet_format.dart';
import '../wallet/wallet_motion.dart';

/// The B14 hero amount (Mob/Figure).
class WithdrawalAmount extends StatelessWidget {
  const WithdrawalAmount({super.key, required this.withdrawal});

  final Withdrawal withdrawal;

  @override
  Widget build(BuildContext context) => Text(
    naira(withdrawal.amountKobo),
    style: IqText.figure.copyWith(color: IqColors.fg),
  );
}

/// Exp/ReceiptCard for a withdrawal. The hero amount above owns the Amount
/// row; [showStatus] false is the failed receipt, which draws no tag. A
/// status change crossfades the card (only the tag differs), 150.
class WithdrawalReceipt extends StatelessWidget {
  const WithdrawalReceipt({
    super.key,
    required this.withdrawal,
    required this.now,
    this.showStatus = true,
  });

  final Withdrawal withdrawal;
  final DateTime now;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final status = capitalized(withdrawal.statusWord);
    return AnimatedSwitcher(
      duration: walletMotion(context, WalletDurations.crossfade),
      switchInCurve: WalletCurves.easeOut,
      switchOutCurve: WalletCurves.easeOut,
      child: IqReceiptCard(
        key: ValueKey(status),
        amount: naira(withdrawal.amountKobo),
        to: withdrawal.destination ?? '',
        reference: withdrawal.reference ?? '',
        date: withdrawalTime(withdrawal.createdAt, now),
        status: status,
        showAmount: false,
        showStatus: showStatus,
      ),
    );
  }
}

/// How many of Requested, Approved, Sent and Arrived are done.
int withdrawalStepsDone(Withdrawal w) {
  if (w.status == WithdrawalStatus.completed) return 4;
  if (w.sentAt != null) return 3;
  if (w.approvedAt != null ||
      w.status == WithdrawalStatus.processing ||
      w.failed) {
    return 2;
  }
  return 1;
}

class _Step {
  const _Step(this.title, this.state, {this.meta = '', this.line = true});

  final String title;
  final IqTimelineRowState state;
  final String meta;
  final bool line;
}

/// The B14 timeline. On the tracker: Requested, then Awaiting approval
/// (Approved by iQLY once done), Sent to your bank and Arrived; done steps
/// after the first carry their time. On a failed or reversed withdrawal:
/// Requested, Approved by iQLY and the Current row on err, "Failed at the
/// bank".
///
/// A step that completes while the screen is open plays the TimelineRow
/// chain (MOTION-SPEC §5.30): its dot inks and its line draws down, and only
/// then does the next dot take the ring; several at once go one by one.
/// Reduced motion: the new state at once. Rows settle in with the page.
class WithdrawalTimeline extends StatefulWidget {
  const WithdrawalTimeline({
    super.key,
    required this.withdrawal,
    required this.now,
  });

  final Withdrawal withdrawal;
  final DateTime now;

  @override
  State<WithdrawalTimeline> createState() => _WithdrawalTimelineState();
}

class _WithdrawalTimelineState extends State<WithdrawalTimeline> {
  late int _done = withdrawalStepsDone(widget.withdrawal);
  bool _ringWaits = false;
  Timer? _next;

  @override
  void didUpdateWidget(WithdrawalTimeline old) {
    super.didUpdateWidget(old);
    final target = withdrawalStepsDone(widget.withdrawal);
    if (target <= _done || _next != null) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _done = target;
      return;
    }
    _advance();
  }

  /// Marks the next step done; the step after it takes the ring once the
  /// dot has inked and the line has drawn.
  void _advance() {
    _done++;
    _ringWaits = true;
    _next = Timer(WalletDurations.ink + WalletDurations.mark, () {
      _next = null;
      if (!mounted) return;
      setState(() => _ringWaits = false);
      if (withdrawalStepsDone(widget.withdrawal) > _done) setState(_advance);
    });
  }

  @override
  void dispose() {
    _next?.cancel();
    super.dispose();
  }

  String _at(DateTime? time) =>
      time == null ? '' : withdrawalTime(time, widget.now);

  List<_Step> _steps() {
    final w = widget.withdrawal;
    if (w.failed) {
      return [
        const _Step('Requested', IqTimelineRowState.done),
        _Step(
          'Approved by iQLY',
          IqTimelineRowState.done,
          meta: _at(w.approvedAt),
        ),
        const _Step(
          'Failed at the bank',
          IqTimelineRowState.current,
          line: false,
        ),
      ];
    }
    IqTimelineRowState state(int i) {
      if (i < _done) return IqTimelineRowState.done;
      if (i == _done && !_ringWaits) return IqTimelineRowState.current;
      return IqTimelineRowState.upcoming;
    }

    return [
      const _Step('Requested', IqTimelineRowState.done),
      _done > 1
          ? _Step(
              'Approved by iQLY',
              IqTimelineRowState.done,
              meta: _at(w.approvedAt),
            )
          : _Step(
              'Awaiting approval',
              state(1),
              meta: 'Usually within a few hours',
            ),
      _Step(
        'Sent to your bank',
        state(2),
        meta: _done > 2 ? _at(w.sentAt) : '',
      ),
      _Step(
        'Arrived',
        state(3),
        meta: _done > 3 ? _at(w.completedAt) : '1 to 2 business days',
        line: false,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final failed = widget.withdrawal.failed;
    final steps = _steps();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, step) in steps.indexed)
          Cue.settle(
            i + 1,
            IqTimelineRow(
              state: step.state,
              title: step.title,
              meta: step.meta,
              showLine: step.line,
              failed: failed && step.state == IqTimelineRowState.current,
            ),
          ),
      ],
    );
  }
}
