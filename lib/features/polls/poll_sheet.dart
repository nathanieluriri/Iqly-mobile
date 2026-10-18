import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/deadline.dart';
import '../../core/flags.dart';
import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../core/transitions.dart';
import '../../data/polls_data.dart';
import '../../theme/theme.dart';

import 'package:flutter/services.dart';

import '../../ui/banner.dart';
import '../../ui/brand_header.dart';
import '../../ui/poll_card.dart';
import '../../ui/skeleton.dart';
import '../../ui/top_bar.dart';
import '../discover/business_art.dart';
import '../discover/discover_routes.dart';
import '../settings/restore_account_screen.dart' show showClosingAccount;
import 'polls_state.dart';

/// B2 · Polls · Orchid Foods · open (33:169), voted (33:289) and done
/// (480:22679): one business's polls in a sheet on paper (radius 28) over
/// the Quick polls page, behind Flags.polls, its top 52 under the status
/// bar. Exp/BrandHeader (Centered) says how long the polls take; once every
/// question is answered the title turns to "You’re done" and the header
/// says the answers went in. A pick shows at once while the vote goes in;
/// a vote that does not go in clears the pick, with the error haptic and
/// banner. Dragging the sheet up opens the same polls as a page (345:15957).
class PollSheet extends ConsumerWidget {
  const PollSheet({super.key, required this.businessId});

  final String businessId;

  /// Figma's sheet tops out 52 under the status bar.
  static const double topGap = 52;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final business = ref
        .watch(pollsProvider)
        .value
        ?.where((b) => b.id == businessId)
        .firstOrNull;
    final media = MediaQuery.of(context);
    final done = business != null && business.allAnswered;

    final lift = IqSheetRoute.liftOf(context);
    return CenteredContent(
      child: SizedBox(
        height: media.size.height - media.padding.top - topGap,
        child: AnimatedBuilder(
          animation: lift,
          builder: (context, child) => Material(
            color: IqColors.bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(28 * (1 - lift.value)),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IqTopBar(
                variant: IqTopBarVariant.sheet,
                title: done ? 'You’re done' : 'Quick polls',
                onClose: () => context.pop(),
              ),
              Expanded(
                child: _Polls(
                  business: business,
                  done: done,
                  layout: IqBrandHeaderLayout.centered,
                  padding: EdgeInsets.fromLTRB(
                    IqSpace.s4,
                    0,
                    IqSpace.s4,
                    IqSpace.s3 + IqSpace.s2 + media.padding.bottom,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// B2 · Polls · Orchid Foods · full screen (345:15957): the poll sheet as a
/// sub page (Page top bar, Back, no dock), with Exp/BrandHeader Leading
/// across the full width.
class PollPage extends ConsumerWidget {
  const PollPage({super.key, required this.businessId});

  final String businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final business = ref
        .watch(pollsProvider)
        .value
        ?.where((b) => b.id == businessId)
        .firstOrNull;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: IqColors.bg,
        body: SafeArea(
          bottom: false,
          child: CenteredContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IqTopBar(
                  variant: IqTopBarVariant.page,
                  title: 'Quick polls',
                  onBack: () => leave(context),
                ),
                Expanded(
                  child: _Polls(
                    business: business,
                    done: business != null && business.allAnswered,
                    layout: IqBrandHeaderLayout.leading,
                    padding: EdgeInsets.only(
                      bottom: IqSpace.s6 + MediaQuery.paddingOf(context).bottom,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Polls extends ConsumerStatefulWidget {
  const _Polls({
    required this.business,
    required this.done,
    required this.layout,
    required this.padding,
  });

  final PollBusiness? business;
  final bool done;
  final IqBrandHeaderLayout layout;
  final EdgeInsets padding;

  @override
  ConsumerState<_Polls> createState() => _PollsState();
}

class _PollsState extends ConsumerState<_Polls> {
  final _picks = <String, int>{};
  String? _failed;
  bool _looked = false;

  Future<void> _vote(Poll poll, int choice) async {
    if (_picks.isNotEmpty) return;
    setState(() => _picks[poll.id] = choice);
    final outcome = await ref
        .read(pollsProvider.notifier)
        .vote(poll.id, choice);
    if (!mounted) return;
    setState(() {
      _picks.remove(poll.id);
      _failed = switch (outcome) {
        VoteOutcome.counted => null,
        VoteOutcome.offline => 'Couldn’t send. Check your connection.',
        VoteOutcome.closing when Flags.deleteAccount => null,
        VoteOutcome.refused || VoteOutcome.closing => 'Couldn’t send.',
      };
    });
    if (outcome == VoteOutcome.counted) return;
    errorHaptic();
    if (outcome == VoteOutcome.closing && Flags.deleteAccount) {
      await showClosingAccount(context, ref);
    }
  }

  /// A sheet opened for a business the list has not got yet (a push for a
  /// poll that came after the list loaded) reads the list again, once.
  void _lookFor() {
    if (_looked || !ref.read(pollsProvider).hasValue) return;
    _looked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(pollsProvider.notifier).refreshQuietly();
    });
  }

  @override
  Widget build(BuildContext context) {
    final business = widget.business;
    final now = ref.watch(clockProvider)();
    final leading = widget.layout == IqBrandHeaderLayout.leading;
    if (business == null) {
      _lookFor();
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: IqSpace.s4),
        child: Align(alignment: Alignment.topCenter, child: IqSkeleton()),
      );
    }
    Widget inset(Widget child) => leading
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
            child: child,
          )
        : child;
    return SingleChildScrollView(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          inset(_FailedVote(title: _failed)),
          IqBrandHeader(
            layout: widget.layout,
            brand: business.name,
            detail: widget.done
                ? pollDoneDetail(business)
                : pollDetail(business),
            cover: businessCover(business.banner),
            logo: businessLogo(business.logo),
          ),
          SizedBox(height: leading ? IqSpace.s4 : IqSpace.s3),
          for (final (i, poll) in business.polls.indexed) ...[
            if (i > 0) const SizedBox(height: IqSpace.s3),
            inset(_card(poll, now)),
          ],
        ],
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
          : 'Closes in ${pollTimeLeft(timeLeft(poll.closesAt, now)!)}',
      chosen: poll.chosen ?? 0,
      selected: _picks[poll.id],
      hint: 'Pick one',
      onVote: voting ? (choice) => _vote(poll, choice) : null,
    );
  }
}

/// The error banner over the polls when a vote did not go in: no answer
/// from the API, or a refusal ([title] keeps the first sentence then, as
/// the withdraw sheet does). It opens its slot as it slides down (240 ms)
/// and closes it again (180 ms) once a vote counts; under reduced motion it
/// fades and the polls move in one step.
class _FailedVote extends StatelessWidget {
  const _FailedVote({required this.title});

  final String? title;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final title = this.title;
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
      child: title != null
          ? Padding(
              key: ValueKey(title),
              padding: const EdgeInsets.only(bottom: IqSpace.s3),
              child: IqBanner(
                kind: IqBannerKind.error,
                title: title,
                showAction: false,
              ),
            )
          : const SizedBox(key: ValueKey(false), width: double.infinity),
    );
  }
}
