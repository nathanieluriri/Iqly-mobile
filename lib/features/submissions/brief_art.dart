import 'package:flutter/widgets.dart';

import '../../core/deadline.dart';
import '../../core/relative_time.dart';
import '../../data/models.dart';
import '../../ui/meta.dart';
import '../../ui/sample_cover.dart';
import '../../ui/sample_logo.dart';
import '../discover/business_art.dart';

/// The sample art and response time of the demo briefs, as the B4 and B13
/// frames draw them. Any other brief (a live one) draws its own.
const _art = <String, (IqSampleLogoBrand, int, int)>{
  'c1': (IqSampleLogoBrand.orchidFoods, 2, 3),
  'c2': (IqSampleLogoBrand.basketNg, 1, 5),
  'c3': (IqSampleLogoBrand.private, 1, 4),
  'c4': (IqSampleLogoBrand.kudiBox, 1, 10),
  'c5': (IqSampleLogoBrand.sunline, 1, 2),
  'c6': (IqSampleLogoBrand.unibooks, 1, 5),
  'c7': (IqSampleLogoBrand.harbour, 1, 8),
  'c8': (IqSampleLogoBrand.voltRiders, 1, 3),
  'c9': (IqSampleLogoBrand.swapit, 1, 5),
  'c10': (IqSampleLogoBrand.garriAndCo, 1, 5),
  'c11': (IqSampleLogoBrand.lagoonLines, 1, 6),
  'c12': (IqSampleLogoBrand.harbour, 2, 3),
  'c13': (IqSampleLogoBrand.classpay, 2, 10),
};

IqSampleLogoBrand _brand(Brief? brief) =>
    _art[brief?.id]?.$1 ?? IqSampleLogoBrand.private;

bool _sample(Brief? brief) => brief == null || _art.containsKey(brief.id);

Widget briefLogo(Brief? brief, {double size = 120}) => _sample(brief)
    ? IqSampleLogo(_brand(brief), size: size)
    : businessLogo(brief!.logo, size: size);

Widget briefCover(Brief? brief) => _sample(brief)
    ? IqSampleCover(_brand(brief), shot: _art[brief?.id]?.$2 ?? 1)
    : businessCover(brief!.cover);

int? briefMinutes(Brief brief) =>
    _sample(brief) ? _art[brief.id]?.$3 : brief.minutes;

/// "₦150k", "₦12.5k", "₦62.5k": a prize or pool on a chip or the podium,
/// never with kobo.
String nairaShort(int kobo) {
  final naira = kobo ~/ 100;
  if (naira < 1000) return '₦$naira';
  final thousands = naira / 1000;
  final digits = thousands == thousands.roundToDouble()
      ? thousands.toStringAsFixed(0)
      : thousands.toStringAsFixed(1);
  return '₦${digits}k';
}

/// The Brief's chips on a Row card (324:14520): the pool and the plain
/// deadline.
List<Widget> rowBriefMeta(Brief brief, DateTime now) => [
  IqMeta(kind: IqMetaKind.reward, label: nairaShort(brief.rewardPoolKobo)),
  IqMeta(
    kind: IqMetaKind.deadline,
    label: closesIn(timeLeft(brief.deadline, now), closed: !brief.isLive),
  ),
];

/// The chips on a Feature card (193:9681): the pool, the time it takes and
/// the deadline, Urgent within three days.
List<Widget> featureBriefMeta(Brief brief, DateTime now) {
  final left = timeLeft(brief.deadline, now);
  final closed = !brief.isLive;
  final minutes = briefMinutes(brief);
  return [
    IqMeta(kind: IqMetaKind.reward, label: nairaShort(brief.rewardPoolKobo)),
    if (minutes != null) IqMeta(kind: IqMetaKind.time, label: '$minutes min'),
    IqMeta(
      kind: !closed && left != null && left <= DeadlineRules.closingSoon
          ? IqMetaKind.urgent
          : IqMetaKind.deadline,
      label: closesIn(left, closed: closed),
    ),
  ];
}

/// Under two days a Feature card wears the closing-soon tint and outline.
bool closingSoonOutline(Brief brief, DateTime now) {
  final left = timeLeft(brief.deadline, now);
  return brief.isLive &&
      left != null &&
      left < DeadlineRules.closingSoonOutline;
}

/// "Sent 1 day ago", "Sent just now".
String sentAgo(DateTime at, DateTime now) {
  final ago = timeAgo(at, now);
  return 'Sent ${ago == 'Just now' ? 'just now' : ago}';
}
