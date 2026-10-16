import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/deadline.dart';
import '../../core/money.dart';
import '../../core/navigation.dart';
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

/// The first two briefs open to everyone now (live, not closed, not full),
/// soonest close first.
final startHereBriefsProvider = FutureProvider<List<Brief>>((ref) async {
  final briefs = await ref.watch(repositoryProvider).briefs();
  final now = ref.read(clockProvider)();
  final open =
      briefs
          .where(
            (b) =>
                b.status == BriefStatus.live &&
                b.deadline != null &&
                b.deadline!.isAfter(now) &&
                b.spotsLeft != 0 &&
                b.businessName != null,
          )
          .toList()
        ..sort((a, b) => a.deadline!.compareTo(b.deadline!));
  return open.take(2).toList();
});

Future<void>? _finishing;

/// Ends first run (Finish or Skip for now on the last step, or the setup
/// nudge once every step is answered): the answers go to the profile, the
/// session stops offering the setup nudge, and the success haptic plays as
/// the step hands off. Done follows only while a brief is open to start
/// with (owner, 16 Oct); otherwise the notifications ask comes next.
Future<void> finishOnboarding(BuildContext context, WidgetRef ref) =>
    _finishing ??= _finish(context, ref).whenComplete(() => _finishing = null);

Future<void> _finish(BuildContext context, WidgetRef ref) async {
  final profile = ref.read(onboardingDraftProvider).profile;
  final session = ref.read(sessionProvider.notifier);
  ref
      .read(onboardingServiceProvider)
      .saveProfile(profile)
      .then((_) => session.setOnboardingDone(true))
      .ignore();
  var briefs = const <Brief>[];
  try {
    briefs = await ref
        .read(startHereBriefsProvider.future)
        .timeout(OnboardingService.briefsWait);
  } catch (_) {
    // No answer in time counts as nothing open: never hold the hand-off.
  }
  if (!context.mounted) return;
  IqHaptics.success.play();
  context.go(briefs.isEmpty ? Routes.notificationsAsk : Routes.onboardingDone);
}

/// B11 · Done (188:8490), shown after first run while a brief is open to
/// start with. The Cheer figure, at 75% of its first size, is clipped to a
/// 128 pt hero and its confetti falls past it; the two soonest-closing
/// briefs scroll under "Go to Discover", which asks for notifications next.
///
/// Motion (MOTION-SPEC 5.32): the figure rises in at 0; title +120, "Start
/// here" +200, the two cards arrive at +240 and +280 (or 40 apart when they
/// land later); the button comes with the page.
class DoneScreen extends ConsumerStatefulWidget {
  const DoneScreen({super.key});

  static const double heroHeight = 128;
  static const double figureWidth =
      OnboardingHeroScaffold.defaultFigureWidth * 0.75;

  @override
  ConsumerState<DoneScreen> createState() => _DoneScreenState();
}

class _DoneScreenState extends ConsumerState<DoneScreen> {
  /// Runs until the cards' beat: briefs that land before it ride the
  /// entrance, later ones arrive as they land.
  final _cardsDue = Timer(IqMomentTiming.ticketsAt, () {});
  bool? _onTime;

  @override
  void dispose() {
    _cardsDue.cancel();
    super.dispose();
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
      heroHeight: DoneScreen.heroHeight,
      figureWidth: DoneScreen.figureWidth,
      figureTop: 0,
      confettiFalls: true,
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
      onPrimary: () => context.open(Routes.notificationsAsk),
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
      onTap: () => context.open(Routes.brief(brief.id)),
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
