import 'package:intl/intl.dart';

import '../../core/deadline.dart';
import '../../core/money.dart';
import '../../data/activations_data.dart';
import '../../ui/activation_ticket.dart';
import '../../ui/countdown.dart';

/// The Exp/Countdown time: "5h 40m" while Hot, then whole hours ("18h",
/// "36h") and from two days whole days ("2 days"), each rounded down so it
/// never promises more time than is left.
String countdownText(Duration left) {
  if (left <= Duration.zero) return 'Closed';
  if (left < DeadlineRules.countdownHot) {
    final minutes = left.inMinutes % Duration.minutesPerHour;
    if (left.inHours == 0) return '${minutes}m';
    return minutes == 0 ? '${left.inHours}h' : '${left.inHours}h ${minutes}m';
  }
  if (left < ActivationRules.countsHours) return '${left.inHours}h';
  return _count(left.inDays, 'day');
}

String _count(int n, String unit) => '$n ${n == 1 ? unit : '${unit}s'}';

Duration activationLeft(Activation activation, DateTime now) =>
    timeLeft(activation.closesAt, now)!;

IqCountdownTone countdownTone(Activation activation, DateTime now) =>
    IqCountdownTone.of(
      activationLeft(activation, now),
      closed: activation.closedAt(now),
    );

/// The ProgressThread count while steps wait: "2 DAYS LEFT".
String leftCount(Activation activation, DateTime now) {
  final left = activationLeft(activation, now);
  return left <= Duration.zero ? 'Closed' : '${countdownText(left)} left';
}

/// The ProgressThread count once a step is past its window: "1 DAY WAITING".
String waitingCount(Activation activation, DateTime now) {
  final since = activation.waitingSince ?? now;
  return '${_count(now.difference(since).inDays, 'day')} waiting';
}

/// "Thu, 1:52 pm", as the B8 and B9 timelines write a moment.
String dayTime(DateTime at) =>
    '${DateFormat('EEE').format(at)}, '
    '${DateFormat('h:mm a').format(at).toLowerCase()}';

/// "0:42".
String videoLength(Duration length) =>
    '${length.inMinutes}:'
    '${(length.inSeconds % Duration.secondsPerMinute).toString().padLeft(2, '0')}';

/// "18 MB".
String videoSize(int bytes) => bytes >= 1000000
    ? '${(bytes / 1000000).round()} MB'
    : '${(bytes / 1000).ceil()} KB';

/// "Earn ₦1,500": rewards are reward pools, no decimals.
String earn(Activation activation) =>
    'Earn ${rewardPool(activation.rewardKobo)}';

String reward(Activation activation) => rewardPool(activation.rewardKobo);

/// "3 steps · about 10 min".
String stepsLine(Activation activation) =>
    '${_count(activation.steps.length, 'step')} · '
    'about ${activation.minutes} min';

/// The Started ticket's line: "Step 1 of 3 confirmed · about 10 min".
String startedLine(Activation activation) =>
    '${confirmedLine(activation)} · about ${activation.minutes} min';

/// "Step 1 of 3 confirmed".
String confirmedLine(Activation activation) =>
    'Step ${activation.confirmed} of ${activation.steps.length} confirmed';

/// My activations: "Kudi Box · step 1 of 3 confirmed".
String myActivationsLine(Activation activation) =>
    '${activation.business} · step ${activation.confirmed} of '
    '${activation.steps.length} confirmed';

/// Started activations show as Started; the rest by their spots and time:
/// Full, Closed, Hero when closing within a day, List otherwise.
IqActivationTicketKind ticketKind(Activation activation, DateTime now) {
  if (activation.started) return IqActivationTicketKind.started;
  if (activation.full) return IqActivationTicketKind.full;
  if (activation.closedAt(now)) return IqActivationTicketKind.closed;
  return activationLeft(activation, now) < ActivationRules.closingSoon
      ? IqActivationTicketKind.hero
      : IqActivationTicketKind.list;
}
