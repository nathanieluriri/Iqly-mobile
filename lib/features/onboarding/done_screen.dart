import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../../ui/urgency.dart';
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

/// Time left to the minute, so a brief created "1 day" out still reads as a
/// day a few seconds later.
Duration? timeLeft(DateTime? deadline, DateTime now) {
  if (deadline == null) return null;
  return Duration(minutes: (deadline.difference(now).inSeconds / 60).round());
}

/// "Closes in 6h", "Closes in 1 day", as the mobile tickets word it.
String closesIn(Duration? left) {
  if (left == null) return 'No deadline';
  final hours = (left.inMinutes / 60).round();
  if (hours < 24) return 'Closes in ${hours < 1 ? 1 : hours}h';
  final days = (hours / 24).round();
  return 'Closes in $days ${days == 1 ? 'day' : 'days'}';
}

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
    final spots = brief.spotsLeft;
    return Center(
      child: IqTicketCard(
        kind: IqTicketCardKind.list,
        title: brief.title,
        meta: '${brief.businessName} · ${brief.tier.label}',
        initial: brief.businessName!.substring(0, 1),
        reward: rewardPool(brief.rewardPoolKobo),
        showRule: false,
        spots: spots == null ? null : '$spots spots left',
        urgency: closesIn(left),
        urgencyTone: IqUrgencyTone.of(left),
      ),
    );
  }
}
