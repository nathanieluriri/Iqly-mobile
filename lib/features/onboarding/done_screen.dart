import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/deadline.dart';
import '../../core/money.dart';
import '../../core/session.dart';
import '../../data/models.dart';
import '../../data/onboarding_service.dart';
import '../../data/repository.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/illustration.dart';
import '../../ui/section_title.dart';
import '../../ui/brief_card.dart';
import '../../ui/meta.dart';
import '../../ui/sample_cover.dart';
import '../../ui/sample_logo.dart';
import 'onboarding_draft.dart';
import 'onboarding_layout.dart';

/// The first two live briefs, soonest close first.
final startHereBriefsProvider = FutureProvider<List<Brief>>((ref) async {
  final briefs = await ref.watch(repositoryProvider).briefs();
  final live =
      briefs
          .where(
            (b) =>
                b.status == BriefStatus.live &&
                b.deadline != null &&
                b.businessName != null,
          )
          .toList()
        ..sort((a, b) => a.deadline!.compareTo(b.deadline!));
  return live.take(2).toList();
});

/// B11 · Done (188:8490). Reaching it finishes first run: the answers go to
/// the profile and the session stops offering the setup nudge. The Cheer
/// figure is clipped to the frame's 171 pt hero; the two soonest-closing
/// briefs scroll under "Go to Discover", which asks for notifications next.
///
/// Motion (MOTION-SPEC 5.32): the figure rises in at 0; title +120, "Start
/// here" +200, the two cards arrive at +240 and +280 (or 40 apart when they
/// land later); the button comes with the page. The success haptic plays as
/// the last step hands off.
class DoneScreen extends ConsumerStatefulWidget {
  const DoneScreen({super.key});

  @override
  ConsumerState<DoneScreen> createState() => _DoneScreenState();
}

class _DoneScreenState extends ConsumerState<DoneScreen> {
  /// Runs until the cards' beat: briefs that land before it ride the
  /// entrance, later ones arrive as they land.
  final _cardsDue = Timer(IqMomentTiming.ticketsAt, () {});
  bool? _onTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
  }

  @override
  void dispose() {
    _cardsDue.cancel();
    super.dispose();
  }

  Future<void> _finish() async {
    if (!mounted) return;
    final profile = ref.read(onboardingDraftProvider).profile;
    final session = ref.read(sessionProvider.notifier);
    await ref.read(onboardingServiceProvider).saveProfile(profile);
    await session.setOnboardingDone(true);
  }

  @override
  Widget build(BuildContext context) {
    final firstName = ref.watch(greetingNameProvider);
    final briefs = ref.watch(startHereBriefsProvider).value ?? const [];
    final now = ref.watch(clockProvider)();
    if (briefs.isNotEmpty) _onTime ??= _cardsDue.isActive;
    final onTime = _onTime ?? true;
    return OnboardingHeroScaffold(
      figure: IqFigures.cheer,
      heroHeight: 171,
      figureTop: 0,
      titleGap: IqSpace.s3,
      entrance:
          IqMomentTiming.ticketsAt +
          IqDurations.stagger +
          BeatMove.arrive.length,
      title: firstName == null ? 'Nice one' : 'Nice one, $firstName',
      content: [
        const SizedBox(height: IqSpace.s3),
        const Beat(
          at: IqMomentTiming.rowsAt,
          child: IqSectionTitle(
            title: 'Start here',
            showCount: false,
            showLink: false,
          ),
        ),
        const SizedBox(height: IqSpace.s3),
        if (onTime)
          for (final (i, brief) in briefs.indexed) ...[
            if (i > 0) const SizedBox(height: IqSpace.s3),
            Beat(
              at: IqMomentTiming.ticketsAt + IqDurations.stagger * i,
              move: BeatMove.arrive,
              child: _card(brief, now),
            ),
          ]
        else
          Stagger(
            play: briefs.isNotEmpty,
            child: Column(
              children: [
                for (final (i, brief) in briefs.indexed) ...[
                  if (i > 0) const SizedBox(height: IqSpace.s3),
                  StaggerItem(index: i, child: _card(brief, now)),
                ],
              ],
            ),
          ),
      ],
      primary: 'Go to Discover',
      onPrimary: () => context.push(Routes.notificationsAsk),
    );
  }

  Widget _card(Brief brief, DateTime now) {
    final left = timeLeft(brief.deadline, now);
    final sample = sampleBrandOf(brief.businessName);
    return IqBriefCard(
      kind: IqBriefCardKind.feature,
      brand: brief.businessName ?? 'Private business',
      title: brief.title,
      cover: IqSampleCover(sample),
      logo: IqSampleLogo(sample),
      meta: [
        IqMeta(
          kind: IqMetaKind.reward,
          label: rewardPool(brief.rewardPoolKobo),
        ),
        IqMeta(
          kind: left != null && left <= DeadlineRules.closingSoon
              ? IqMetaKind.urgent
              : IqMetaKind.deadline,
          label: closesIn(left),
        ),
      ],
      onTap: () => context.push(Routes.brief(brief.id)),
    );
  }
}

/// The sample logo and cover set drawn for a business, the anonymous art
/// when it has none.
IqSampleLogoBrand sampleBrandOf(String? businessName) =>
    IqSampleLogoBrand.values
        .where((b) => b.label == businessName)
        .firstOrNull ??
    IqSampleLogoBrand.private;
