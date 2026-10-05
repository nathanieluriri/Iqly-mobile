import 'package:intl/intl.dart';

import '../core/deep_links.dart';
import '../core/money.dart';
import '../data/models.dart';
import 'surface_copy.dart';

/// The tracker's normal path (designer answer 8). Held for review is not a
/// step here: the activity stays on Requested until the bank leg starts.
enum PayoutStep { requested, sent, arrived }

/// What the Live Activity (347:16446, 347:16489) and the Android payout
/// progress (350:17909) show for one withdrawal. ActivityKit reads [toJson]
/// as its ContentState.
class PayoutActivityState {
  const PayoutActivityState({
    required this.withdrawalId,
    required this.amount,
    required this.headline,
    required this.detail,
    required this.step,
    required this.route,
  });

  final String withdrawalId;
  final String amount;
  final String headline;
  final String detail;
  final PayoutStep step;
  final String route;

  int get stepNumber => step.index + 1;
  static const stepCount = 3;
  bool get finished => step == PayoutStep.arrived;
  String get compact => SurfaceCopy.compactOnItsWay;

  static const steps = [
    SurfaceCopy.stepRequested,
    SurfaceCopy.stepSent,
    SurfaceCopy.stepArrived,
  ];

  /// Null for a withdrawal that failed or came back: there is nothing on
  /// its way, so the activity ends.
  static PayoutActivityState? of(Withdrawal w) {
    if (w.failed) return null;
    final to = w.destination ?? '';
    final amount = naira(w.amountKobo);
    final step = w.status == WithdrawalStatus.completed
        ? PayoutStep.arrived
        : w.sentAt != null
        ? PayoutStep.sent
        : PayoutStep.requested;
    final arrivedAt = w.completedAt;
    return PayoutActivityState(
      withdrawalId: w.id,
      amount: amount,
      headline: step == PayoutStep.arrived
          ? '$amount paid out'
          : SurfaceCopy.onItsWay(amount),
      detail: step == PayoutStep.arrived && arrivedAt != null
          ? 'Arrived at $to at ${_clock(arrivedAt)}'
          : SurfaceCopy.payoutDetailLive(to),
      step: step,
      route: DeepLinks.withdrawal(w.id),
    );
  }

  Map<String, Object> toJson() => {
    'withdrawalId': withdrawalId,
    'amount': amount,
    'headline': headline,
    'detail': detail,
    'step': stepNumber,
    'steps': steps,
    'compact': compact,
    'link': DeepLinks.uri(route).toString(),
  };
}

String _clock(DateTime at) => DateFormat('h:mm a').format(at).toLowerCase();
