import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';
import 'spinner.dart';

enum IqChatMediaKind { image, video, voice, file }

/// Light sits in a bubble on paper; Ink in the person's own brand bubble.
enum IqChatMediaTone { light, ink }

/// Ready shows the file; Loading is a picture or video on its way (down or
/// up), the disc over it turning or filling with [IqChatMedia.progress];
/// Failed offers Try again ([IqChatMedia.onRetry]).
enum IqChatMediaState { ready, loading, failed }

/// Exp/ChatMedia: what rides in a chat bubble. Image is the picture, 172
/// tall with radius 6; Voice the play disc, the 26 bar waveform (the part
/// played full, the rest faint) and the length; File a document tile with
/// its name and facts. [onTap] opens it.
///
/// Not in Figma, the app's own: Video is a recording's first frame
/// ([image]) in the picture's frame with the play disc and its length, and
/// the Loading and Failed states of a picture or a video, so a file never
/// shows as an empty grey box.
class IqChatMedia extends StatelessWidget {
  const IqChatMedia({
    super.key,
    this.kind = IqChatMediaKind.voice,
    this.tone = IqChatMediaTone.light,
    this.state = IqChatMediaState.ready,
    this.image,
    this.width = 210,
    this.duration = '0:24',
    this.played = 10,
    this.progress,
    this.name = 'Withdrawal receipt.pdf',
    this.meta = 'PDF · 1 page · 64 KB',
    this.fileIcon = IqIcons.document,
    this.onTap,
    this.onRetry,
    this.semanticLabel,
  });

  final IqChatMediaKind kind;
  final IqChatMediaTone tone;
  final IqChatMediaState state;

  /// The picture, or a video's first frame, filling the 172 pt frame.
  final Widget? image;
  final double width;
  final String duration;

  /// How many of the waveform's bars read as played.
  final int played;

  /// How far a Loading file is, 0 to 1; null while that is not known.
  final double? progress;
  final String name;
  final String meta;
  final IqIcons fileIcon;
  final VoidCallback? onTap;
  final VoidCallback? onRetry;
  final String? semanticLabel;

  /// The bars' heights, as Figma draws the recording.
  static const bars = <double>[
    6, 10, 15, 9, 18, 22, 13, 17, 24, 15, 10, 20, 26, //
    18, 12, 8, 16, 22, 14, 10, 18, 12, 8, 6, 10, 6,
  ];

  static const double frameHeight = 172;

  bool get _ink => tone == IqChatMediaTone.ink;

  @override
  Widget build(BuildContext context) {
    final body = switch (kind) {
      IqChatMediaKind.image || IqChatMediaKind.video => _frame(),
      IqChatMediaKind.voice => _voice(),
      IqChatMediaKind.file => _file(),
    };
    final tap = state == IqChatMediaState.failed ? onRetry : onTap;
    if (tap == null) {
      return Semantics(
        label: state == IqChatMediaState.loading ? 'Loading' : null,
        child: body,
      );
    }
    return IqPressable(
      semanticLabel: state == IqChatMediaState.failed
          ? 'Try again'
          : semanticLabel ?? name,
      onTap: tap,
      builder: (context, pressed) => PressDim(pressed: pressed, child: body),
    );
  }

  Widget _frame() {
    final video = kind == IqChatMediaKind.video;
    final picture =
        image ??
        ColoredBox(color: video ? IqColors.brandDark : IqColors.secondary);
    return ClipRRect(
      borderRadius: BorderRadius.circular(IqRadius.sm),
      child: SizedBox(
        width: width,
        height: frameHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            picture,
            if (state == IqChatMediaState.ready && video) ...[
              const Center(child: _Disc(child: _Play())),
              if (duration.isNotEmpty)
                Positioned(
                  left: IqSpace.s2,
                  bottom: IqSpace.s2,
                  child: _Stamp(duration),
                ),
            ],
            if (state == IqChatMediaState.loading)
              Center(child: _Disc(progress: progress, child: null)),
            if (state == IqChatMediaState.failed)
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Disc(
                      child: IqIcon(
                        IqIcons.refresh,
                        size: 20,
                        color: IqColors.brand,
                      ),
                    ),
                    SizedBox(height: IqSpace.s1p5),
                    _Stamp('Try again'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

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

/// The 44 paper disc over a picture: the play mark, Try again, or the
/// wait, its ring filling with [progress] once that is known.
class _Disc extends StatelessWidget {
  const _Disc({required this.child, this.progress});

  final Widget? child;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final progress = this.progress;
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: IqColors.card,
        shape: BoxShape.circle,
        boxShadow: IqShadows.xs,
      ),
      child:
          child ??
          (progress == null
              ? const IqSpinner(color: IqColors.brand, size: 20)
              : SizedBox.square(
                  dimension: 32,
                  child: CircularProgressIndicator(
                    value: progress.clamp(0.02, 1),
                    strokeWidth: 3,
                    color: IqColors.brand,
                    backgroundColor: IqColors.line,
                    strokeCap: StrokeCap.round,
                  ),
                )),
    );
  }
}

class _Play extends StatelessWidget {
  const _Play();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(left: 2),
    child: IqIcon(IqIcons.play, size: 20, color: IqColors.brand),
  );
}

/// A short label on a picture: a video's length, or Try again.
class _Stamp extends StatelessWidget {
  const _Stamp(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: IqSpace.s2, vertical: 2),
    decoration: BoxDecoration(
      color: IqColors.fg.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(IqRadius.full),
    ),
    child: Text(
      text,
      style: IqText.smallStrong.copyWith(color: IqColors.primaryFg),
    ),
  );
}
