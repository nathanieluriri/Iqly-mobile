import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../core/motion.dart';
import '../../data/models.dart';
import '../../theme/theme.dart';
import '../../ui/receipt_card.dart';
import '../../ui/timeline_row.dart';
import '../wallet/wallet_format.dart';

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
/// row; [showStatus] false is the failed receipt, which draws no tag. The
/// card crossfades its tag when the status changes.
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
    return IqReceiptCard(
      amount: naira(withdrawal.amountKobo),
      to: withdrawal.destination ?? '',
      reference: withdrawal.reference ?? '',
      date: withdrawalTime(withdrawal.createdAt, now),
      status: withdrawal.status == WithdrawalStatus.completed
          ? 'Arrived'
          : capitalized(withdrawal.statusWord),
      showAmount: false,
      showStatus: showStatus,
    );
  }
}

/// The steps of a withdrawal and how many are done. On hold or arrived:
/// Requested, the approval step only when it was held (designer answer 8),
/// Sent to your bank, Arrived. Failed: Requested, Approved by iQLY when it
/// was held, Failed at the bank. Reversed (no frame, built on the failed
/// one): Requested, Sent to your bank, Reversed by the bank.
List<WithdrawalStep> withdrawalSteps(Withdrawal w, DateTime now, {int? done}) {
  String at(DateTime? time) => time == null ? '' : withdrawalTime(time, now);
  if (w.status == WithdrawalStatus.failed) {
    return [
      const WithdrawalStep('Requested', IqTimelineRowState.done),
      if (w.held || w.approvedAt != null)
        WithdrawalStep(
          'Approved by iQLY',
          IqTimelineRowState.done,
          meta: at(w.approvedAt),
        ),
      const WithdrawalStep(
        'Failed at the bank',
        IqTimelineRowState.current,
        end: true,
      ),
    ];
  }
  if (w.status == WithdrawalStatus.reversed) {
    return [
      const WithdrawalStep('Requested', IqTimelineRowState.done),
      WithdrawalStep(
        'Sent to your bank',
        IqTimelineRowState.done,
        meta: at(w.sentAt),
      ),
      const WithdrawalStep(
        'Reversed by the bank',
        IqTimelineRowState.current,
        end: true,
      ),
    ];
  }
  final reached = done ?? withdrawalStepsDone(w);
  final titles = [
    'Requested',
    if (w.held) reached > 1 ? 'Approved by iQLY' : 'Awaiting approval',
    'Sent to your bank',
    'Arrived',
  ];
  // Figma rings only a step iQLY is working on (Awaiting approval); the
  // bank's steps wait plain.
  IqTimelineRowState state(int i) => i < reached
      ? IqTimelineRowState.done
      : i == reached && titles[i] == 'Awaiting approval'
      ? IqTimelineRowState.current
      : IqTimelineRowState.upcoming;
  final last = titles.length - 1;
  return [
    for (final (i, title) in titles.indexed)
      WithdrawalStep(
        title,
        state(i),
        meta: switch (title) {
          'Awaiting approval' => 'Usually within a few hours',
          'Approved by iQLY' => at(w.approvedAt),
          'Arrived' =>
            i < reached
                ? 'Arrived at ${w.destination ?? ''} · ${at(w.completedAt)}'
                : 'Usually arrives within minutes, can take up to 24 hours.',
          _ => '',
        },
        end: i == last,
      ),
  ];
}

/// How many steps are done: Requested, [approval,] Sent, Arrived.
int withdrawalStepsDone(Withdrawal w) {
  final approval = w.held ? 1 : 0;
  if (w.status == WithdrawalStatus.completed) return 3 + approval;
  if (w.sentAt != null) return 2 + approval;
  if (w.held && w.approvedAt != null) return 2;
  return 1;
}

class WithdrawalStep {
  const WithdrawalStep(
    this.title,
    this.state, {
    this.meta = '',
    this.end = false,
  });

  final String title;
  final IqTimelineRowState state;
  final String meta;
  final bool end;
}

/// The B14 timeline. A step that completes while the screen is open plays
/// the TimelineRow chain (spec 5.30): its dot inks and its line draws down,
/// and only then does the next step move on; several at once go one by
/// one. Reduced motion: the new state at once.
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

  void _advance() {
    _done++;
    _next = Timer(IqDurations.ink + IqDurations.mark, () {
      _next = null;
      if (!mounted) return;
      if (withdrawalStepsDone(widget.withdrawal) > _done) {
        setState(_advance);
      }
    });
  }

  @override
  void dispose() {
    _next?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.withdrawal;
    final steps = withdrawalSteps(w, widget.now, done: _done);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final step in steps)
          IqTimelineRow(
            state: step.state,
            title: step.title,
            meta: step.meta,
            showLine: !step.end,
            failed: w.failed && step.state == IqTimelineRowState.current,
          ),
      ],
    );
  }
}
