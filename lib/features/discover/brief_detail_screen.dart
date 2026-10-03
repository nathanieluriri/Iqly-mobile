import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/brief_labels.dart';
import '../../core/deadline.dart';
import '../../core/flags.dart';
import '../../core/money.dart';
import '../../core/responsive.dart';
import '../../data/models.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/bookmark.dart';
import '../../ui/button.dart';
import '../../ui/setting_row.dart';
import '../../ui/switch.dart';
import '../../ui/top_bar.dart';
import 'discover_routes.dart';
import 'discover_state.dart';

/// B1 · Brief detail (31:665) as evolved in B12 · Brief detail · saved
/// (192:9707): the bookmark beside the top bar, the facts with only the
/// reward pool keeping its note, the "Remind me" switch, then the brief and
/// the submit bar.
class BriefDetailScreen extends ConsumerWidget {
  const BriefDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brief = ref.watch(briefDetailProvider(id)).value;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: IqColors.bg,
        body: SafeArea(
          child: CenteredContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  children: [
                    IqTopBar(
                      variant: IqTopBarVariant.page,
                      title: 'Brief',
                      onBack: () => leave(context),
                    ),
                    if (brief != null && Flags.savedBriefs)
                      Positioned(
                        right: IqSpace.s4,
                        top: IqSpace.s1p5,
                        child: _BookmarkButton(brief: brief),
                      ),
                  ],
                ),
                Expanded(
                  child: brief == null
                      ? const SizedBox.shrink()
                      : _Body(brief: brief),
                ),
                if (brief != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      IqSpace.s4,
                      IqSpace.s3,
                      IqSpace.s4,
                      IqSpace.s3,
                    ),
                    child: IqButton(
                      label: 'Submit your response',
                      width: double.infinity,
                      disabled: !brief.isLive,
                      onTap: () => context.push(Routes.submitTo(brief.id)),
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

class _BookmarkButton extends ConsumerWidget {
  const _BookmarkButton({required this.brief});

  final Brief brief;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved =
        ref.watch(savedBriefsProvider).value?.any((b) => b.id == brief.id) ??
        false;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: IqColors.card,
        shape: BoxShape.circle,
        border: Border.all(color: IqColors.brand, width: 1.5),
      ),
      child: IqBookmark(
        state: saved ? IqBookmarkState.on : IqBookmarkState.off,
        onChanged: (state) => ref
            .read(savedBriefsProvider.notifier)
            .setSaved(brief, state == IqBookmarkState.on),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.brief});

  final Brief brief;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    final left = timeLeft(brief.deadline, now);
    final closed = !brief.isLive;
    final reminders = ref.watch(closeRemindersProvider).value ?? const {};
    final canRemind =
        Flags.closeReminders && !closed && left != null && left > Duration.zero;
    final eyebrow = [
      ?brief.businessName,
      brief.tier.label,
      ?interestLabel(brief.interest),
    ].join(' · ');
    final total = brief.spotsTotal;
    final spotsLeft = brief.spotsLeft;
    final spots = spotsLeft == null
        ? 'No limit'
        : total == null
        ? '$spotsLeft left'
        : '$spotsLeft of $total left';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
      children: [
        const SizedBox(height: IqSpace.s2),
        Text(
          eyebrow.toUpperCase(),
          style: IqText.mono.copyWith(color: IqColors.fg3),
        ),
        const SizedBox(height: IqSpace.s2),
        Text(brief.title, style: IqText.title.copyWith(color: IqColors.fg)),
        const SizedBox(height: IqSpace.s6),
        _Fact(
          label: 'Reward pool',
          note: brief.winnerRule,
          value: rewardPool(brief.rewardPoolKobo),
        ),
        const _Hairline(),
        _Fact(
          label: 'Submissions close',
          value: closesInWords(left, closed: closed),
        ),
        const _Hairline(),
        _Fact(label: 'Spots', value: spots),
        if (canRemind) ...[
          const SizedBox(height: IqSpace.s4),
          IqSettingRow(
            label: 'Remind me',
            description: 'An hour before close',
            divider: false,
            state: reminders.contains(brief.id)
                ? IqSwitchState.on
                : IqSwitchState.off,
            onChanged: (state) => ref
                .read(closeRemindersProvider.notifier)
                .setReminder(brief.id, state == IqSwitchState.on),
          ),
        ],
        const SizedBox(height: IqSpace.s4),
        Text(
          'About the brief'.toUpperCase(),
          style: IqText.mono.copyWith(color: IqColors.fg3),
        ),
        const SizedBox(height: IqSpace.s2),
        Text(brief.body, style: IqText.body.copyWith(color: IqColors.fg)),
        const SizedBox(height: IqSpace.s4),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.note});

  final String label;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: IqSpace.s3),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: IqText.mono.copyWith(color: IqColors.fg3),
                ),
                if (note != null)
                  Text(
                    note!,
                    style: IqText.small.copyWith(color: IqColors.fg2),
                  ),
              ],
            ),
          ),
          const SizedBox(width: IqSpace.s3),
          Text(value, style: IqText.figureSmall.copyWith(color: IqColors.fg)),
        ],
      ),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 1, child: ColoredBox(color: IqColors.line));
}
