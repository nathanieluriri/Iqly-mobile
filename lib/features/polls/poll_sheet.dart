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
import '../../ui/button.dart';
import '../../ui/poll_card.dart';
import '../../ui/skeleton.dart';
import '../../ui/step_mark.dart';
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
    final done = pollsDone(business, ref.watch(pollsWalkingProvider));

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
                  bottomInset: media.padding.bottom,
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
                    done: pollsDone(business, ref.watch(pollsWalkingProvider)),
                    layout: IqBrandHeaderLayout.leading,
                    padding: EdgeInsets.only(
                      bottom: IqSpace.s6 + MediaQuery.paddingOf(context).bottom,
                    ),
                    bottomInset: MediaQuery.paddingOf(context).bottom,
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

/// Whether the sheet says "You’re done": every question answered, and a
/// walk through the questions ended with Done.
bool pollsDone(PollBusiness? business, Set<String> walking) =>
    business != null && business.allAnswered && !walking.contains(business.id);

class _Polls extends ConsumerStatefulWidget {
  const _Polls({
    required this.business,
    required this.done,
    required this.layout,
    required this.padding,
    required this.bottomInset,
  });

  final PollBusiness? business;
  final bool done;
  final IqBrandHeaderLayout layout;
  final EdgeInsets padding;
  final double bottomInset;

  @override
  ConsumerState<_Polls> createState() => _PollsState();
}

class _PollsState extends ConsumerState<_Polls> {
  final _picks = <String, int>{};
  String? _failed;
  bool _looked = false;

  /// The question on screen while the polls are walked one at a time.
  ({String poll, int question})? _at;

  static String _key(Poll poll, int question) => '${poll.id}#$question';

  Future<void> _vote(Poll poll, int choice, {int question = 0}) async {
    if (_picks.isNotEmpty) return;
    final key = _key(poll, question);
    final business = widget.business;
    if (business != null && business.stepped) {
      ref.read(pollsWalkingProvider.notifier).walk(business.id);
    }
    setState(() => _picks[key] = choice);
    final outcome = await ref
        .read(pollsProvider.notifier)
        .vote(poll.id, choice, question: question);
    if (!mounted) return;
    setState(() {
      _picks.remove(key);
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
    if (business.stepped && !widget.done) {
      return _stepper(business, now, inset);
    }
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
          for (final (i, card) in [
            for (final poll in business.polls)
              for (var q = 0; q < poll.questions.length; q++)
                if (q == 0 || (poll.asks(q) && poll.questions[q].answered))
                  _card(poll, now, question: q),
          ].indexed) ...[
            if (i > 0) const SizedBox(height: IqSpace.s3),
            inset(card),
          ],
        ],
      ),
    );
  }

  Widget _card(Poll poll, DateTime now, {int question = 0}) {
    final asked = poll.questions[question];
    final closed = poll.closedAt(now);
    final shares = asked.shares;
    final voting = !asked.answered && !closed && _picks.isEmpty;
    return IqPollCard(
      key: ValueKey(_key(poll, question)),
      question: asked.question,
      state: asked.answered
          ? IqPollCardState.voted
          : closed
          ? IqPollCardState.closed
          : IqPollCardState.open,
      options: [
        for (final (i, choice) in asked.choices.indexed)
          IqPollCardOption(choice, shares[i] / 100),
      ],
      votes: asked.total,
      timeLeft: closed
          ? ''
          : 'Closes in ${pollTimeLeft(timeLeft(poll.closesAt, now)!)}',
      chosen: asked.chosen ?? 0,
      selected: _picks[_key(poll, question)],
      hint: 'Pick one',
      onVote: voting
          ? (choice) => _vote(poll, choice, question: question)
          : null,
    );
  }

  /// B2 · Polls · 3 questions (1600:33055 to 1600:33991): one question at a
  /// time under the business, which question it is and the step mark over
  /// it, and why a branched question is asked. Next question waits for the
  /// vote; Back returns to the question before (a skipped one is passed
  /// over, and counts as done on the mark); the last question's Done shows
  /// every result (1600:34175).
  Widget _stepper(
    PollBusiness business,
    DateTime now,
    Widget Function(Widget) inset,
  ) {
    final steps = [
      for (final poll in business.polls)
        for (var q = 0; q < poll.questions.length; q++) (poll: poll, q: q),
    ];
    bool skipped(int i) => steps[i].poll.skips(steps[i].q);
    bool open(int i) =>
        !steps[i].poll.questions[steps[i].q].answered && !skipped(i);
    var at = _at == null
        ? -1
        : steps.indexWhere(
            (s) => s.poll.id == _at!.poll && s.q == _at!.question,
          );
    if (at < 0) {
      at =
          [for (var i = 0; i < steps.length; i++) i].where(open).firstOrNull ??
          0;
      // The walk holds this question until Next or Back moves it, so a
      // vote shows its results here first.
      _at = (poll: steps[at].poll.id, question: steps[at].q);
    }
    final step = steps[at];
    final asked = step.poll.questions[step.q];
    int? find(Iterable<int> order) =>
        order.where((i) => !skipped(i)).firstOrNull;
    final next = find([for (var i = at + 1; i < steps.length; i++) i]);
    final back = find([for (var i = at - 1; i >= 0; i--) i]);
    final branch = asked.showIf;
    final picked = branch == null
        ? null
        : step.poll.questions[branch.question].chosen;
    final because = branch == null || picked == null
        ? null
        : 'Because you picked '
              '${step.poll.questions[branch.question].choices[picked]}';
    void go(int i) =>
        setState(() => _at = (poll: steps[i].poll.id, question: steps[i].q));
    final leading = widget.layout == IqBrandHeaderLayout.leading;
    final ready = asked.answered || step.poll.closedAt(now);
    final nextButton = IqButton(
      label: next == null ? 'Done' : 'Next question',
      showIcon: false,
      width: double.infinity,
      disabled: !ready,
      onTap: () => next == null
          ? ref.read(pollsWalkingProvider.notifier).finish(business.id)
          : go(next),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              widget.padding.left,
              widget.padding.top,
              widget.padding.right,
              IqSpace.s2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                inset(_FailedVote(title: _failed)),
                IqBrandHeader(
                  layout: widget.layout,
                  brand: business.name,
                  detail: pollDetail(business),
                  cover: businessCover(business.banner),
                  logo: businessLogo(business.logo),
                ),
                SizedBox(height: leading ? IqSpace.s4 : IqSpace.s3),
                inset(
                  Text(
                    pollStepLabel(
                      at: at,
                      count: steps.length,
                      last: next == null,
                      skipped: [for (var i = 0; i < at; i++) i].any(skipped),
                    ),
                    style: IqText.label.copyWith(color: IqColors.fg2),
                  ),
                ),
                const SizedBox(height: IqSpace.s2),
                inset(IqStepMark(step: IqStepMarkStep.at(at, steps.length))),
                if (because != null) ...[
                  const SizedBox(height: IqSpace.s3),
                  inset(
                    Text(
                      because,
                      style: IqText.small.copyWith(color: IqColors.fg2),
                    ),
                  ),
                ],
                const SizedBox(height: IqSpace.s3),
                inset(_card(step.poll, now, question: step.q)),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            IqSpace.s4,
            IqSpace.s2,
            IqSpace.s4,
            IqSpace.s2 + widget.bottomInset,
          ),
          child: back == null
              ? nextButton
              : Row(
                  children: [
                    Expanded(
                      child: IqButton(
                        label: 'Back',
                        kind: IqButtonKind.secondary,
                        showIcon: false,
                        width: double.infinity,
                        onTap: () => go(back),
                      ),
                    ),
                    const SizedBox(width: IqSpace.s3),
                    Expanded(child: nextButton),
                  ],
                ),
        ),
      ],
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
