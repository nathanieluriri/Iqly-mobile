import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/flags.dart';
import '../../core/motion.dart';
import '../../core/navigation.dart';
import '../../core/responsive.dart';
import '../../core/session.dart';
import '../../core/transitions.dart';
import '../../data/models.dart';
import '../../data/submit_data.dart';
import '../../data/submit_service.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/button.dart';
import '../../ui/top_bar.dart';
import '../discover/discover_state.dart';
import '../drafts/drafts_state.dart';
import '../profile/profile_routes.dart';
import '../profile/your_details_screen.dart';
import '../settings/restore_account_screen.dart';
import '../submissions/submissions_routes.dart';
import '../submissions/submissions_state.dart';
import 'brief_sheet.dart';
import 'submit_sent.dart';
import 'submit_state.dart';
import 'submit_steps.dart';
import 'submit_widgets.dart';

/// Row B3, the submit flow, a sub page: the answer (34:24, 34:121), the
/// quick questions (34:186, 490:24270) when the brief asks any, then the
/// sent moment (34:269). It opens on the brief's saved draft at the step
/// the draft reached (B17 313:13650), so Drafts resumes it here. The top
/// bar and the thread hold still while the steps slide; sending dissolves
/// into the moment. A brief that cannot take a response says why, and one
/// already answered opens that submission instead.
///
/// Back pops to whichever page opened it, and from the questions it returns
/// to the answer. Every word is saved as it is typed, so leaving never asks
/// (owner, 16 Oct): the draft waits in Drafts.
///
/// A send the API refuses for a date of birth under 18 opens Date of birth,
/// and one from a closing account goes to Restore; the frames have no state
/// for either. A send the brief can never take (closed, full, past its
/// deadline or for a different audience) turns the flow into Can't submit
/// right now with the API's reason; one already sent opens it.
class SubmitScreen extends ConsumerWidget {
  const SubmitScreen({super.key, required this.briefId});

  final String briefId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opening = ref.watch(submitOpeningProvider(briefId));
    final drafts = ref.watch(draftsProvider);
    ref.listen(
      submitOpeningProvider(briefId),
      (_, next) => _openSubmitted(context, ref, next.value),
    );

    final Widget body;
    if (opening.value case final open? when !drafts.isLoading) {
      final brief = open.brief;
      final form = open.form;
      if (form != null && brief != null) {
        body = _Flow(key: const ValueKey('flow'), brief: brief, form: form);
      } else if (open.block == SubmitBlock.alreadySubmitted) {
        body = const SizedBox.shrink(key: ValueKey('submitted'));
      } else {
        body = _Blocked(
          key: const ValueKey('blocked'),
          block: open.block ?? SubmitBlock.closed,
          onBack: () => leaveSubmit(context, briefId),
        );
      }
    } else if (opening.hasError) {
      body = _LoadFailed(
        key: const ValueKey('failed'),
        onRetry: () => ref.invalidate(submitOpeningProvider(briefId)),
      );
    } else {
      body = const SizedBox.shrink(key: ValueKey('loading'));
    }

    final typing =
        body is _Flow &&
        !ref.watch(
          submitFlowProvider(briefId).select((f) => f.step == SubmitStep.sent),
        );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        resizeToAvoidBottomInset: typing,
        backgroundColor: IqColors.bg,
        body: SafeArea(
          maintainBottomViewPadding: !typing,
          child: CenteredContent(
            child: body is _Flow
                ? body
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TopBar(onBack: () => leaveSubmit(context, briefId)),
                      Expanded(child: Dissolve(child: body)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  void _openSubmitted(
    BuildContext context,
    WidgetRef ref,
    SubmitOpening? opening,
  ) {
    final sent = opening?.submissionId;
    if (opening?.block != SubmitBlock.alreadySubmitted || sent == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.openInstead(submissionPath(sent));
    });
  }
}

/// Back to the opener; a flow opened by a link goes to its brief.
void leaveSubmit(BuildContext context, String briefId) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(Routes.brief(briefId), extra: NavDirection.back);
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => IqTopBar(
    variant: IqTopBarVariant.page,
    title: 'Your submission',
    onBack: onBack,
  );
}

/// The flow itself, once the brief, its form and the drafts are in.
class _Flow extends ConsumerStatefulWidget {
  const _Flow({super.key, required this.brief, required this.form});

  final Brief brief;
  final SubmitForm form;

  @override
  ConsumerState<_Flow> createState() => _FlowState();
}

class _FlowState extends ConsumerState<_Flow> {
  String get _id => widget.brief.id;
  SubmitForm get _form => widget.form;

  void _back() {
    final flow = ref.read(submitFlowProvider(_id));
    if (flow.blocked != null) return leaveSubmit(context, _id);
    switch (flow.step) {
      case SubmitStep.sent:
        leaveSubmit(context, _id);
      case SubmitStep.questions:
        FocusScope.of(context).unfocus();
        ref.read(submitFlowProvider(_id).notifier).back();
      case SubmitStep.answer:
        FocusScope.of(context).unfocus();
        leaveSubmit(context, _id);
    }
  }

  void _continue() {
    if (!_form.hasQuestions) {
      _send();
      return;
    }
    if (ref.read(submitFlowProvider(_id).notifier).next()) {
      FocusScope.of(context).unfocus();
    } else {
      IqHaptics.error.play();
    }
  }

  Future<void> _send() async {
    final scope = ref.read(accountScopeProvider);
    final result = await ref.read(submitFlowProvider(_id).notifier).send(_form);
    if (!mounted || !scope.open) return;
    if (result == null) {
      if (!ref.read(submitFlowProvider(_id)).sending) IqHaptics.error.play();
      return;
    }
    if (result.queued) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }
    if (result.receipt case final receipt?) {
      FocusManager.instance.primaryFocus?.unfocus();
      IqHaptics.success.play();
      ref
          .read(sentSubmissionsProvider.notifier)
          .add(
            SubmissionItem(submission: receipt.submission, brief: widget.brief),
          );
      ref.invalidate(briefDetailProvider(_id));
      return;
    }
    IqHaptics.error.play();
    switch (result.failure) {
      case SubmitFailure.blocked
          when result.block == SubmitBlock.alreadySubmitted:
        ref.invalidate(submitOpeningProvider(_id));
      case SubmitFailure.underAge:
        await context.open<void>(editDetailPath(DetailField.dateOfBirth));
      case SubmitFailure.closing when Flags.deleteAccount:
        await showClosingAccount(context, ref);
      default:
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(submitFlowProvider(_id));
    final receipt = flow.receipt;
    final block = flow.blocked;
    final sent =
        flow.step == SubmitStep.sent && (receipt != null || flow.queued);
    return PopScope(
      canPop: flow.step != SubmitStep.questions || block != null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TopBar(onBack: _back),
          Expanded(
            child: Dissolve(
              child: block != null
                  ? _Blocked(
                      key: const ValueKey('blocked'),
                      block: block,
                      onBack: () => leaveSubmit(context, _id),
                    )
                  : sent
                  ? SentMoment(
                      key: const ValueKey('sent'),
                      receipt: receipt,
                      onView: receipt == null
                          ? null
                          : () => context.go(
                              submissionPath(receipt.submission.id),
                            ),
                      onDiscover: () => context.go(Routes.home),
                    )
                  : _Form(
                      key: const ValueKey('form'),
                      brief: widget.brief,
                      form: _form,
                      flow: flow,
                      canSend: ref
                          .read(submitFlowProvider(_id).notifier)
                          .canSend(_form),
                      onContinue: _continue,
                      onSend: _send,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The steps under the pinned thread (form-status: 8 above and below) and
/// over the action bar: Continue on step 1, Submit on the last step,
/// disabled until every question is answered (#37), then View the brief,
/// which opens the brief sheet over the draft (designer doc rev 57).
class _Form extends StatelessWidget {
  const _Form({
    super.key,
    required this.brief,
    required this.form,
    required this.flow,
    required this.canSend,
    required this.onContinue,
    required this.onSend,
  });

  final Brief brief;
  final SubmitForm form;
  final SubmitFlow flow;
  final bool canSend;
  final VoidCallback onContinue;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final answering = flow.step == SubmitStep.answer;
    final sends = !answering || !form.hasQuestions;
    final label = sends ? 'Submit' : 'Continue';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            IqSpace.s4,
            IqSpace.s2,
            IqSpace.s4,
            IqSpace.s2,
          ),
          child: threadOf(flow, form),
        ),
        Expanded(
          child: StepSwitcher(
            back: flow.back,
            child: answering
                ? AnswerStep(
                    key: const ValueKey(SubmitStep.answer),
                    brief: brief,
                    flow: flow,
                    settle: !flow.back,
                    onRetry: onSend,
                  )
                : QuestionsStep(
                    key: const ValueKey(SubmitStep.questions),
                    briefId: brief.id,
                    form: form,
                    flow: flow,
                    onRetry: onSend,
                  ),
          ),
        ),
        SubmitActionBar(
          children: [
            AnimatedSwitcher(
              duration: motion(context, IqDurations.swap),
              switchInCurve: IqCurves.easeOut,
              switchOutCurve: IqCurves.easeOut,
              child: IqButton(
                key: ValueKey(label),
                label: label,
                showIcon: !sends,
                width: double.infinity,
                loading: flow.sending,
                disabled: sends && form.hasQuestions && !canSend,
                onTap: sends ? onSend : onContinue,
              ),
            ),
            IqButton(
              label: 'View the brief',
              kind: IqButtonKind.ghost,
              showIcon: false,
              width: double.infinity,
              onTap: () => showBriefSheet(context, brief),
            ),
          ],
        ),
      ],
    );
  }
}

/// iqly.net's "Can't submit right now", with its reason and the way back.
class _Blocked extends StatelessWidget {
  const _Blocked({super.key, required this.block, required this.onBack});

  final SubmitBlock block;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final reason = switch (block) {
      SubmitBlock.full =>
        'Capacity reached. No more submissions can be accepted.',
      SubmitBlock.deadlinePassed => "This brief's deadline has passed.",
      SubmitBlock.closed ||
      SubmitBlock.alreadySubmitted => "This brief isn't open for submissions.",
      SubmitBlock.notInAudience => 'This brief is for a different audience.',
    };
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        IqSpace.s4,
        IqSpace.s6,
        IqSpace.s4,
        IqSpace.s4,
      ),
      child: Appear(
        child: Column(
          children: [
            Text(
              "Can't submit right now",
              textAlign: TextAlign.center,
              style: IqText.cardTitle.copyWith(color: IqColors.fg),
            ),
            const SizedBox(height: IqSpace.s2),
            Text(
              reason,
              textAlign: TextAlign.center,
              style: IqText.body.copyWith(color: IqColors.fg2),
            ),
            const SizedBox(height: IqSpace.s4),
            IqButton(
              label: 'Back to the brief',
              kind: IqButtonKind.secondary,
              showIcon: false,
              onTap: onBack,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
      child: Align(
        alignment: Alignment.topCenter,
        child: IqBanner(
          kind: IqBannerKind.error,
          title: 'Couldn’t load. Check your connection.',
          action: 'Try again',
          onAction: onRetry,
        ),
      ),
    );
  }
}
