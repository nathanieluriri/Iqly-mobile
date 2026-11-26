import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../core/deadline.dart';
import '../../core/money.dart';
import '../../core/relative_time.dart';
import '../../data/activations_data.dart';
import '../../ui/sample_cover.dart';
import '../../ui/sample_logo.dart';
import '../discover/business_art.dart' as art;

/// The time left on a deadline chip: "5h 40m" under six hours, then whole
/// hours ("18h", "36h") and from two days whole days ("2 days"), each
/// rounded down so it never promises more time than is left.
String countdownText(Duration left) {
  if (left < DeadlineRules.countdownHot) {
    final minutes = left.inMinutes % Duration.minutesPerHour;
    if (left.inHours == 0) return '${minutes}m';
    return minutes == 0 ? '${left.inHours}h' : '${left.inHours}h ${minutes}m';
  }
  if (left < ActivationRules.countsHours) return '${left.inHours}h';
  return _count(left.inDays, 'day');
}

String _count(int n, String unit) => '$n ${n == 1 ? unit : '${unit}s'}';

Duration? activationLeft(Activation activation, DateTime now) =>
    timeLeft(activation.closesAt, now);

/// "2 days left", "Closes when full", or "Ended 2 days ago" once closed.
String deadlineText(Activation activation, DateTime now) {
  final closesAt = activation.closesAt;
  if (activation.closedAt(now)) {
    return closesAt == null ? 'Ended' : 'Ended ${timeAgo(closesAt, now)}';
  }
  if (closesAt == null) {
    return activation.full ? 'Full' : 'Closes when full';
  }
  return '${countdownText(activationLeft(activation, now)!)} left';
}

/// Closing within a day: the deadline sits on the Urgent pill.
bool closingSoon(Activation activation, DateTime now) {
  final left = activationLeft(activation, now);
  return left != null &&
      !activation.closedAt(now) &&
      left < ActivationRules.closingSoon;
}

/// "Thu, 1:52 pm", as the B8 and B9 timelines write a moment.
String dayTime(DateTime at) =>
    '${DateFormat('EEE').format(at)}, '
    '${DateFormat('h:mm a').format(at).toLowerCase()}';

/// "1:42".
String videoLength(Duration length) =>
    '${length.inMinutes}:'
    '${(length.inSeconds % Duration.secondsPerMinute).toString().padLeft(2, '0')}';

/// "18 MB".
String videoSize(int bytes) => bytes >= 1000000
    ? '${(bytes / 1000000).round()} MB'
    : '${(bytes / 1000).ceil()} KB';

/// "0:42 · 18 MB", or the size alone when the length is not known.
String videoFacts(ProofVideo video) {
  final length = video.length;
  final size = videoSize(video.bytes);
  return length == null ? size : '${videoLength(length)} · $size';
}

/// "₦1,500": rewards are promises, no decimals.
String reward(Activation activation) => rewardPool(activation.rewardKobo);

/// The reward chip: "₦500", "₦1.5k", "₦150k".
String rewardChip(Activation activation) {
  final naira = activation.rewardKobo ~/ 100;
  if (naira < 1000) return rewardPool(activation.rewardKobo);
  final thousands = naira / 1000;
  final digits = thousands == thousands.roundToDouble()
      ? thousands.toStringAsFixed(0)
      : thousands.toStringAsFixed(1);
  return '₦${digits}k';
}

/// The offer's reward (design profile, round 18): "Up to ₦1,000" when
/// several steps pay, else "₦1,500 per completion", as B8 now draws it.
String offerReward(Activation activation) => activation.showsStepRewards
    ? 'Up to ${reward(activation)}'
    : '${reward(activation)} per completion';

/// The reward on a list's card: the chip ("₦1.5k"), or the offer's "Up to
/// ₦1,500" once several steps pay, as the detail page words it.
String cardReward(Activation activation, String chip) =>
    activation.showsStepRewards ? offerReward(activation) : chip;

/// What a per-step run is holding: "₦50 waiting · finish to get paid".
/// Paid runs say "₦50 paid". Nothing confirmed yet asks them to finish.
String earnedLine(Activation activation, {DateTime? now}) {
  final paid =
      activation.progress?.stepPayouts.fold(0, (sum, p) => sum + p.kobo) ?? 0;
  if (activation.progress?.paidAt != null) {
    return '${rewardPool(paid)} paid';
  }
  final held = heldStepKobo(activation);
  if (held > 0) {
    return '${rewardPool(held)} waiting · finish to get paid';
  }
  return 'Finish every step to get paid';
}

/// Confirmed per-step rewards that have not reached the wallet yet.
int heldStepKobo(Activation activation) {
  if (!activation.perStep || activation.progress?.paidAt != null) return 0;
  final done = activation.confirmed;
  var held = 0;
  for (var i = 0; i < done && i < activation.steps.length; i++) {
    if (activation.payoutOf(i) != null) continue;
    held += activation.steps[i].rewardKobo ?? 0;
  }
  return held;
}

/// The offer's line on how a per-step activation pays, in the design
/// profile's rules for step rewards (round 18), whoever confirms the steps.
String perStepLine(Activation activation) {
  final by = activation.closesAt;
  final timing = by == null
      ? 'Each step is held until you finish every step. '
      : 'Each step is held until you finish every step by ${DateFormat('d MMM').format(by)}. ';
  return '${timing}Then it lands in your iQLY wallet.';
}

/// Whether step [i]'s row shows an amount: a paying step, once more than one
/// step pays (Round 18).
bool showsStepReward(Activation activation, int i) =>
    activation.showsStepRewards && (activation.steps[i].rewardKobo ?? 0) > 0;

/// Step [i]'s amount at the right of its row: "₦50", then "Paid ₦50" once
/// it was paid.
String stepRewardText(Activation activation, int i) {
  final payout = activation.payoutOf(i);
  if (payout != null) return 'Paid ${rewardPool(payout.kobo)}';
  if (i < activation.confirmed && activation.progress?.paidAt == null) {
    return 'Held ${rewardPool(activation.steps[i].rewardKobo ?? 0)}';
  }
  return rewardPool(activation.steps[i].rewardKobo ?? 0);
}

/// "5 min".
String minutesText(Activation activation) => '${activation.minutes} min';

/// The ProgressThread status: "Not started · 3 steps" until the business
/// confirms one ("No steps confirmed yet" when it pays step by step, or
/// holds a step it confirmed), then "Step 1 of 3 confirmed".
String progressLine(Activation activation) => activation.confirmed == 0
    ? activation.perStep || activation.holding
          ? 'No steps confirmed yet'
          : 'Not started · ${_count(activation.steps.length, 'step')}'
    : 'Step ${activation.confirmed} of ${activation.steps.length} confirmed';

/// Why no proof can go now, in words, or null when one can: a step the
/// business has reported waits out its hold; in postback mode, or without
/// a mode, a step first waits a day for the business.
String? proofHeldBack(Activation activation, DateTime now) {
  if (activation.holdsNextAt(now)) return heldLine(activation);
  if (activation.confirmationMode == ConfirmationMode.proof) return null;
  return switch (activation.phaseAt(now)) {
    ActivationPhase.started ||
    ActivationPhase.confirming => _notDue(activation),
    _ => null,
  };
}

/// A proof refused as not due (409 ACTIVATION_PROOF_NOT_DUE) in words, as
/// the API words it with the business named: held when it sends
/// `heldUntil`, else the rule of the activation's mode.
String proofNotDueText(Activation activation, Map<String, dynamic>? details) {
  if (details?['heldUntil'] != null) return heldLine(activation);
  return activation.confirmationMode == ConfirmationMode.proof
      ? 'Send proof of the next step, one step at a time.'
      : _notDue(activation);
}

/// The design profile's words for a step the business has reported and
/// holds, wherever it shows.
String heldLine(Activation activation) =>
    'Waiting for ${activation.business} to confirm.';

String _notDue(Activation activation) =>
    'Proof can be sent once a step has waited a day for '
    '${activation.business}.';

/// My activations: "Kudi Box · step 1 of 3 confirmed".
String myActivationsLine(Activation activation) =>
    '${activation.business} · step ${activation.confirmed} of '
    '${activation.steps.length} confirmed';

/// The activation the My activations row names: the one furthest along.
Activation? leadActivation(Iterable<Activation> activations) {
  Activation? lead;
  for (final a in activations) {
    if (!a.inFlight) continue;
    if (lead == null || a.confirmed > lead.confirmed) lead = a;
  }
  return lead;
}

/// The Sample/Cover the B8 frames give [business]: Orchid Foods wears
/// Basket NG's first shot, Unibooks its own second, the rest their first.
IqSampleCover activationCover(String business) =>
    switch (businessArt(business)) {
      IqSampleLogoBrand.orchidFoods => const IqSampleCover(
        IqSampleLogoBrand.basketNg,
      ),
      IqSampleLogoBrand.unibooks => const IqSampleCover(
        IqSampleLogoBrand.unibooks,
        shot: 2,
      ),
      final art => IqSampleCover(art),
    };

/// The activation's logo: the API's, or the anonymous mark without one; in
/// the preview the sample business's.
Widget activationLogoArt(Activation activation, {double size = 120}) =>
    activation.live
    ? art.businessLogo(activation.logoUrl, size: size)
    : IqSampleLogo(businessArt(activation.business), size: size);

/// The activation's photo, as [activationLogoArt] finds its logo.
Widget activationCoverArt(Activation activation) => activation.live
    ? art.businessCover(activation.imageUrl)
    : activationCover(activation.business);

/// The Sample/Logo of [business], for the demo businesses.
IqSampleLogoBrand businessArt(String business) =>
    IqSampleLogoBrand.values.firstWhere(
      (b) => b.label == business,
      orElse: () => IqSampleLogoBrand.private,
    );
