import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/deadline.dart';
import '../../core/motion.dart';
import '../../core/relative_time.dart';
import '../../data/models.dart';
import '../../data/submit_data.dart';
import '../../data/submit_service.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/field.dart';
import '../../ui/poll_option.dart';
import '../../ui/progress_thread.dart';
import 'submit_parts.dart';
import 'submit_state.dart';
import 'submit_widgets.dart';

AnswerLook answerLookOf(SubmitFlow flow) {
  if (answerReady(flow.draft)) return AnswerLook.ready;
  if (answerLength(flow.draft) == 0 && flow.answerTries == 0) {
    return AnswerLook.neutral;
  }
  return AnswerLook.error;
}

/// The pinned Exp/ProgressThread. Step 1 judges the text area: "4 more
/// characters to go" while writing (313:13631), "4 more characters" in
/// Error once Continue was tried short (34:24), then "Ready for the next
/// step". Step 2 names the first question left, then "Ready to send",
/// still in Progress with its count (490:24270).
IqProgressThread threadOf(SubmitFlow flow, SubmitForm form) {
  final steps = form.hasQuestions ? 2 : 1;
  if (flow.step == SubmitStep.questions) {
    final missing = firstUnanswered(form, flow.draft);
    return IqProgressThread(
      status: missing == null ? 'Ready to send' : needsAnswer(missing),
      count: '2 of 2',
    );
  }
  final missing = SubmitLimits.answerMin - answerLength(flow.draft);
  final ready = answerReady(flow.draft);
  final error = !ready && flow.answerTries > 0;
  return IqProgressThread(
    status: moreCharactersToGo(missing),
    count: '1 of $steps',
    readyText: steps == 1 ? 'Ready to send' : 'Ready for the next step',
    errorText: moreCharacters(missing),
    state: ready
        ? IqProgressThreadState.ready
        : error
        ? IqProgressThreadState.error
        : IqProgressThreadState.progress,
  );
}

/// A step's Mob/Title heading (the "step" frame: 8 above and below).
class StepHeading extends StatelessWidget {
  const StepHeading({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: IqSpace.s2),
      child: Text(title, style: IqText.title.copyWith(color: IqColors.fg)),
    );
  }
}

/// "Couldn’t send. Your draft is saved on this phone." (481:21472).
class SendFailedBanner extends StatelessWidget {
  const SendFailedBanner({
    super.key,
    required this.visible,
    required this.onRetry,
  });

  final bool visible;

  /// Null hides Try again, for a send that would only be refused again.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return IqBanner(
      kind: IqBannerKind.error,
      title: 'Couldn’t send. Your draft is saved on this phone.',
      action: onRetry == null ? null : 'Try again',
      visible: visible,
      onAction: onRetry,
    );
  }
}

/// Step 1 (34:24, 34:121; B17 313:13631, 313:13650): the brief it answers,
/// the title (5 to 120 characters, inline) and the answer, judged by the
/// thread. A flow opened on a saved draft says so where the autosave line
/// would sit, above the heading.
class AnswerStep extends ConsumerStatefulWidget {
  const AnswerStep({
    super.key,
    required this.brief,
    required this.flow,
    required this.settle,
    required this.onRetry,
  });

  final Brief brief;

  /// The flow as the screen last drew this step, so a step on its way out
  /// keeps showing what was sent while it fades.
  final SubmitFlow flow;

  /// Rides the push in; coming back from the questions it stands still.
  final bool settle;
  final VoidCallback onRetry;

  @override
  ConsumerState<AnswerStep> createState() => _AnswerStepState();
}

class _AnswerStepState extends ConsumerState<AnswerStep> {
  late final _draft = ref.read(submitFlowProvider(widget.brief.id)).draft;
  late final _title = TextEditingController(text: _draft.title);
  late final _answer = TextEditingController(text: _draft.answer);
  final _titleFocus = FocusNode();
  final _answerFocus = FocusNode();
  int _titleShakes = 0;
  int _answerShakes = 0;

  @override
  void initState() {
    super.initState();
    _titleFocus.addListener(_onFocus);
  }

  void _onFocus() => setState(() {});

  @override
  void dispose() {
    _title.dispose();
    _answer.dispose();
    _titleFocus.dispose();
    _answerFocus.dispose();
    super.dispose();
  }

  IqFieldState? _titleState(SubmitFlow flow) {
    final tried = flow.answerTries > 0;
    final ready = titleReady(flow.draft);
    if (_titleFocus.hasFocus) {
      return tried && !ready ? IqFieldState.error : null;
    }
    if (titleLength(flow.draft) == 0) {
      return tried ? IqFieldState.error : IqFieldState.empty;
    }
    return ready ? IqFieldState.valid : IqFieldState.error;
  }

  @override
  Widget build(BuildContext context) {
    final provider = submitFlowProvider(widget.brief.id);
    ref.listen(provider.select((f) => f.answerTries), (before, tries) {
      if (tries <= (before ?? 0)) return;
      final draft = ref.read(provider).draft;
      setState(() {
        if (!titleReady(draft)) _titleShakes++;
        if (!answerReady(draft)) _answerShakes++;
      });
    });
    final flow = widget.flow;
    final notifier = ref.read(provider.notifier);
    final title = titleLength(flow.draft);
    final now = ref.watch(clockProvider)();
    final restored = flow.restored;
    final note = Text(
      restored != null
          ? 'Welcome back. Your draft is here, saved '
                '${timeAgoShort(restored, now)}.'
          : 'Drafts autosave until you send.',
      style: IqText.small.copyWith(color: IqColors.fg2),
    );
    return Stagger(
      move: StaggerMove.settle,
      play: widget.settle,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StaggerItem(
              index: 0,
              child: BriefContext(brief: widget.brief, now: now),
            ),
            _Failed(flow: flow, onRetry: widget.onRetry),
            if (restored != null) ...[
              const SizedBox(height: IqSpace.s2),
              StaggerItem(index: 1, child: note),
            ],
            const SizedBox(height: IqSpace.s2),
            const StaggerItem(
              index: 1,
              child: StepHeading(title: "What's your take?"),
            ),
            const SizedBox(height: IqSpace.s2),
            StaggerItem(
              index: 2,
              child: Shake(
                trigger: _titleShakes,
                child: IqField(
                  label: 'Title',
                  value: '',
                  note: '$title/${SubmitLimits.titleMax}',
                  help: moreCharacters(SubmitLimits.titleMin - title),
                  state: _titleState(flow),
                  controller: _title,
                  focusNode: _titleFocus,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(SubmitLimits.titleMax),
                  ],
                  onChanged: notifier.setTitle,
                  onSubmitted: (_) => _answerFocus.requestFocus(),
                ),
              ),
            ),
            const SizedBox(height: IqSpace.s2),
            StaggerItem(
              index: 3,
              child: Shake(
                trigger: _answerShakes,
                child: AnswerArea(
                  controller: _answer,
                  focusNode: _answerFocus,
                  look: answerLookOf(flow),
                  length: answerLength(flow.draft),
                  onChanged: notifier.setAnswer,
                ),
              ),
            ),
            if (restored == null) ...[
              const SizedBox(height: IqSpace.s2),
              StaggerItem(index: 4, child: note),
            ],
            const SizedBox(height: IqSpace.s4),
          ],
        ),
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.flow, required this.onRetry});

  final SubmitFlow flow;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Collapse(
      open: flow.failed,
      child: Padding(
        padding: const EdgeInsets.only(top: IqSpace.s2),
        child: SendFailedBanner(
          visible: flow.failed,
          onRetry: flow.refusedFile ? null : onRetry,
        ),
      ),
    );
  }
}

/// Step 2 (34:186, 490:24270, 481:21544): the business's questions, all
/// required (a choice is a column of Exp/PollOption), then the attachments
/// group. Attachments opens the phone's own picker; each file goes up at
/// once and a failed one retries on tap.
class QuestionsStep extends ConsumerStatefulWidget {
  const QuestionsStep({
    super.key,
    required this.briefId,
    required this.form,
    required this.flow,
    required this.onRetry,
  });

  final String briefId;
  final SubmitForm form;

  /// The flow as the screen last drew this step.
  final SubmitFlow flow;
  final VoidCallback onRetry;

  @override
  ConsumerState<QuestionsStep> createState() => _QuestionsStepState();
}

class _QuestionsStepState extends ConsumerState<QuestionsStep> {
  late final _draft = ref.read(submitFlowProvider(widget.briefId)).draft;
  late final _texts = {
    for (final q in widget.form.questions)
      if (!q.choice)
        q.id: TextEditingController(
          text: (_draft.answers[q.id] ?? const []).firstOrNull ?? '',
        ),
  };
  late final _focus = {
    for (final q in widget.form.questions)
      if (!q.choice) q.id: FocusNode()..addListener(_onFocus),
  };

  void _onFocus() => setState(() {});

  @override
  void dispose() {
    for (final c in _texts.values) {
      c.dispose();
    }
    for (final f in _focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _attach() async {
    final picked = await ref
        .read(attachmentPickerProvider)
        .pick(only: widget.form.fileExtensions);
    if (!mounted || picked.isEmpty) return;
    final notifier = ref.read(submitFlowProvider(widget.briefId).notifier);
    notifier.addFiles(picked);
    if (ref.read(submitFlowProvider(widget.briefId)).fileError != null) {
      IqHaptics.error.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = submitFlowProvider(widget.briefId);
    final flow = widget.flow;
    final notifier = ref.read(provider.notifier);
    final form = widget.form;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Failed(flow: flow, onRetry: widget.onRetry),
          if (form.questions.isNotEmpty)
            const StepHeading(title: 'A few quick questions'),
          for (final q in form.questions) ...[
            const SizedBox(height: IqSpace.s2),
            if (q.choice)
              _Choice(
                question: q,
                picked: flow.draft.answers[q.id] ?? const [],
                onPick: (option) => notifier.pick(q, option),
              )
            else
              _Text(
                question: q,
                controller: _texts[q.id]!,
                focusNode: _focus[q.id]!,
                answered: answered(flow.draft, q),
                onChanged: (text) => notifier.type(q, text),
              ),
          ],
          if (form.acceptsFiles) ...[
            const SizedBox(height: IqSpace.s2),
            AttachmentsGroup(
              files: flow.files,
              onAdd: _attach,
              onRetry: notifier.retry,
            ),
            if (flow.fileError case final error?)
              Padding(
                padding: const EdgeInsets.only(top: IqSpace.s1p5),
                child: Reveal(
                  key: ValueKey(error),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      error,
                      style: IqText.small.copyWith(color: IqColors.errStrong),
                    ),
                  ),
                ),
              ),
          ],
          const SizedBox(height: IqSpace.s4),
        ],
      ),
    );
  }
}

/// A free-text question: the label and "Type your answer"; once answered
/// the valid check and "18/500 · required" (490:24270).
class _Text extends StatelessWidget {
  const _Text({
    required this.question,
    required this.controller,
    required this.focusNode,
    required this.answered,
    required this.onChanged,
  });

  final SurveyQuestion question;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool answered;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return IqField(
      label: question.text,
      value: 'Type your answer',
      note:
          '${controller.text.trim().length}/${SubmitLimits.questionMax} · '
          'required',
      showNote: answered,
      state: focusNode.hasFocus
          ? null
          : answered
          ? IqFieldState.valid
          : IqFieldState.empty,
      controller: controller,
      focusNode: focusNode,
      textInputAction: TextInputAction.done,
      inputFormatters: [
        LengthLimitingTextInputFormatter(SubmitLimits.questionMax),
      ],
      onChanged: onChanged,
    );
  }
}

/// A choice question: its words with "(pick one)" (Figma 34:186) or "(pick
/// one or more)" (iqly.net), then the options 8 apart.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.question,
    required this.picked,
    required this.onPick,
  });

  final SurveyQuestion question;
  final List<String> picked;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final hint = question.multi ? '(pick one or more)' : '(pick one)';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${question.text} $hint',
          style: IqText.body.copyWith(color: IqColors.fg),
        ),
        const SizedBox(height: IqSpace.s2),
        LayoutBuilder(
          builder: (context, box) => Column(
            children: [
              for (final (i, option) in question.options.indexed) ...[
                if (i > 0) const SizedBox(height: IqSpace.s2),
                AnimatedSwitcher(
                  duration: motion(context, IqDurations.press),
                  switchInCurve: IqCurves.easeOut,
                  switchOutCurve: IqCurves.easeOut,
                  child: IqPollOption(
                    key: ValueKey((option, picked.contains(option))),
                    label: option,
                    width: box.maxWidth,
                    state: picked.contains(option)
                        ? IqPollOptionState.selected
                        : IqPollOptionState.standard,
                    onTap: () => onPick(option),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
