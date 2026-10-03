import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/responsive.dart';
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
import '../submissions/submissions_routes.dart';
import '../submissions/submissions_state.dart';
import 'submit_sent.dart';
import 'submit_state.dart';
import 'submit_steps.dart';
import 'submit_thread.dart';
import 'submit_widgets.dart';

/// Row B3, the submit flow from Brief detail: the answer (34:24, 34:121),
/// the quick questions (34:186) when the brief asks any, then the sent
/// moment (34:269). The top bar and the thread under it hold still while
/// the steps slide; sending dissolves into the moment. A brief that cannot
/// take a response says why, as iqly.net does, and one already answered
/// opens that submission instead.
///
/// Figma: back on the sent moment goes to Discover, and so does system
/// back; on the questions it returns to the answer.
class SubmitScreen extends ConsumerStatefulWidget {
  const SubmitScreen({super.key, required this.briefId});

  final String briefId;

  @override
  ConsumerState<SubmitScreen> createState() => _SubmitScreenState();
}

class _SubmitScreenState extends ConsumerState<SubmitScreen> {
  String get _id => widget.briefId;

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.brief(_id), extra: NavDirection.back);
    }
  }

  void _back() {
    switch (ref.read(submitFlowProvider(_id)).step) {
      case SubmitStep.sent:
        context.go(Routes.home, extra: NavDirection.back);
      case SubmitStep.questions:
        FocusScope.of(context).unfocus();
        ref.read(submitFlowProvider(_id).notifier).back();
      case SubmitStep.answer:
        _leave();
    }
  }

  void _continue(SubmitForm form) {
    if (!form.hasQuestions) {
      _send(form);
      return;
    }
    if (ref.read(submitFlowProvider(_id).notifier).next()) {
      FocusScope.of(context).unfocus();
    } else {
      IqHaptics.error.play();
    }
  }

  Future<void> _send(SubmitForm form) async {
    final result = await ref.read(submitFlowProvider(_id).notifier).send(form);
    if (!mounted) return;
    if (result == null) {
      if (!ref.read(submitFlowProvider(_id)).sending) IqHaptics.error.play();
      return;
    }
    if (result.receipt case final receipt?) {
      FocusManager.instance.primaryFocus?.unfocus();
      IqHaptics.success.play();
      ref
          .read(sentSubmissionsProvider.notifier)
          .add(
            SubmissionItem(
              submission: receipt.submission,
              brief: ref.read(submitOpeningProvider(_id)).value?.brief,
            ),
          );
      ref.invalidate(briefDetailProvider(_id));
      return;
    }
    IqHaptics.error.play();
    if (result.failure == SubmitFailure.blocked) {
      ref.invalidate(submitOpeningProvider(_id));
    }
  }

  void _openSubmitted(SubmitOpening? opening) {
    final sent = opening?.submissionId;
    if (opening?.block != SubmitBlock.alreadySubmitted || sent == null) return;
    if (ref.read(submitFlowProvider(_id)).step == SubmitStep.sent) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.replace(submissionPath(sent));
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      submitOpeningProvider(_id),
      (_, next) => _openSubmitted(next.value),
    );
    final opening = ref.watch(submitOpeningProvider(_id));
    final flow = ref.watch(submitFlowProvider(_id));
    final receipt = flow.receipt;

    final Widget body;
    if (flow.step == SubmitStep.sent && receipt != null) {
      body = SentMoment(
        key: const ValueKey('sent'),
        receipt: receipt,
        onView: () => context.go(submissionPath(receipt.submission.id)),
        onDiscover: () => context.go(Routes.home),
      );
    } else if (opening.value case final open?) {
      final brief = open.brief;
      final form = open.form;
      if (form != null && brief != null) {
        body = _Form(
          key: const ValueKey('form'),
          brief: brief,
          form: form,
          flow: flow,
          onContinue: () => _continue(form),
          onSend: () => _send(form),
        );
      } else if (open.block == SubmitBlock.alreadySubmitted) {
        body = const SizedBox.shrink(key: ValueKey('submitted'));
      } else {
        body = _Blocked(
          key: const ValueKey('blocked'),
          block: open.block ?? SubmitBlock.closed,
          onBack: _leave,
        );
      }
    } else if (opening.hasError) {
      body = _LoadFailed(
        key: const ValueKey('failed'),
        onRetry: () => ref.invalidate(submitOpeningProvider(_id)),
      );
    } else {
      body = const SizedBox.shrink(key: ValueKey('loading'));
    }

    // Only the steps have fields; the moment and the blocked notice hold
    // still while a keyboard leaves.
    final typing = body is _Form;
    return PopScope(
      canPop: flow.step == SubmitStep.answer,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          resizeToAvoidBottomInset: typing,
          backgroundColor: IqColors.bg,
          body: SafeArea(
            maintainBottomViewPadding: !typing,
            child: CenteredContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  IqTopBar(
                    variant: IqTopBarVariant.page,
                    title: 'Submit your response',
                    onBack: _back,
                  ),
                  Expanded(child: Dissolve(child: body)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The steps under the pinned thread (form-status: 8 above and below) and
/// over the action bar. The button's words cross over 150 ms between
/// Continue and Send response.
class _Form extends StatelessWidget {
  const _Form({
    super.key,
    required this.brief,
    required this.form,
    required this.flow,
    required this.onContinue,
    required this.onSend,
  });

  final Brief brief;
  final SubmitForm form;
  final SubmitFlow flow;
  final VoidCallback onContinue;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final answering = flow.step == SubmitStep.answer;
    final sends = !answering || !form.hasQuestions;
    final label = sends ? 'Send response' : 'Continue';
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
          child: SubmitThread(
            look: answering
                ? answerThread(flow, steps: form.hasQuestions ? 2 : 1)
                : questionsThread(flow, form),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
          child: IqBanner(
            kind: IqBannerKind.error,
            title: 'Failed to submit',
            action: 'Try again',
            visible: flow.failed,
            onAction: onSend,
          ),
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
                  )
                : QuestionsStep(
                    key: const ValueKey(SubmitStep.questions),
                    briefId: brief.id,
                    form: form,
                    flow: flow,
                  ),
          ),
        ),
        SubmitActionBar(
          children: [
            AnimatedSwitcher(
              duration: motion(context, IqDurations.crossfade),
              switchInCurve: IqCurves.easeOut,
              switchOutCurve: IqCurves.easeOut,
              child: IqButton(
                key: ValueKey(label),
                label: label,
                width: double.infinity,
                loading: flow.sending,
                onTap: sends ? onSend : onContinue,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// iqly.net's "Can't submit right now", with its reason (the capacity one
/// loses its em dash for a period) and the way back to the brief.
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
