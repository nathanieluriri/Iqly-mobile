import 'package:flutter/widgets.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'cover_with_logo.dart';
import 'meta.dart';
import 'pressable.dart';
import 'sample_cover.dart';
import 'sample_logo.dart';

enum IqPollTileState { open, answered }

enum IqPollTileLayout { vertical, horizontal }

/// Exp/PollTile: a quick poll from a business: photo, logo, the question,
/// how long. Tapping opens the poll sheet. Answered dims the photo to .6
/// and swaps the count for a Done chip.
///
/// [meta] is the nested chip's label ("2 questions", "Answered").
class IqPollTile extends StatelessWidget {
  const IqPollTile({
    super.key,
    this.state = IqPollTileState.open,
    this.layout = IqPollTileLayout.vertical,
    this.question = 'Which flavour should we launch first?',
    this.meta,
    this.cover = const IqSampleCover(IqSampleLogoBrand.orchidFoods),
    this.logo = const IqSampleLogo(IqSampleLogoBrand.orchidFoods),
    this.onTap,
  });

  final IqPollTileState state;
  final IqPollTileLayout layout;
  final String question;
  final String? meta;
  final Widget cover;
  final Widget logo;
  final VoidCallback? onTap;

  bool get _answered => state == IqPollTileState.answered;

  Size get size => layout == IqPollTileLayout.vertical
      ? const Size(168, 214)
      : const Size(300, 98);

  Widget get _meta => _answered
      ? IqMeta(kind: IqMetaKind.done, label: meta ?? 'Answered')
      : IqMeta(kind: IqMetaKind.polls, label: meta ?? '2 questions');

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final body = layout == IqPollTileLayout.vertical ? _vertical() : _row();
    return IqPressable(
      onTap: onTap,
      semanticLabel: question,
      builder: (context, pressed) => AnimatedScale(
        scale: pressed && !reduced ? IqScale.cardPress : 1,
        duration: pressMotion(context, pressed),
        curve: IqCurves.easeOut,
        child: SizedBox.fromSize(
          size: size,
          child: LineCard(
            inset: layout == IqPollTileLayout.horizontal,
            child: body,
          ),
        ),
      ),
    );
  }

  Widget _vertical() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CoverWithLogo(
          size: const Size(168, 112),
          cover: cover,
          logo: logo,
          coverOpacity: _answered ? 0.6 : 1,
          logoOffset: const Offset(IqSpace.s3, 94),
          logoSize: 36,
          logoInset: 3,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              IqSpace.s3,
              22,
              IqSpace.s3,
              IqSpace.s3,
            ),
            child: ClipRect(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    question,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: IqText.smallStrong.copyWith(color: IqColors.fg),
                  ),
                  const SizedBox(height: IqSpace.s2),
                  _meta,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _row() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        IqSpace.s3,
        IqSpace.s3,
        IqSpace.s2p5,
        IqSpace.s3,
      ),
      child: Row(
        children: [
          CoverWithLogo(
            size: const Size.square(72),
            radius: IqRadius.xl,
            cover: cover,
            logo: logo,
            coverOpacity: _answered ? 0.6 : 1,
            logoOffset: const Offset(50, 50),
            logoSize: 28,
            logoInset: 2,
          ),
          const SizedBox(width: IqSpace.s3),
          Expanded(
            child: SizedBox(
              height: 70,
              child: ClipRect(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: IqText.bodyStrong.copyWith(color: IqColors.fg),
                    ),
                    const SizedBox(height: IqSpace.s1p5),
                    _meta,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
