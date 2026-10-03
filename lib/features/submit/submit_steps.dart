import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion.dart';
import '../../data/models.dart';
import '../../data/submit_data.dart';
import '../../data/submit_service.dart';
import '../../theme/theme.dart';
import '../../ui/field.dart';
import '../../ui/icon.dart';
import '../../ui/list_row.dart';
import '../../ui/poll_option.dart';
import 'submit_state.dart';
import 'submit_thread.dart';
import 'submit_widgets.dart';

const readyText = 'Ready for the next step';

AnswerLook answerLookOf(SubmitFlow flow) {
  if (answerReady(flow.draft)) return AnswerLook.ready;
  if (answerLength(flow.draft) == 0 && flow.answerTries == 0) {
    return AnswerLook.neutral;
  }
  return AnswerLook.error;
}

/// The thread judges only the text area (Figma 34:20): Progress before
/// anything is typed, Error while it is under 20 characters, Ready after.
ThreadLook answerThread(SubmitFlow flow, {required int steps}) {
  final missing = SubmitLimits.answerMin - answerLength(flow.draft);
  final count = '1 of $steps';
  return switch (answerLookOf(flow)) {
    AnswerLook.ready => const ThreadLook.ready(readyText),
    AnswerLook.neutral => ThreadLook.progress(moreCharacters(missing), count),
    AnswerLook.error => ThreadLook.error(moreCharacters(missing), count),
  };
}

/// On the questions step it names the first question still unanswered
/// (34:186), in Error once Send was tried without it.
ThreadLook questionsThread(SubmitFlow flow, SubmitForm form) {
  final missing = firstUnanswered(form, flow.draft);
  if (missing == null) return const ThreadLook.ready(readyText);
  const count = '2 of 2';
  final text = needsAnswer(missing);
  return flow.questionTries > 0
      ? ThreadLook.error(text, count)
      : ThreadLook.progress(text, count);
}

/// A step's eyebrow and Mob/Title heading (the "step" frame: 8 above and
/// below, 4 between).
class StepHeading extends StatelessWidget {
  const StepHeading({super.key, required this.title, this.eyebrow});

  final String? eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: IqSpace.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow case final eyebrow?) ...[
            Text(
              eyebrow.toUpperCase(),
              style: IqText.mono.copyWith(color: IqColors.fg3),
            ),
            const SizedBox(height: IqSpace.s1),
          ],
          Text(title, style: IqText.title.copyWith(color: IqColors.fg)),
        ],
      ),
    );
  }
}

/// B3 · Submit · answer too short (34:24) and answer ready (34:121): the
/// title validates inline (5 to 120 characters, as iqly.net), the answer
/// area is judged by the thread. Its parts settle in with the push.
class AnswerStep extends ConsumerStatefulWidget {
  const AnswerStep({super.key, required this.brief, required this.settle});

  final Brief brief;

  /// Rides the push in; coming back from the questions it stands still.
  final bool settle;

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
    final flow = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final title = titleLength(flow.draft);
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
              child: StepHeading(
                eyebrow: widget.brief.businessName,
                title: "What's your take?",
              ),
            ),
            const SizedBox(height: IqSpace.s2),
            StaggerItem(
              index: 1,
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
              index: 2,
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
            const SizedBox(height: IqSpace.s2),
            StaggerItem(
              index: 3,
              child: Text(
                'Drafts autosave until you send.',
                style: IqText.small.copyWith(color: IqColors.fg2),
              ),
            ),
            const SizedBox(height: IqSpace.s4),
          ],
        ),
      ),
    );
  }
}

/// B3 · Submit · quick questions (34:186): the business's questions, all
/// required (a choice is a column of Exp/PollOption, picking one fills it
/// over 120 ms with the select haptic), then Attachments, which opens the
/// file picker and keeps up to five files of 10 MB.
class QuestionsStep extends ConsumerStatefulWidget {
  const QuestionsStep({super.key, required this.briefId, required this.form});

  final String briefId;
  final SubmitForm form;

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
  final _shakes = <String, int>{};

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
    final picked = await ref.read(attachmentPickerProvider).pick();
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
    ref.listen(provider.select((f) => f.questionTries), (before, tries) {
      if (tries <= (before ?? 0)) return;
      final missing = firstUnanswered(widget.form, ref.read(provider).draft);
      if (missing == null) return;
      final id = widget.form.questions[missing].id;
      setState(() => _shakes[id] = (_shakes[id] ?? 0) + 1);
    });
    final flow = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final form = widget.form;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (form.questions.isNotEmpty) ...[
            const StepHeading(
              eyebrow: 'All required',
              title: 'A few quick questions',
            ),
            for (final (i, q) in form.questions.indexed) ...[
              const SizedBox(height: IqSpace.s2),
              Shake(
                trigger: _shakes[q.id] ?? 0,
                child: q.choice
                    ? _Choice(
                        question: q,
                        picked: flow.draft.answers[q.id] ?? const [],
                        onPick: (option) => notifier.pick(q, option),
                      )
                    : IqField(
                        label: q.text,
                        value: 'Type your answer',
                        help: needsAnswer(i),
                        showNote: false,
                        state: _textState(
                          focused: _focus[q.id]!.hasFocus,
                          empty: !answered(flow.draft, q),
                          tried: flow.questionTries > 0,
                        ),
                        controller: _texts[q.id],
                        focusNode: _focus[q.id],
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(
                            SubmitLimits.questionMax,
                          ),
                        ],
                        onChanged: (text) => notifier.type(q, text),
                      ),
              ),
            ],
          ],
          if (form.acceptsFiles) ...[
            const SizedBox(height: IqSpace.s2),
            IqListRow(
              label: 'Attachments',
              description:
                  'Up to ${SubmitLimits.files} files · '
                  '${SubmitLimits.fileBytes ~/ (1024 * 1024)} MB each',
              icon: IqIcons.plus,
              divider: false,
              onTap: _attach,
            ),
            for (final (i, file) in flow.files.indexed)
              _Inserted(
                key: ObjectKey(file),
                child: AttachedFileRow(
                  file: file,
                  onRemove: () => notifier.removeFile(i),
                ),
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

  IqFieldState? _textState({
    required bool focused,
    required bool empty,
    required bool tried,
  }) {
    if (focused) return tried && empty ? IqFieldState.error : null;
    if (empty) return tried ? IqFieldState.error : IqFieldState.empty;
    return IqFieldState.valid;
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

/// A row added while in view: its space opens, then it arrives (MOTION-SPEC
/// §5.17), through [Collapse].
class _Inserted extends StatefulWidget {
  const _Inserted({super.key, required this.child});

  final Widget child;

  @override
  State<_Inserted> createState() => _InsertedState();
}

class _InsertedState extends State<_Inserted> {
  bool _open = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _open = true);
    });
  }

  @override
  Widget build(BuildContext context) =>
      Collapse(open: _open, child: widget.child);
}
