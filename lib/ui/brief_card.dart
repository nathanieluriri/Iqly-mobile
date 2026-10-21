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
/// clipped to the Figma frame (the logo to a circle). [time] adds the Time
/// chip ("2 min") after the prize, as Figma orders the facts, unless [meta]
/// already carries one.
///
/// Figma over brief: the closing tint sits under the media, so the logo
/// stays whole over it.
///
/// Figma over the first build: the body grows with a two-line ask (409:91
/// is 124 tall, 409:95 is 327) and the meta chips wrap, as the Figma meta
/// frame does.
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
    this.time,
    this.onTap,
    this.widthOverride,
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
  final String? time;
  final VoidCallback? onTap;

  /// The tablet grid's card (Exp/BriefCard local, 1637:9376) is a Carousel
  /// that fills its column.
  final double? widthOverride;

  double get width =>
      widthOverride ?? (kind == IqBriefCardKind.carousel ? 272 : 358);

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
      tactile: false,
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

  List<Widget> get _facts {
    final time = this.time;
    if (time == null ||
        meta.any((m) => m is IqMeta && m.kind == IqMetaKind.time)) {
      return meta;
    }
    final at = meta.indexWhere(
      (m) => !(m is IqMeta && m.kind == IqMetaKind.reward),
    );
    return [...meta]..insert(
      at < 0 ? meta.length : at,
      IqMeta(kind: IqMetaKind.time, label: time),
    );
  }

  Widget _metaRow(double top) {
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: Wrap(
        spacing: IqSpace.s1p5,
        runSpacing: IqSpace.s1p5,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: _facts,
      ),
    );
  }

  Widget _stacked() {
    final feature = kind == IqBriefCardKind.feature;
    final mediaHeight = feature ? 200.0 : 164.0;
    final bodyHeight = feature ? 107.0 : 127.0;
    final logoSize = feature ? 48.0 : 40.0;
    final column = Column(
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
          padding: const EdgeInsets.fromLTRB(
            IqSpace.s4,
            3,
            IqSpace.s4,
            IqSpace.s4,
          ),
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
      ],
    );
    if (!closingSoon) return column;
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: mediaHeight - 1,
          bottom: 0,
          child: const ColoredBox(color: IqColors.accentSoft),
        ),
        column,
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
        ],
      ),
    );
  }
}
