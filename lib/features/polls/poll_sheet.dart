import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/deadline.dart';
import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../data/polls_data.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/poll_card.dart';
import '../../ui/skeleton.dart';
import '../../ui/top_bar.dart';
import 'polls_state.dart';

/// B2 · Polls · Orchid Foods · open (33:169) and voted (33:289): one
/// business's polls in a sheet on paper (Color/bg, radius 28) over the
/// Polls page, behind Flags.polls. A pick shows at once (Exp/PollOption
/// Selected, the select haptic) while the vote goes in; then the card
/// reveals its results and the eyebrow rolls to "1 of 2 answered". A vote
/// that does not go in clears the pick, with the error haptic and banner.
///
/// The sheet rises and drops per MOTION-SPEC §3.3 (Figma opens it Instant
/// and closes it with Smart Animate 0.3 s); there is no stagger inside.
class PollSheet extends ConsumerStatefulWidget {
  const PollSheet({super.key, required this.businessId});

  final String businessId;

  /// Figma's sheet tops out 26 under the status bar.
  static const double topGap = 26;

  @override
  ConsumerState<PollSheet> createState() => _PollSheetState();
}

class _PollSheetState extends ConsumerState<PollSheet> {
  final _picks = <String, int>{};
  bool _failed = false;

  Future<void> _vote(Poll poll, int choice) async {
    if (_picks.isNotEmpty) return;
    setState(() => _picks[poll.id] = choice);
    final counted = await ref
        .read(pollsProvider.notifier)
        .vote(poll.id, choice);
    if (!mounted) return;
    setState(() {
      _picks.remove(poll.id);
      _failed = !counted;
    });
    if (!counted) errorHaptic();
  }

  @override
  Widget build(BuildContext context) {
    final business = ref
        .watch(pollsProvider)
        .value
        ?.where((b) => b.id == widget.businessId)
        .firstOrNull;
    final now = ref.watch(clockProvider)();
    final media = MediaQuery.of(context);

    return CenteredContent(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: media.size.height - media.padding.top - PollSheet.topGap,
        ),
        child: Material(
          color: IqColors.bg,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IqTopBar(
                variant: IqTopBarVariant.sheet,
                title: business?.name ?? ' ',
                onClose: () => context.pop(),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    IqSpace.s4,
                    0,
                    IqSpace.s4,
                    IqSpace.s3 + IqSpace.s2 + media.padding.bottom,
                  ),
                  child: business == null
                      ? const IqSkeleton()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _FailedVote(shown: _failed),
                            RollingText(
                              sheetEyebrow(business).toUpperCase(),
                              style: IqText.mono.copyWith(color: IqColors.fg3),
                            ),
                            for (final poll in business.polls) ...[
                              const SizedBox(height: IqSpace.s3),
                              _card(poll, now),
                            ],
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(Poll poll, DateTime now) {
    final closed = poll.closedAt(now);
    final shares = poll.shares;
    final voting = !poll.voted && !closed && _picks.isEmpty;
    return IqPollCard(
      key: ValueKey(poll.id),
      question: poll.question,
      state: poll.voted
          ? IqPollCardState.voted
          : closed
          ? IqPollCardState.closed
          : IqPollCardState.open,
      options: [
        for (final (i, choice) in poll.choices.indexed)
          IqPollCardOption(choice, shares[i] / 100),
      ],
      votes: poll.total,
      timeLeft: closed
          ? ''
          : '${pollTimeLeft(timeLeft(poll.closesAt, now)!)} left',
      chosen: poll.chosen ?? 0,
      selected: _picks[poll.id],
      hint: 'Pick one',
      onVote: voting ? (choice) => _vote(poll, choice) : null,
    );
  }
}

/// The error banner over the polls when a vote did not go in. It opens its
/// slot as it slides down (240 ms) and closes it again (180 ms) once a vote
/// counts; under reduced motion it fades and the polls move in one step.
class _FailedVote extends StatelessWidget {
  const _FailedVote({required this.shown});

  final bool shown;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: motion(context, IqDurations.mark, fade: true),
      reverseDuration: motion(context, IqDurations.ink, fade: true),
      switchInCurve: IqCurves.easeOut,
      switchOutCurve: IqCurves.easeOut,
      transitionBuilder: (child, animation) => reduced
          ? FadeTransition(opacity: animation, child: child)
          : SizeTransition(
              sizeFactor: animation,
              alignment: Alignment.topCenter,
              child: FadeTransition(opacity: animation, child: child),
            ),
      child: shown
          ? const Padding(
              key: ValueKey(true),
              padding: EdgeInsets.only(bottom: IqSpace.s3),
              child: IqBanner(
                kind: IqBannerKind.error,
                title: 'Couldn’t send. Check your connection.',
                showAction: false,
              ),
            )
          : const SizedBox(key: ValueKey(false), width: double.infinity),
    );
  }
}
