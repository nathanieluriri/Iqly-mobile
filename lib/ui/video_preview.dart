import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';
import 'tilt.dart';

enum IqVideoPreviewState { ready, uploading, failed }

/// Exp/VideoPreview: the uploaded recording as a polaroid. An ink thumbnail
/// with a tilted play sticker, the duration stamp and a remove sticker, over
/// a caption with the file name and a meta line. Uploading fills a thread
/// with [progress]; Failed offers Retry. Fills its parent's width (358 in
/// Figma). [thumbnail] replaces the phone silhouette with the real frame.
///
/// [onPlay] works from the moment the upload finishes (the sticker scales
/// .92 while pressed); [onRemove] should open Exp/ConfirmSheet before
/// anything is deleted. Upload to ready pops the play sticker in (.6 to 1,
/// 220 ms ease-out) and slides the duration stamp up 6 px. Reduced motion:
/// fades only.
///
/// Figma over its note: the duration stamp sits below the clipped thumbnail
/// in the master; it is placed bottom left, 12 px in, as the note intends.
/// Figma over brief: Retry uses Color/primary.
/// Figma over the icon rule: the close icon is 18 px and the arrow 14 px.
class IqVideoPreview extends StatefulWidget {
  const IqVideoPreview({
    super.key,
    this.state = IqVideoPreviewState.ready,
    this.name = 'kudi-box-signup.mp4',
    this.duration = '0:42',
    this.meta,
    this.progress = 0.64,
    this.thumbnail,
    this.onPlay,
    this.onRemove,
    this.onRetry,
  });

  final IqVideoPreviewState state;
  final String name;
  final String duration;
  final String? meta;
  final double progress;
  final Widget? thumbnail;
  final VoidCallback? onPlay;
  final VoidCallback? onRemove;
  final VoidCallback? onRetry;

  static const Duration pop = Duration(milliseconds: 220);
  static const Duration press = Duration(milliseconds: 120);

  @override
  State<IqVideoPreview> createState() => _IqVideoPreviewState();
}

class _IqVideoPreviewState extends State<IqVideoPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ready = AnimationController(
    vsync: this,
    duration: IqVideoPreview.pop,
    value: 1,
  );

  bool get _reduced => MediaQuery.disableAnimationsOf(context);

  @override
  void didUpdateWidget(IqVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state == IqVideoPreviewState.ready &&
        oldWidget.state != IqVideoPreviewState.ready) {
      _ready.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ready.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: IqColors.card,
        borderRadius: BorderRadius.circular(IqRadius.xl2),
        border: Border.all(color: IqColors.brandLine2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(IqRadius.xl2 - 1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [_thumbnail(), _caption()],
        ),
      ),
    );
  }

  Widget _thumbnail() {
    final state = widget.state;
    final reduced = _reduced;
    final pop = CurvedAnimation(parent: _ready, curve: Curves.easeOut);
    return SizedBox(
      height: 200,
      child: ColoredBox(
        color: IqColors.brand,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.thumbnail != null)
              Positioned.fill(child: widget.thumbnail!)
            else ...[
              Container(
                width: 88,
                height: 170,
                decoration: BoxDecoration(
                  color: IqColors.sidebarAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              Positioned(
                top: 40,
                child: Container(
                  width: 48,
                  height: 6,
                  decoration: BoxDecoration(
                    color: IqColors.sidebarFg.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
            IqPressable(
              onTap: state == IqVideoPreviewState.ready ? widget.onPlay : null,
              semanticLabel: 'Play',
              behavior: HitTestBehavior.deferToChild,
              builder: (context, pressed) => AnimatedScale(
                scale: pressed ? 0.92 : 1,
                duration: reduced ? Duration.zero : IqVideoPreview.press,
                curve: Curves.easeOut,
                child: AnimatedBuilder(
                  animation: pop,
                  builder: (context, child) => Opacity(
                    opacity: pop.value,
                    child: Transform.scale(
                      scale: reduced ? 1 : 0.6 + 0.4 * pop.value,
                      child: child,
                    ),
                  ),
                  child: IqTilt(
                    degrees: 4,
                    child: Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: IqColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: IqIcon(
                        switch (state) {
                          IqVideoPreviewState.ready => IqIcons.play,
                          IqVideoPreviewState.uploading => IqIcons.upload,
                          IqVideoPreviewState.failed => IqIcons.warning,
                        },
                        size: 24,
                        color: IqColors.brand,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (state == IqVideoPreviewState.ready)
              Positioned(
                left: IqSpace.s3,
                bottom: IqSpace.s3,
                child: AnimatedBuilder(
                  animation: pop,
                  builder: (context, child) => Opacity(
                    opacity: pop.value,
                    child: Transform.translate(
                      offset: Offset(0, reduced ? 0 : 6 * (1 - pop.value)),
                      child: child,
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: IqSpace.s1p5,
                      vertical: IqSpace.s0p5,
                    ),
                    decoration: BoxDecoration(
                      color: IqColors.accentSoft,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.duration.toUpperCase(),
                      style: IqText.mono.copyWith(color: IqColors.brand),
                    ),
                  ),
                ),
              ),
            // Figma's 310, 12 is the tilted frame's origin; this is its
            // circle measured from the thumbnail's top right corner.
            Positioned(
              top: 10,
              right: 8,
              child: IqPressable(
                onTap: widget.onRemove,
                semanticLabel: 'Remove',
                builder: (context, pressed) => Transform.rotate(
                  angle: -6 * math.pi / 180,
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: pressed ? IqColors.brandDark : IqColors.brand,
                      shape: BoxShape.circle,
                    ),
                    child: const IqIcon(
                      IqIcons.close,
                      size: 18,
                      color: IqColors.primaryFg,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _caption() {
    final state = widget.state;
    final failed = state == IqVideoPreviewState.failed;
    final meta =
        widget.meta ??
        switch (state) {
          IqVideoPreviewState.ready => '18 MB · uploaded, ready to send',
          IqVideoPreviewState.uploading =>
            'Uploading… ${(widget.progress * 100).round()}% of 18 MB',
          IqVideoPreviewState.failed =>
            'Upload failed. Check your connection and retry.',
        };
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: IqSpace.s4,
        vertical: IqSpace.s3,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: IqText.bodyStrong.copyWith(color: IqColors.fg),
                ),
                const SizedBox(height: IqSpace.s0p5),
                Text(
                  meta,
                  style: IqText.small.copyWith(
                    color: failed ? IqColors.errStrong : IqColors.fg3,
                  ),
                ),
                if (state == IqVideoPreviewState.uploading) ...[
                  const SizedBox(height: IqSpace.s0p5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Container(
                      width: 100,
                      height: 4,
                      color: IqColors.line,
                      alignment: Alignment.centerLeft,
                      child: AnimatedFractionallySizedBox(
                        duration: _reduced
                            ? Duration.zero
                            : const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        widthFactor: widget.progress.clamp(0.0, 1.0),
                        heightFactor: 1,
                        child: const ColoredBox(color: IqColors.accent),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (failed) ...[
            const SizedBox(width: IqSpace.s3),
            IqPressable(
              onTap: widget.onRetry,
              semanticLabel: 'Retry',
              builder: (context, pressed) => Opacity(
                opacity: pressed ? 0.7 : 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Retry',
                      style: IqText.smallStrong.copyWith(
                        color: IqColors.primary,
                      ),
                    ),
                    const SizedBox(width: IqSpace.s1),
                    const IqIcon(
                      IqIcons.forward,
                      size: 14,
                      color: IqColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
