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

Duration activationLeft(Activation activation, DateTime now) =>
    timeLeft(activation.closesAt, now)!;

/// "Closes in 2 days", or "Ended 2 days ago" once closed.
String deadlineText(Activation activation, DateTime now) =>
    activation.closedAt(now)
    ? 'Ended ${timeAgo(activation.closesAt, now)}'
    : 'Closes in ${countdownText(activationLeft(activation, now))}';

/// Closing within a day: the deadline sits on the Urgent pill.
bool closingSoon(Activation activation, DateTime now) =>
    !activation.closedAt(now) &&
    activationLeft(activation, now) < ActivationRules.closingSoon;

/// The ProgressThread count once a step is past its window: "1 day waiting".
String waitingCount(Activation activation, DateTime now) {
  final since = activation.waitingSince ?? now;
  return '${_count(now.difference(since).inDays, 'day')} waiting';
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

/// "5 min".
String minutesText(Activation activation) => '${activation.minutes} min';

/// The ProgressThread status: "Not started · 3 steps" until the business
/// confirms one, then "Step 1 of 3 confirmed".
String progressLine(Activation activation) => activation.confirmed == 0
    ? 'Not started · ${_count(activation.steps.length, 'step')}'
    : 'Step ${activation.confirmed} of ${activation.steps.length} confirmed';

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
