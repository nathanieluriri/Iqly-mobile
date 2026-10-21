import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/deadline.dart';
import '../../core/money.dart';
import '../../core/navigation.dart';
import '../../core/responsive.dart';
import '../../data/models.dart';
import '../../data/submit_data.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/pressable.dart';
import '../../ui/tablet_action_bar.dart';
import '../../ui/tablet_icon.dart';
import '../discover/business_art.dart';
import '../discover/discover_widgets.dart';
import '../shell/tablet_page.dart';
import 'submit_header.dart';
import 'submit_state.dart';

/// T6 · Submit (Mobile App · tablet, 1834:42568). Landscape: the 1024
/// layout, the step beside the 320 requirements panel (the brief, What to
/// send and the one button). Portrait: one column, the step full width,
/// What to send under it and the button in Exp/Tablet/ActionBar (Submit
/// with Back on step 2). The guide line leads the page, under the crumbs.
class TabletSubmitLayout extends StatelessWidget {
  const TabletSubmitLayout({
    super.key,
    required this.brief,
    required this.form,
    required this.flow,
    required this.guide,
    required this.step,
    required this.label,
    required this.showIcon,
    required this.loading,
    required this.disabled,
    required this.onPrimary,
    required this.onBack,
  });

  final Brief brief;
  final SubmitForm form;
  final SubmitFlow flow;
  final SubmitGuide guide;
  final Widget step;
  final String label;
  final bool showIcon;
  final bool loading;
  final bool disabled;
  final VoidCallback onPrimary;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final expanded = Layout.isExpanded(context);
    final questions = flow.step == SubmitStep.questions;
    final crumbs = [
      TabletCrumb('Discover', () => context.go(Routes.home)),
      TabletCrumb(brief.title, () => context.open(Routes.brief(brief.id))),
      const TabletCrumb('Your submission'),
    ];
    final button = IqButton(
      label: label,
      showIcon: showIcon,
      loading: loading,
      disabled: disabled,
      width: expanded ? double.infinity : 248,
      onTap: onPrimary,
    );
    final panel = RequirementsPanel(
      brief: brief,
      form: form,
      flow: flow,
      action: expanded
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                button,
                if (questions) ...[
                  const SizedBox(height: IqSpace.s3),
                  IqButton(
                    label: 'Back',
                    kind: IqButtonKind.ghost,
                    showIcon: false,
                    width: double.infinity,
                    height: 44,
                    onTap: onBack,
                  ),
                ],
              ],
            )
          : null,
    );
    final head = SizedBox(height: SubmitGuide.height, child: guide);
    if (expanded) {
      return TabletPage(
        crumbs: crumbs,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [head, step],
                ),
              ),
              const SizedBox(width: IqSpace.s6),
              SizedBox(width: 320, child: panel),
            ],
          ),
        ],
      );
    }
    final steps = form.hasQuestions ? 2 : 1;
    return TabletPage(
      crumbs: crumbs,
      bottomBar: IqTabletActionBar(
        title: '${questions ? 2 : 1} of $steps',
        caption: questions
            ? guide.words
            : form.hasQuestions
            ? _questionCount(form)
            : guide.words,
        actions: [
          if (questions)
            IqButton(
              label: 'Back',
              kind: IqButtonKind.ghost,
              showIcon: false,
              width: 96,
              onTap: onBack,
            ),
          button,
        ],
      ),
      children: [head, step, panel],
    );
  }
}

String _questionCount(SubmitForm form) {
  final n = form.questions.length;
  return '$n ${n == 1 ? 'question' : 'questions'}, next';
}

/// The requirements panel: the brief with View the brief, then What to
/// send, each requirement ticked once it is met.
class RequirementsPanel extends StatelessWidget {
  const RequirementsPanel({
    super.key,
    required this.brief,
    required this.form,
    required this.flow,
    this.action,
  });

  final Brief brief;
  final SubmitForm form;
  final SubmitFlow flow;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final draft = flow.draft;
    final questions = flow.step == SubmitStep.questions;
    final mb = SubmitLimits.fileBytes ~/ (1024 * 1024);
    return Container(
      padding: const EdgeInsets.all(IqSpace.s6),
      decoration: BoxDecoration(
        color: IqColors.card,
        borderRadius: BorderRadius.circular(IqRadius.xl2),
        border: Border.all(color: IqColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipOval(child: businessLogo(brief.logo, size: 40)),
              const SizedBox(width: IqSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      businessLabel(brief),
                      style: IqWebText.metaCaption.copyWith(
                        color: IqColors.fg3,
                      ),
                    ),
                    const SizedBox(height: IqSpace.s0p5),
                    Text(
                      brief.title,
                      style: IqWebText.bodySmall.copyWith(color: IqColors.fg),
                    ),
                    const SizedBox(height: IqSpace.s0p5),
                    _Caption(brief: brief),
                    _ViewBrief(brief: brief),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: IqSpace.s4),
            child: SizedBox(height: 1, child: ColoredBox(color: IqColors.line)),
          ),
          Text(
            'What to send',
            style: IqWebText.bodySmallStrong.copyWith(color: IqColors.fg),
          ),
          const SizedBox(height: IqSpace.s2),
          _Need(
            'Title',
            '${SubmitLimits.titleMin} to ${SubmitLimits.titleMax} characters',
            done: titleReady(draft),
          ),
          _Need(
            'Your answer',
            'At least ${SubmitLimits.answerMin} characters.',
            done: answerReady(draft),
          ),
          if (form.hasQuestions)
            _Need(
              'A few quick questions',
              questions
                  ? '${form.questions.length} questions'
                  : _questionCount(form),
              done: questions && firstUnanswered(form, draft) == null,
            ),
          if (form.acceptsFiles)
            _Need(
              'Attachments',
              'Optional. Up to ${SubmitLimits.files} files, $mb MB each.',
              done: flow.files.isNotEmpty,
            ),
          if (action case final action?) ...[
            const SizedBox(height: IqSpace.s4),
            action,
          ],
        ],
      ),
    );
  }
}

class _Caption extends ConsumerWidget {
  const _Caption({required this.brief});

  final Brief brief;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final left = timeLeft(brief.deadline, ref.watch(clockProvider)());
    return Text(
      '${rewardPool(brief.rewardPoolKobo)} · '
      '${closesIn(left, closed: !brief.isLive)}',
      style: IqWebText.metaCaption.copyWith(color: IqColors.fg2),
    );
  }
}

class _ViewBrief extends StatelessWidget {
  const _ViewBrief({required this.brief});

  final Brief brief;

  @override
  Widget build(BuildContext context) {
    return IqPressable(
      onTap: () => context.open(Routes.brief(brief.id)),
      tactile: false,
      semanticLabel: 'View the brief',
      builder: (context, pressed) => SizedBox(
        height: 32,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'View the brief',
            style: IqWebText.bodySmallStrong.copyWith(
              color: pressed ? IqColors.brandWarm : IqColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _Need extends StatelessWidget {
  const _Need(this.label, this.help, {required this.done});

  final String label;
  final String help;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: IqSpace.s1p5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: IqSpace.s0p5),
            child: IqTabletIcon(
              done ? IqTabletIcons.circleCheck : IqTabletIcons.circleDashed,
              size: 18,
              color: done ? IqColors.ok : IqColors.fg3,
            ),
          ),
          const SizedBox(width: IqSpace.s2p5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: IqWebText.bodySmall.copyWith(color: IqColors.fg),
                ),
                Text(
                  help,
                  style: IqWebText.metaCaption.copyWith(color: IqColors.fg3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
