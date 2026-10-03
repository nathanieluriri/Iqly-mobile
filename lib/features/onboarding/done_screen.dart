import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/brief_labels.dart';
import '../../core/motion.dart';
import '../../core/deadline.dart';
import '../../core/money.dart';
import '../../core/session.dart';
import '../../data/models.dart';
import '../../data/onboarding_service.dart';
import '../../data/repository.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/illustration.dart';
import '../../ui/section_title.dart';
import '../../ui/ticket_card.dart';
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
/// the profile and the session stops offering the setup nudge.
///
/// The Rocket's layer is 150 x 120 at (120, 78), but its vectors do not
/// scale with the instance, so Figma draws the art at its own 200 x 160 from
/// that corner; the screen draws it the same way.
///
/// Motion (MOTION-SPEC 5.32): the Rocket rises in at 0, its flame lights
/// at +200 and flickers twice, and it lifts 4 and settles at +320; eyebrow
/// +80, title +120, "Start here" +200, the two tickets arrive at +240 and
/// +280 (or 40 apart when they land later); Continue comes with the page.
/// The success haptic plays as the last step hands off.
class DoneScreen extends ConsumerStatefulWidget {
  const DoneScreen({super.key});

  @override
  ConsumerState<DoneScreen> createState() => _DoneScreenState();
}

class _DoneScreenState extends ConsumerState<DoneScreen> {
  /// Runs until the tickets' beat: briefs that land before it ride the
  /// entrance, later ones arrive as they land.
  final _ticketsDue = Timer(IqMomentTiming.ticketsAt, () {});
  bool? _onTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
  }

  @override
  void dispose() {
    _ticketsDue.cancel();
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
    if (briefs.isNotEmpty) _onTime ??= _ticketsDue.isActive;
    final onTime = _onTime ?? true;
    return OnboardingHeroScaffold(
      gap: IqSpace.s3,
      entrance:
          IqMomentTiming.ticketsAt +
          IqDurations.stagger +
          BeatMove.arrive.length,
      hero: SizedBox(
        height: 171,
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 150,
            height: 120,
            child: OverflowBox(
              alignment: Alignment.topLeft,
              maxWidth: IqIllustration.designWidth,
              maxHeight: IqIllustration.designHeight,
              child: IqIllustration(
                IqIllustrations.rocket,
                entrance: heroEntrance(context),
              ),
            ),
          ),
        ),
      ),
      eyebrow: 'You’re set',
      title: firstName == null ? 'Nice one' : 'Nice one, $firstName',
      content: [
        const Beat(
          at: IqMomentTiming.rowsAt,
          child: IqSectionTitle(
            title: 'Start here',
            showCount: false,
            showLink: false,
          ),
        ),
        if (onTime)
          for (final (i, brief) in briefs.indexed)
            Beat(
              at: IqMomentTiming.ticketsAt + IqDurations.stagger * i,
              move: BeatMove.arrive,
              child: _ticket(brief, now),
            )
        else
          Stagger(
            play: briefs.isNotEmpty,
            child: Column(
              children: [
                for (final (i, brief) in briefs.indexed) ...[
                  if (i > 0) const SizedBox(height: IqSpace.s3),
                  StaggerItem(index: i, child: _ticket(brief, now)),
                ],
              ],
            ),
          ),
      ],
      actions: [
        IqButton(
          label: 'Continue',
          showIcon: false,
          width: double.infinity,
          onTap: () => context.go(Routes.notificationsAsk),
        ),
      ],
    );
  }

  Widget _ticket(Brief brief, DateTime now) {
    final left = timeLeft(brief.deadline, now);
    return Center(
      child: IqTicketCard(
        kind: IqTicketCardKind.list,
        title: brief.title,
        meta: '${brief.businessName} · ${brief.tier.label}',
        initial: brief.businessName!.substring(0, 1),
        reward: rewardPool(brief.rewardPoolKobo),
        showRule: false,
        spots: spotsLeftLabel(brief),
        showSpotsMarker: brief.spotsLeft != null,
        urgency: closesIn(left),
        urgencyTone: urgencyTone(left),
        onTap: () => context.push(Routes.brief(brief.id)),
      ),
    );
  }
}
