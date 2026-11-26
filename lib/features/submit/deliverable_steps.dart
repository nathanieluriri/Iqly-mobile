import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/submit_data.dart';
import '../../theme/theme.dart';
import '../../ui/icon.dart';
import '../../ui/text_link.dart';
import 'submit_field.dart';
import 'submit_header.dart';
import 'submit_state.dart';
import 'submit_steps.dart';

class DeliverableHeader extends StatelessWidget {
  const DeliverableHeader({
    super.key,
    required this.brief,
    required this.form,
    required this.flow,
    required this.onBack,
    required this.onMore,
  });

  final Brief brief;
  final SubmitForm form;
  final SubmitFlow flow;
  final VoidCallback onBack;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final review = flow.step == SubmitStep.review;
    final index = flow.deliverableIndex;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: IqSpace.s4,
        vertical: IqSpace.s1p5,
      ),
      child: Row(
        children: [
          RoundIconButton(
            icon: IqIcons.back,
            label: 'Back',
            color: IqColors.brand,
            onTap: onBack,
          ),
          const SizedBox(width: IqSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  review
                      ? '${form.deliverables.length} of ${form.deliverables.length} answered'
                      : 'Deliverable ${index + 1} of ${form.deliverables.length}',
                  style: IqText.small.copyWith(color: IqColors.fg2),
                ),
                Text(
                  review ? 'Review and submit' : form.deliverables[index],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: IqText.smallStrong.copyWith(color: IqColors.fg),
                ),
              ],
            ),
          ),
          const SizedBox(width: IqSpace.s3),
          RoundIconButton.more(onTap: onMore),
        ],
      ),
    );
  }
}

class _DeliverableFailure extends ConsumerWidget {
  const _DeliverableFailure({required this.briefId, required this.flow});

  final String briefId;
  final SubmitFlow flow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: IqSpace.s4),
      child: SendFailedBanner(
        visible: flow.failed,
        onRetry: flow.refusedFile
            ? null
            : () => ref.read(submitFlowProvider(briefId).notifier).retrySend(),
      ),
    );
  }
}

class DeliverableStep extends ConsumerStatefulWidget {
  const DeliverableStep({
    super.key,
    required this.briefId,
    required this.index,
    required this.prompt,
    required this.flow,
  });

  final String briefId;
  final int index;
  final String prompt;
  final SubmitFlow flow;

  @override
  ConsumerState<DeliverableStep> createState() => _DeliverableStepState();
}

class _DeliverableStepState extends ConsumerState<DeliverableStep> {
  late final TextEditingController _answer;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _answer = TextEditingController(
      text: deliverableAnswer(widget.flow.draft, widget.index),
    );
  }

  @override
  void dispose() {
    _answer.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flow = widget.flow;
    final tried = flow.answerTries > 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(IqSpace.s4, IqSpace.s2, IqSpace.s4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (flow.failed)
            _DeliverableFailure(briefId: widget.briefId, flow: flow),
          Expanded(
            child: SubmitField(
              label: widget.prompt,
              requirement: '',
              placeholder: 'Write your answer',
              counter: fieldCount(
                deliverableAnswerLength(flow.draft, widget.index),
                SubmitLimits.answerMax,
              ),
              error: tried && !deliverableAnswerReady(flow.draft, widget.index),
              help: moreCharacters(
                SubmitLimits.answerMin -
                    deliverableAnswerLength(flow.draft, widget.index),
              ),
              many: true,
              showLabel: false,
              inputHeight: 300,
              controller: _answer,
              focusNode: _focus,
              inputFormatters: [
                LengthLimitingTextInputFormatter(SubmitLimits.answerMax),
              ],
              onChanged: (text) => ref
                  .read(submitFlowProvider(widget.briefId).notifier)
                  .setDeliverableAnswer(widget.index, text),
            ),
          ),
        ],
      ),
    );
  }
}

class DeliverableReview extends StatelessWidget {
  const DeliverableReview({
    super.key,
    required this.briefId,
    required this.deliverables,
    required this.flow,
  });

  final String briefId;
  final List<String> deliverables;
  final SubmitFlow flow;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(IqSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (flow.failed) _DeliverableFailure(briefId: briefId, flow: flow),
          for (final (index, prompt) in deliverables.indexed) ...[
            if (index > 0) ...[
              const SizedBox(height: IqSpace.s6),
              const SizedBox(
                height: 1,
                child: ColoredBox(color: IqColors.line),
              ),
              const SizedBox(height: IqSpace.s6),
            ],
            _ReviewAnswer(
              briefId: briefId,
              index: index,
              prompt: prompt,
              answer: deliverableAnswer(flow.draft, index),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewAnswer extends ConsumerWidget {
  const _ReviewAnswer({
    required this.briefId,
    required this.index,
    required this.prompt,
    required this.answer,
  });

  final String briefId;
  final int index;
  final String prompt;
  final String answer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${index + 1} · $prompt',
                style: IqText.bodyStrong.copyWith(color: IqColors.fg),
              ),
            ),
            IqTextLink(
              label: 'Edit answer',
              showIcon: false,
              onTap: () => ref
                  .read(submitFlowProvider(briefId).notifier)
                  .editDeliverable(index),
            ),
          ],
        ),
        const SizedBox(height: IqSpace.s2),
        Text(answer, style: IqText.body.copyWith(color: IqColors.fg2)),
      ],
    );
  }
}
