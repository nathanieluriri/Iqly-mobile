import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';

/// Figma Kind. The four apps carry their official marks; [more] hands off to
/// the system share sheet.
enum IqShareTargetKind {
  whatsapp('WhatsApp', mark: 'share-whatsapp'),
  instagram('Instagram', mark: 'share-instagram'),
  x('X', mark: 'share-x'),
  telegram('Telegram', mark: 'share-telegram'),
  more('More…', icon: IqIcons.share),
  copyLink('Copy link', icon: IqIcons.link),
  saveImage('Save image', icon: IqIcons.download);

  const IqShareTargetKind(this.label, {this.mark, this.icon});

  final String label;
  final String? mark;
  final IqIcons? icon;
}

/// Exp/ShareTarget: a 56 px tile with the app mark (official, never
/// recoloured) or a brush icon, label under it, 72 wide.
///
/// Figma over brief: the tile is card white, not paper.
/// Figma bug not followed: Save image hides its icon fill; it draws the download icon in brand.
class IqShareTarget extends StatelessWidget {
  const IqShareTarget({
    super.key,
    this.kind = IqShareTargetKind.whatsapp,
    this.onTap,
  });

  final IqShareTargetKind kind;
  final VoidCallback? onTap;

  static const double width = 72;
  static const double tile = 56;
  static const Duration pressDuration = Duration(milliseconds: 100);

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : pressDuration;
    final mark = kind.mark;
    return IqPressable(
      onTap: onTap,
      semanticLabel: kind.label,
      builder: (context, pressed) => SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: duration,
              curve: Curves.easeOut,
              width: tile,
              height: tile,
              alignment: Alignment.center,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: pressed ? IqColors.tint : IqColors.card,
                border: Border.all(color: IqColors.line),
                borderRadius: BorderRadius.circular(16),
              ),
              child: mark != null
                  ? SvgPicture.asset(
                      'assets/brand/$mark.svg',
                      width: 34,
                      excludeFromSemantics: true,
                    )
                  : IqIcon(kind.icon!, size: 26, color: IqColors.brand),
            ),
            const SizedBox(height: IqSpace.s2),
            Text(
              kind.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: IqText.small.copyWith(color: IqColors.fg),
            ),
          ],
        ),
      ),
    );
  }
}
