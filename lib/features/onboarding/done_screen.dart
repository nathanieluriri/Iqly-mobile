import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/brief_labels.dart';
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
class DoneScreen extends ConsumerStatefulWidget {
  const DoneScreen({super.key});

  @override
  ConsumerState<DoneScreen> createState() => _DoneScreenState();
}

class _DoneScreenState extends ConsumerState<DoneScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
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
    final now = DateTime.now();
    return OnboardingHeroScaffold(
      gap: IqSpace.s3,
      hero: const SizedBox(
        height: 171,
        child: Align(
          alignment: Alignment.topCenter,
          child: IqIllustration(IqIllustrations.rocket),
        ),
      ),
      eyebrow: 'You’re set',
      title: firstName == null ? 'Nice one' : 'Nice one, $firstName',
      content: [
        const IqSectionTitle(
          title: 'Start here',
          showCount: false,
          showLink: false,
        ),
        for (final brief in briefs) _ticket(brief, now),
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
