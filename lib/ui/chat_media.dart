import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';

enum IqChatMediaKind { image, voice, file }

/// Light sits in a bubble on paper; Ink in the person's own brand bubble.
enum IqChatMediaTone { light, ink }

/// Exp/ChatMedia: what rides in a chat bubble. Image is the picture, 172
/// tall with radius 6; Voice the play disc, the 26 bar waveform (the part
/// played full, the rest faint) and the length; File a document tile with
/// its name and facts. [onTap] opens it.
class IqChatMedia extends StatelessWidget {
  const IqChatMedia({
    super.key,
    this.kind = IqChatMediaKind.voice,
    this.tone = IqChatMediaTone.light,
    this.image,
    this.width = 210,
    this.duration = '0:24',
    this.played = 10,
    this.name = 'Withdrawal receipt.pdf',
    this.meta = 'PDF · 1 page · 64 KB',
    this.fileIcon = IqIcons.document,
    this.onTap,
    this.semanticLabel,
  });

  final IqChatMediaKind kind;
  final IqChatMediaTone tone;

  /// The picture, filling the 172 pt frame.
  final Widget? image;
  final double width;
  final String duration;

  /// How many of the waveform's bars read as played.
  final int played;
  final String name;
  final String meta;
  final IqIcons fileIcon;
  final VoidCallback? onTap;
  final String? semanticLabel;

  /// The bars' heights, as Figma draws the recording.
  static const bars = <double>[
    6, 10, 15, 9, 18, 22, 13, 17, 24, 15, 10, 20, 26, //
    18, 12, 8, 16, 22, 14, 10, 18, 12, 8, 6, 10, 6,
  ];

  bool get _ink => tone == IqChatMediaTone.ink;

  @override
  Widget build(BuildContext context) {
    final body = switch (kind) {
      IqChatMediaKind.image => _image(),
      IqChatMediaKind.voice => _voice(),
      IqChatMediaKind.file => _file(),
    };
    final tap = onTap;
    if (tap == null) return body;
    return IqPressable(
      semanticLabel: semanticLabel ?? name,
      onTap: tap,
      builder: (context, pressed) => PressDim(pressed: pressed, child: body),
    );
  }

  Widget _image() => ClipRRect(
    borderRadius: BorderRadius.circular(IqRadius.sm),
    child: SizedBox(
      width: width,
      height: 172,
      child: image ?? const ColoredBox(color: IqColors.secondary),
    ),
  );

  Widget _voice() {
    final ink = _ink ? IqColors.sidebarFg : IqColors.brand;
    return Padding(
      padding: const EdgeInsets.all(IqSpace.s1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: ink, shape: BoxShape.circle),
            child: IqIcon(
              IqIcons.play,
              size: 18,
              color: _ink ? IqColors.brand : IqColors.primaryFg,
            ),
          ),
          const SizedBox(width: IqSpace.s2p5),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 128,
                height: 26,
                child: Row(
                  children: [
                    for (final (i, height) in bars.indexed) ...[
                      if (i > 0) const SizedBox(width: IqSpace.s0p5),
                      Opacity(
                        opacity: _ink && i >= played ? 0.4 : 1,
                        child: Container(
                          width: 3,
                          height: height,
                          decoration: BoxDecoration(
                            color: _ink || i < played ? ink : IqColors.line2,
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: IqSpace.s1),
              Opacity(
                opacity: _ink ? 0.7 : 1,
                child: Text(
                  duration,
                  style: IqText.small.copyWith(
                    color: _ink ? IqColors.sidebarFg : IqColors.fg3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: IqSpace.s1),
        ],
      ),
    );
  }

  Widget _file() => Container(
    width: width,
    padding: const EdgeInsets.fromLTRB(IqSpace.s2, 8, IqSpace.s2p5, 8),
    decoration: BoxDecoration(
      color: _ink ? IqColors.brandDark : IqColors.secondary,
      borderRadius: BorderRadius.circular(IqRadius.sm),
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _ink ? IqColors.sidebarFg : IqColors.card,
            borderRadius: BorderRadius.circular(IqRadius.sm),
          ),
          child: IqIcon(fileIcon, size: 20, color: IqColors.brand),
        ),
        const SizedBox(width: IqSpace.s2p5),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: IqText.smallStrong.copyWith(
                  color: _ink ? IqColors.sidebarFg : IqColors.fg,
                ),
              ),
              const SizedBox(height: IqSpace.s0p5),
              Text(
                meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: IqText.small.copyWith(
                  color: _ink ? IqColors.sidebarFg : IqColors.fg2,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
