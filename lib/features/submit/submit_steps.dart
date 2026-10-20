import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion.dart';
import '../../data/models.dart';
import '../../data/submit_data.dart';
import '../../data/submit_service.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/poll_option.dart';
import 'submit_field.dart';
import 'submit_header.dart';
import 'submit_parts.dart';
import 'submit_state.dart';

/// The guide under the cover. The answer step counts the characters the
/// answer still needs (SubmitLimits.answerMin), "4 more characters to go",
/// and only once Continue was pressed short "4 more characters" (34:24);
/// then "Ready for the next step" (34:121), or "Ready to send" when nothing
/// follows. The questions step names the first question left, then "Ready
/// to send" (490:24270). A brief without questions is "One step"
/// (1589:134761).
SubmitGuide guideOf(SubmitFlow flow, SubmitForm form) {
  final steps = form.hasQuestions ? 2 : 1;
  if (flow.step == SubmitStep.questions) {
    final missing = firstUnanswered(form, flow.draft);
    return SubmitGuide(
      words: missing == null ? 'Ready to send' : needsAnswer(missing),
      step: 'Step 2 of 2',
      state: missing == null
          ? SubmitGuideState.ready
          : SubmitGuideState.progress,
    );
  }
  final missing = SubmitLimits.answerMin - answerLength(flow.draft);
  final step = steps == 1 ? 'One step' : 'Step 1 of 2';
  if (answerReady(flow.draft)) {
    return SubmitGuide(
      words: steps == 1 ? 'Ready to send' : 'Ready for the next step',
      step: step,
      state: SubmitGuideState.ready,
    );
  }
  if (flow.answerTries > 0) {
    return SubmitGuide(
      words: moreCharacters(missing),
      step: step,
      state: SubmitGuideState.error,
    );
  }
  return SubmitGuide(words: moreCharactersToGo(missing), step: step);
}

/// Opens the phone's picker for [form]'s files and sends each one up.
Future<void> pickAttachments(
  BuildContext context,
  WidgetRef ref,
  String briefId,
  SubmitForm form,
) async {
  final picked = await ref
      .read(attachmentPickerProvider)
      .pick(only: form.fileExtensions);
  if (!context.mounted || picked.isEmpty) return;
  ref.read(submitFlowProvider(briefId).notifier).addFiles(picked);
  if (ref.read(submitFlowProvider(briefId)).fileError != null) {
    IqHaptics.error.play();
  }
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

/// Step 1 (B17 313:13650, 313:13631; B3 34:24, 34:121, 1589:134761): only
/// the title (5 to 120 characters) and the answer, 20 apart, judged by the
/// guide; the brief, the files and the drafts wait under More. A failed
/// send says so over the answer (481:21472). Writing the
/// answer scrolls it up under the guide and opens it to the foot of the
/// page, the title above it out of sight, as does coming back from the
/// questions with a title in; going back to the title brings it down. Nothing turns err until Continue was pressed.
class AnswerStep extends ConsumerStatefulWidget {
  const AnswerStep({
    super.key,
    required this.brief,
    required this.flow,
    required this.settle,
    required this.fill,
    required this.reveal,
    required this.onRetry,
  });

  final Brief brief;

  /// The flow as the screen last drew this step, so a step on its way out
  /// keeps showing what was sent while it fades.
  final SubmitFlow flow;

  /// Rides the push in; coming back from the questions it stands still.
  final bool settle;

  /// The answer's height while writing: the page under the bar and guide.
  final double fill;

  /// Scrolls the page so [double] (from the step's top, its 20 included)
  /// sits under the guide.
  final ValueChanged<double> reveal;
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
  final _titleKey = GlobalKey();
  final _answerKey = GlobalKey();
  final _bannerKey = GlobalKey();
  double _banner = 0;
  int _titleShakes = 0;
  int _answerShakes = 0;
  bool _writing = false;

  @override
  void initState() {
    super.initState();
    _titleFocus.addListener(_onTitleFocus);
    _answerFocus.addListener(_onAnswerFocus);
    if (!widget.settle && titleReady(_draft)) {
      _writing = true;
      _revealAfterLayout(_answerKey);
    }
  }

  void _onTitleFocus() {
    if (!_titleFocus.hasFocus) return;
    setState(() => _writing = false);
    _revealAfterLayout(_titleKey);
  }

  void _onAnswerFocus() {
    if (!_answerFocus.hasFocus) return;
    setState(() => _writing = true);
    _revealAfterLayout(_answerKey);
  }

  void _revealAfterLayout(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      final step = context.findRenderObject() as RenderBox?;
      if (box == null || step == null || !box.attached) return;
      final top = box.localToGlobal(Offset.zero, ancestor: step).dy;
      widget.reveal(top - IqSpace.s5);
    });
  }

  /// The failure banner takes its room from the answer while writing; its
  /// height is only known once laid out, so it is read after the frame.
  void _measureBanner() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final height = _bannerKey.currentContext?.size?.height ?? 0;
      if ((height - _banner).abs() > .5) setState(() => _banner = height);
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _answer.dispose();
    _titleFocus.dispose();
    _answerFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = submitFlowProvider(widget.brief.id);
    ref.listen(provider.select((f) => f.answerTries), (before, tries) {
      if (tries <= (before ?? 0)) return;
      final draft = ref.read(provider).draft;
      setState(() {
        if (!titleReady(draft)) {
          _titleShakes++;
          _writing = false;
        }
        if (!answerReady(draft)) _answerShakes++;
      });
      if (!titleReady(draft)) _revealAfterLayout(_titleKey);
    });
    final flow = widget.flow;
    final notifier = ref.read(provider.notifier);
    final title = titleLength(flow.draft);
    final tried = flow.answerTries > 0;
    if (flow.failed || _banner > 0) _measureBanner();
    final room = widget.fill - SubmitField.chromeOf(context) - _banner;
    return Stagger(
      move: StaggerMove.settle,
      play: widget.settle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          IqSpace.s4,
          IqSpace.s5,
          IqSpace.s4,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StaggerItem(
              index: 0,
              child: Shake(
                key: _titleKey,
                trigger: _titleShakes,
                child: SubmitField(
                  label: 'Title',
                  requirement: 'At least ${SubmitLimits.titleMin} characters',
                  placeholder: 'Give it a short title',
                  counter: fieldCount(title, SubmitLimits.titleMax),
                  error: tried && !titleReady(flow.draft),
                  help: moreCharacters(SubmitLimits.titleMin - title),
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
            const SizedBox(height: IqSpace.s5),
            StaggerItem(
              index: 1,
              child: Column(
                key: _answerKey,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  KeyedSubtree(
                    key: _bannerKey,
                    child: _Failed(flow: flow, onRetry: widget.onRetry),
                  ),
                  Shake(
                    trigger: _answerShakes,
                    child: SubmitField(
                      label: 'Your answer',
                      requirement:
                          'At least ${SubmitLimits.answerMin} characters',
                      placeholder: 'Write your answer',
                      counter: fieldCount(
                        answerLength(flow.draft),
                        SubmitLimits.answerMax,
                      ),
                      error: tried && !answerReady(flow.draft),
                      many: true,
                      inputHeight:
                          _writing && room > SubmitField.defaultInputHeight
                          ? room
                          : SubmitField.defaultInputHeight,
                      controller: _answer,
                      focusNode: _answerFocus,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(
                          SubmitLimits.answerMax,
                        ),
                      ],
                      onChanged: notifier.setAnswer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The send failure over the step, 20 above what follows (481:21472).
class _Failed extends StatelessWidget {
  const _Failed({required this.flow, required this.onRetry});

  final SubmitFlow flow;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Collapse(
      open: flow.failed,
      child: Padding(
        padding: const EdgeInsets.only(bottom: IqSpace.s5),
        child: SendFailedBanner(
          visible: flow.failed,
          onRetry: flow.refusedFile ? null : onRetry,
        ),
      ),
    );
  }
}

/// Step 2 (34:186, 490:24270), the last look before sending: the
/// business's questions, all required (a choice is a column of
/// Exp/PollOption), 20 apart. The files sit under More (481:21544); a
/// brief that asks no questions and takes files lists them here, as
/// there is nothing else on the step.
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
      if (!q.choice) q.id: FocusNode(),
  };

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

  @override
  Widget build(BuildContext context) {
    final provider = submitFlowProvider(widget.briefId);
    final flow = widget.flow;
    final notifier = ref.read(provider.notifier);
    final form = widget.form;
    return Padding(
      padding: const EdgeInsets.fromLTRB(IqSpace.s4, IqSpace.s5, IqSpace.s4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Failed(flow: flow, onRetry: widget.onRetry),
          if (form.questions.isNotEmpty)
            const StepHeading(title: 'A few quick questions'),
          for (final q in form.questions) ...[
            const SizedBox(height: IqSpace.s5),
            if (q.choice)
              _Choice(
                question: q,
                picked: flow.draft.answers[q.id] ?? const [],
                onPick: (option) => notifier.pick(q, option),
              )
            else
              SubmitField(
                label: q.text,
                requirement: 'Required',
                placeholder: 'Type your answer',
                counter: fieldCount(
                  _texts[q.id]!.text.trim().length,
                  SubmitLimits.questionMax,
                ),
                many: true,
                inputHeight: 0,
                controller: _texts[q.id]!,
                focusNode: _focus[q.id]!,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(SubmitLimits.questionMax),
                ],
                onChanged: (text) => notifier.type(q, text),
              ),
          ],
          if (form.questions.isEmpty && form.acceptsFiles)
            AttachmentsPanel(
              files: flow.files,
              error: flow.fileError,
              onAdd: () => pickAttachments(context, ref, widget.briefId, form),
              onRetry: notifier.retry,
            ),
          const SizedBox(height: IqSpace.s5),
        ],
      ),
    );
  }
}

/// A choice question: its words with "(pick one)" (Figma 34:186) or "(pick
/// one or more)" (iqly.net), then the options 20 below
/// and 8 apart.
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
        const SizedBox(height: IqSpace.s5),
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
