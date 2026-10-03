import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/deadline.dart';
import '../../core/money.dart';
import '../../core/relative_time.dart';
import '../../core/responsive.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/top_bar.dart';
import 'submission_widgets.dart';
import 'submissions_state.dart';

/// B4 Submission detail (35:146).
class SubmissionDetailScreen extends ConsumerWidget {
  const SubmissionDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(submissionItemProvider(id)).value;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: IqColors.bg,
        body: SafeArea(
          child: CenteredContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IqTopBar(
                  variant: IqTopBarVariant.page,
                  title: 'Submission',
                  onBack: () => context.canPop()
                      ? context.pop()
                      : context.go(Routes.submissions),
                ),
                Expanded(
                  child: item == null
                      ? const SizedBox.shrink()
                      : _Body(item: item, now: ref.watch(clockProvider)()),
                ),
                if (item != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: IqSpace.s4,
                      vertical: IqSpace.s3,
                    ),
                    child: IqButton(
                      label: 'View the brief',
                      kind: IqButtonKind.secondary,
                      width: double.infinity,
                      onTap: () =>
                          context.push(Routes.brief(item.submission.briefId)),
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

class _Body extends StatelessWidget {
  const _Body({required this.item, required this.now});

  final SubmissionItem item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final brief = item.brief;
    final business = brief?.businessName ?? 'the business';
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: IqSpace.s2),
          SubmissionStatusMark(status: item.status),
          const SizedBox(height: IqSpace.s2),
          Text(
            item.submission.title,
            style: IqText.title.copyWith(color: IqColors.fg),
          ),
          const SizedBox(height: IqSpace.s2),
          Text(
            item.briefLine,
            style: IqText.small.copyWith(color: IqColors.fg2),
          ),
          const SizedBox(height: IqSpace.s6),
          _Fact('Sent', timeAgo(item.submission.createdAt, now)),
          if (brief != null) ...[
            const Hairline(),
            _Fact('Reward pool', rewardPool(brief.rewardPoolKobo)),
            const Hairline(),
            _Fact(
              'Brief closes',
              closesInWords(
                timeLeft(brief.deadline, now),
                closed: !brief.isLive,
              ),
            ),
          ],
          const SizedBox(height: IqSpace.s4),
          Text(
            'Your answer'.toUpperCase(),
            style: IqText.mono.copyWith(color: IqColors.fg3),
          ),
          const SizedBox(height: IqSpace.s2),
          Text(
            item.submission.body,
            style: IqText.body.copyWith(color: IqColors.fg),
          ),
          if (item.underReview) ...[
            const SizedBox(height: IqSpace.s4),
            Text(
              'Results land here when $business decides.',
              style: IqText.small.copyWith(color: IqColors.fg3),
            ),
          ],
          const SizedBox(height: IqSpace.s4),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: SizedBox(
        height: 43,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: IqText.mono.copyWith(color: IqColors.fg3),
              ),
            ),
            const SizedBox(width: IqSpace.s3),
            Text(value, style: IqText.figureSmall.copyWith(color: IqColors.fg)),
          ],
        ),
      ),
    );
  }
}
