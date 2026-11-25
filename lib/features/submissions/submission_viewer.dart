import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/responsive.dart';
import '../../core/transitions.dart';
import '../../theme/theme.dart';
import '../../ui/brief_hero.dart';
import '../../ui/top_bar.dart';
import '../shell/tablet_sheet.dart';
import 'brief_art.dart';
import 'deliverable_body.dart';
import 'submissions_state.dart';

/// The original brief and the complete answer without leaving the result.
Future<void> showSubmissionViewer(BuildContext context, SubmissionItem item) {
  final root = Navigator.of(context, rootNavigator: true).context;
  if (Layout.isTablet(root)) {
    return showTabletDialog<void>(
      root,
      builder: (_) => SubmissionViewer(item: item),
      width: 560,
    );
  }
  return showIqSheet<void>(
    root,
    (_) => SubmissionViewer(item: item),
    scrim: IqScrim.sheet,
  );
}

class SubmissionViewer extends StatelessWidget {
  const SubmissionViewer({super.key, required this.item});

  final SubmissionItem item;

  @override
  Widget build(BuildContext context) {
    final tablet = Layout.isTablet(context);
    final brief = item.brief;
    final pairs = parseDeliverablePairs(item.submission.body);
    return Material(
      color: IqColors.card,
      clipBehavior: Clip.antiAlias,
      borderRadius: tablet
          ? BorderRadius.zero
          : const BorderRadius.vertical(top: Radius.circular(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (tablet)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                IqSpace.s5,
                IqSpace.s3,
                IqSpace.s3,
                IqSpace.s2,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Your submission',
                      style: IqText.title.copyWith(color: IqColors.fg),
                    ),
                  ),
                  const TabletClose(),
                ],
              ),
            )
          else
            IqTopBar(
              variant: IqTopBarVariant.sheet,
              title: 'Your submission',
              onClose: () {
                Navigator.of(context).maybePop();
              },
            ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                IqSpace.s5,
                tablet ? IqSpace.s3 : IqSpace.s2,
                IqSpace.s5,
                IqSpace.s5,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (brief != null) ...[
                    IqBriefHero(
                      height: 176,
                      showDots: false,
                      showLogo: false,
                      cover: briefCover(brief),
                      logo: briefLogo(brief),
                    ),
                    const SizedBox(height: IqSpace.s4),
                    Text(
                      brief.title,
                      style: IqText.headline.copyWith(color: IqColors.fg),
                    ),
                    const SizedBox(height: IqSpace.s3),
                    Row(
                      children: [
                        SizedBox.square(
                          dimension: 40,
                          child: ClipOval(child: briefLogo(brief, size: 40)),
                        ),
                        const SizedBox(width: IqSpace.s3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Posted by',
                                style: IqText.small.copyWith(
                                  color: IqColors.fg3,
                                ),
                              ),
                              Text(
                                brief.businessName ?? 'Private business',
                                style: IqText.bodyStrong.copyWith(
                                  color: IqColors.fg,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (brief.body.trim().isNotEmpty) ...[
                      const SizedBox(height: IqSpace.s5),
                      _Section(title: 'The brief', child: Text(brief.body)),
                    ],
                  ],
                  const SizedBox(height: IqSpace.s5),
                  _Section(
                    title: 'Your submission',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          item.submission.title,
                          style: IqText.bodyStrong.copyWith(color: IqColors.fg),
                        ),
                        const SizedBox(height: IqSpace.s4),
                        for (final (index, pair) in pairs.indexed) ...[
                          if (index > 0) ...[
                            const SizedBox(height: IqSpace.s4),
                            const Divider(color: IqColors.line, height: 1),
                            const SizedBox(height: IqSpace.s4),
                          ],
                          if (pair.prompt case final prompt?) ...[
                            Text(
                              pairs.length == 1
                                  ? 'Deliverable'
                                  : 'Deliverable ${index + 1}',
                              style: IqText.smallStrong.copyWith(
                                color: IqColors.brand,
                              ),
                            ),
                            const SizedBox(height: IqSpace.s1),
                            Text(
                              prompt,
                              style: IqText.bodyStrong.copyWith(
                                color: IqColors.fg,
                              ),
                            ),
                            const SizedBox(height: IqSpace.s2),
                          ],
                          Text(
                            pair.answer,
                            style: IqText.body.copyWith(color: IqColors.fg2),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: tablet
                ? IqSpace.s4
                : math.max(MediaQuery.viewPaddingOf(context).bottom, 34),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: IqText.title.copyWith(color: IqColors.fg)),
        const SizedBox(height: IqSpace.s2),
        DefaultTextStyle(
          style: IqText.body.copyWith(color: IqColors.fg2),
          child: child,
        ),
      ],
    );
  }
}
