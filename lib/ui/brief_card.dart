import 'package:flutter/widgets.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'bookmark.dart';
import 'cover_with_logo.dart';
import 'meta.dart';
import 'pressable.dart';
import 'sample_cover.dart';
import 'sample_logo.dart';

enum IqBriefCardKind { feature, carousel, row }

/// Exp/BriefCard: the image-led brief card. Photo first, the business logo
/// on the image edge, the business name, the ask (two lines), then up to
/// three [meta] chips. No eyebrows or body copy. [closingSoon] lays a warm
/// tint under the text and an orange outline; these lead the Briefs list.
///
/// [cover] and [logo] are the Figma instance swaps: any image fills them,
/// clipped to the Figma frame (the logo to a circle).
class IqBriefCard extends StatelessWidget {
  const IqBriefCard({
    super.key,
    this.kind = IqBriefCardKind.feature,
    this.brand = 'Sunline',
    this.title = 'A tagline for a solar kiosk network',
    this.cover = const IqSampleCover(IqSampleLogoBrand.sunline),
    this.logo = const IqSampleLogo(IqSampleLogoBrand.sunline),
    this.meta = const [
      IqMeta(kind: IqMetaKind.reward, label: '₦150,000'),
      IqMeta(kind: IqMetaKind.time, label: '5 min'),
      IqMeta(kind: IqMetaKind.urgent, label: '6h left'),
    ],
    this.showBookmark = false,
    this.bookmark = IqBookmarkState.off,
    this.onBookmarkChanged,
    this.closingSoon = false,
    this.onTap,
  });

  final IqBriefCardKind kind;
  final String brand;
  final String title;
  final Widget cover;
  final Widget logo;
  final List<Widget> meta;
  final bool showBookmark;
  final IqBookmarkState bookmark;
  final ValueChanged<IqBookmarkState>? onBookmarkChanged;
  final bool closingSoon;
  final VoidCallback? onTap;

  double get width => kind == IqBriefCardKind.carousel ? 272 : 358;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final row = kind == IqBriefCardKind.row;
    final inset = row ? 4.0 : 6.0;
    final card = LineCard(
      stroke: closingSoon ? IqColors.accent : IqColors.line,
      strokeWidth: closingSoon ? 2 : 1,
      overlay: [
        if (showBookmark)
          Positioned(
            top: inset,
            right: inset,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: IqColors.card,
                    shape: BoxShape.circle,
                  ),
                ),
                IqBookmark(state: bookmark, onChanged: onBookmarkChanged),
              ],
            ),
          ),
      ],
      inset: row,
      child: row ? _row() : _stacked(),
    );
    return IqPressable(
      onTap: onTap,
      semanticLabel: '$brand, $title',
      builder: (context, pressed) => AnimatedScale(
        scale: pressed && !reduced ? IqScale.cardPress : 1,
        duration: pressMotion(context, pressed),
        curve: IqCurves.easeOut,
        child: SizedBox(width: width, child: card),
      ),
    );
  }

  Widget _metaRow(double top) {
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: Wrap(
        spacing: IqSpace.s1p5,
        runSpacing: IqSpace.s1p5,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: meta,
      ),
    );
  }

  Widget _stacked() {
    final feature = kind == IqBriefCardKind.feature;
    final mediaHeight = feature ? 200.0 : 164.0;
    final bodyHeight = feature ? 107.0 : 127.0;
    final logoSize = feature ? 48.0 : 40.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CoverWithLogo(
          size: Size(width, mediaHeight),
          cover: cover,
          logo: logo,
          logoOffset: Offset(IqSpace.s3, mediaHeight - logoSize / 2),
          logoSize: logoSize,
          logoInset: 3,
        ),
        Container(
          constraints: BoxConstraints(minHeight: bodyHeight),
          color: closingSoon ? IqColors.accentSoft : null,
          padding: const EdgeInsets.fromLTRB(
            IqSpace.s4,
            3,
            IqSpace.s4,
            IqSpace.s4,
          ),
          child: ClipRect(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.only(left: logoSize, bottom: 6),
                  child: Text(
                    brand,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: IqText.smallStrong.copyWith(color: IqColors.fg2),
                  ),
                ),
                const SizedBox(height: IqSpace.s1),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: IqText.cardTitle.copyWith(color: IqColors.fg),
                ),
                const SizedBox(height: IqSpace.s1),
                _metaRow(IqSpace.s2),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _row() {
    return Container(
      color: closingSoon ? IqColors.accentSoft : null,
      padding: const EdgeInsets.all(IqSpace.s3),
      child: Row(
        children: [
          CoverWithLogo(
            size: const Size.square(72),
            radius: IqRadius.xl,
            cover: cover,
            logo: logo,
            logoOffset: const Offset(50, 50),
            logoSize: 28,
            logoInset: 2,
          ),
          const SizedBox(width: IqSpace.s3),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 77),
              child: ClipRect(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      brand,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: IqText.smallStrong.copyWith(color: IqColors.fg2),
                    ),
                    const SizedBox(height: IqSpace.s1),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: IqText.bodyStrong.copyWith(color: IqColors.fg),
                    ),
                    const SizedBox(height: IqSpace.s1),
                    _metaRow(IqSpace.s1),
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
