import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/transitions.dart';
import '../../theme/theme.dart';
import '../../ui/text_link.dart';
import 'deliverable_body.dart';

/// The answer card on a submission: each deliverable named, the answer
/// clipped, and See more for the full pair in a sheet.
class SubmissionAnswerCard extends StatelessWidget {
  const SubmissionAnswerCard({super.key, required this.body});

  final String body;

  @override
  Widget build(BuildContext context) {
    final pairs = parseDeliverablePairs(body);
    if (pairs.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: IqColors.line),
        borderRadius: BorderRadius.circular(IqRadius.xl2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (index, pair) in pairs.indexed) ...[
            if (index > 0) ...[
              const SizedBox(height: IqSpace.s4),
              const SizedBox(
                height: 1,
                width: double.infinity,
                child: ColoredBox(color: IqColors.line),
              ),
              const SizedBox(height: IqSpace.s4),
            ],
            _PairPreview(index: index, pair: pair, count: pairs.length),
          ],
        ],
      ),
    );
  }
}

class _PairPreview extends StatelessWidget {
  const _PairPreview({
    required this.index,
    required this.pair,
    required this.count,
  });

  final int index;
  final DeliverablePair pair;
  final int count;

  @override
  Widget build(BuildContext context) {
    final more = needsSeeMore(pair);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pair.prompt != null) ...[
          Text(
            count == 1 ? 'Deliverable' : 'Deliverable ${index + 1}',
            style: IqText.smallStrong.copyWith(color: IqColors.brand),
          ),
          const SizedBox(height: IqSpace.s1),
          Text(
            pair.prompt!,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: IqText.bodyStrong.copyWith(color: IqColors.fg),
          ),
          const SizedBox(height: IqSpace.s1p5),
        ],
        Text(
          pair.answer,
          maxLines: pair.prompt == null ? 6 : 4,
          overflow: TextOverflow.ellipsis,
          style: IqText.body.copyWith(color: IqColors.fg2),
        ),
        if (more)
          IqTextLink(
            label: 'See more',
            showIcon: false,
            onTap: () => showSubmissionAnswerSheet(
              context,
              index: index,
              pair: pair,
              count: count,
            ),
          ),
      ],
    );
  }
}

Future<void> showSubmissionAnswerSheet(
  BuildContext context, {
  required int index,
  required DeliverablePair pair,
  required int count,
}) {
  return showIqSheet<void>(
    context,
    (sheet) => Material(
      type: MaterialType.transparency,
      child: SubmissionAnswerSheet(index: index, pair: pair, count: count),
    ),
    scrim: IqScrim.sheet,
  );
}

/// The full deliverable and its answer, scrollable.
class SubmissionAnswerSheet extends StatelessWidget {
  const SubmissionAnswerSheet({
    super.key,
    required this.index,
    required this.pair,
    required this.count,
  });

  final int index;
  final DeliverablePair pair;
  final int count;

  static const double radius = 24;
  static const double homeIndicator = 34;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    final maxH = MediaQuery.sizeOf(context).height * 0.92;
    final title = pair.prompt == null
        ? 'Your answer'
        : count == 1
        ? 'Deliverable'
        : 'Deliverable ${index + 1}';
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: IqColors.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  top: IqSpace.s2,
                  bottom: IqSpace.s1,
                ),
                child: Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: IqColors.line2,
                      borderRadius: BorderRadius.circular(IqRadius.full),
                    ),
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    IqSpace.s5,
                    IqSpace.s2p5,
                    IqSpace.s5,
                    IqSpace.s5,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: IqText.smallStrong.copyWith(
                          color: IqColors.brand,
                        ),
                      ),
                      if (pair.prompt != null) ...[
                        const SizedBox(height: IqSpace.s2),
                        Text(
                          pair.prompt!,
                          style: IqText.title.copyWith(color: IqColors.fg),
                        ),
                        const SizedBox(height: IqSpace.s3),
                      ] else
                        const SizedBox(height: IqSpace.s2),
                      Text(
                        pair.answer,
                        style: IqText.body.copyWith(color: IqColors.fg2),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: math.max(inset, homeIndicator)),
            ],
          ),
        ),
      ),
    );
  }
}
