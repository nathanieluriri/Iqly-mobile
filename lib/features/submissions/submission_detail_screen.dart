import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/deadline.dart';
import '../../core/motion.dart';
import '../../core/navigation.dart';
import '../../core/responsive.dart';
import '../../core/transitions.dart';
import '../../data/outcomes_data.dart' show BusinessNote;
import '../../data/outcomes_service.dart' show businessNoteShownProvider;
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/brief_hero.dart';
import '../../ui/button.dart';
import '../../ui/meta.dart';
import '../../ui/section_title.dart';
import '../../ui/skeleton.dart';
import '../../ui/top_bar.dart';
import '../outcomes/business_note.dart';
import 'brief_art.dart';
import 'submission_files.dart';
import 'submissions_state.dart';

/// B4 Submission detail (35:146), a sub page: the brief's photo with the
/// business logo, who it is for and the status, your title, when you sent
/// it and the brief, the pool and deadline, your answer and when results
/// come, what the person sent with it (no frame draws the files: they keep
/// the submit flow's attachments group), and the business's note once its
/// results are out (contract 12.2). View the brief opens Brief detail. From a card the submission is
/// already on the device, so it draws from the first frame; only a cold
/// open waits behind LoadingGate.
class SubmissionDetailScreen extends ConsumerWidget {
  const SubmissionDetailScreen({super.key, required this.id});

  final String id;

  static const double heroHeight = 160;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loaded = ref.watch(submissionItemProvider(id));
    final item = loaded.value;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: IqColors.bg,
        body: SafeArea(
          maintainBottomViewPadding: true,
          child: CenteredContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IqTopBar(
                  variant: IqTopBarVariant.page,
                  title: 'Submission',
                  onBack: () => context.canPop()
                      ? context.pop()
                      : context.go(
                          Routes.submissions,
                          extra: NavDirection.back,
                        ),
                ),
                Expanded(
                  child: LoadingGate(
                    loading: item == null && loaded.isLoading,
                    skeleton: const _Skeleton(),
                    child: item != null
                        ? _Body(
                            item: item,
                            now: ref.watch(clockProvider)(),
                            note: ref.watch(businessNoteShownProvider)
                                ? item.submission.note
                                : null,
                          )
                        : loaded.hasError
                        ? Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: IqSpace.s4,
                            ),
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: IqBanner(
                                kind: IqBannerKind.error,
                                title: 'Couldn’t load. Check your connection.',
                                action: 'Try again',
                                onAction: () =>
                                    ref.invalidate(submissionItemProvider(id)),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
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
                      showIcon: false,
                      width: double.infinity,
                      onTap: () => context.open(
                        Routes.brief(item.submission.briefId),
                        extra: item.brief,
                      ),
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

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        Widget line(double share) => IqSkeleton(
          kind: IqSkeletonKind.line,
          width: (box.maxWidth - IqSpace.s8) * share,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: SubmissionDetailScreen.heroHeight),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                IqSpace.s4,
                IqSpace.s8,
                IqSpace.s4,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  line(0.3),
                  const SizedBox(height: IqSpace.s3),
                  line(1),
                  const SizedBox(height: IqSpace.s2),
                  line(0.7),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.item, required this.now, this.note});

  final SubmissionItem item;
  final DateTime now;

  /// The business's note to the author, once its results are out.
  final BusinessNote? note;

  @override
  Widget build(BuildContext context) {
    final brief = item.brief;
    Widget gap() => const SizedBox(height: IqSpace.s3);
    return Stagger(
      move: StaggerMove.settle,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IqBriefHero(
              height: SubmissionDetailScreen.heroHeight,
              showDots: false,
              cover: briefCover(brief),
              logo: briefLogo(brief),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                IqSpace.s4,
                0,
                IqSpace.s4,
                IqSpace.s6,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 66),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            brief?.businessName ?? 'Private business',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: IqText.smallStrong.copyWith(
                              color: IqColors.fg,
                            ),
                          ),
                        ),
                        const SizedBox(width: IqSpace.s2p5),
                        IqMeta(kind: IqMetaKind.time, label: item.status.label),
                      ],
                    ),
                  ),
                  gap(),
                  StaggerItem(
                    index: 0,
                    child: Text(
                      item.submission.title,
                      style: IqText.headline.copyWith(color: IqColors.fg),
                    ),
                  ),
                  gap(),
                  StaggerItem(
                    index: 1,
                    child: Text(
                      [
                        sentAgo(item.submission.createdAt, now),
                        if (brief != null) 'For: ${brief.title}',
                      ].join(' · '),
                      style: IqText.small.copyWith(color: IqColors.fg3),
                    ),
                  ),
                  if (brief != null) ...[
                    gap(),
                    StaggerItem(
                      index: 2,
                      child: Row(
                        children: [
                          IqMeta(
                            kind: IqMetaKind.reward,
                            label: nairaShort(brief.rewardPoolKobo),
                          ),
                          const SizedBox(width: IqSpace.s1p5),
                          IqMeta(
                            kind: IqMetaKind.deadline,
                            label: closesIn(
                              timeLeft(brief.deadline, now),
                              closed: !brief.isLive,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  gap(),
                  StaggerItem(
                    index: 3,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: IqSpace.s4,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: IqColors.line),
                        borderRadius: BorderRadius.circular(IqRadius.xl2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your answer',
                            style: IqText.smallStrong.copyWith(
                              color: IqColors.fg3,
                            ),
                          ),
                          const SizedBox(height: IqSpace.s1p5),
                          Text(
                            item.submission.body,
                            style: IqText.body.copyWith(color: IqColors.fg),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (item.submission.files case final files
                      when files.isNotEmpty) ...[
                    gap(),
                    StaggerItem(
                      index: 4,
                      child: SubmissionFiles(
                        submissionId: item.submission.id,
                        files: files,
                      ),
                    ),
                  ],
                  if (note case final note?) ...[
                    gap(),
                    const StaggerItem(
                      index: 4,
                      child: IqSectionTitle(
                        title: 'A note from the business',
                        showCount: false,
                        showLink: false,
                      ),
                    ),
                    gap(),
                    StaggerItem(
                      index: 5,
                      child: BusinessNoteView(
                        note: note,
                        brief: brief,
                        now: now,
                      ),
                    ),
                  ],
                  if (item.underReview) ...[
                    gap(),
                    StaggerItem(
                      index: 4,
                      child: Text(
                        'Results after the brief closes.',
                        style: IqText.small.copyWith(color: IqColors.fg3),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
