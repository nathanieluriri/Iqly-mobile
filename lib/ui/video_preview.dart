import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/motion.dart';
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
/// anything is deleted. Upload to ready completes the thread (it fills to
/// the end over 200 ms ease-out, then folds away), pops the play sticker in
/// (.6 to 1, 220 ms ease-out) and slides the duration stamp up 6 px.
/// Reduced motion: fades only, and the thread goes at once.
/// [showRemove] false drops the remove sticker once the recording is sent
/// (B9 · Proof · submitted shows an empty disc there).
///
/// [heroTag] makes the thumbnail a Hero, its stickers and stamp inside, so
/// they go with the frame when it flies and nothing of it stays behind
/// under the flight: pushed, the flight draws the look it lands on; popped,
/// the leaving look fades out over the arriving one, so a sticker only the
/// leaving look has (the remove X, back from Send proof) fades with it.
///
/// Figma over its note: the master's duration stamp sits below the clipped
/// thumbnail, so it is hidden by default; [showDuration] places it bottom
/// left, 12 px in, as the note intends (the owner to choose).
/// Figma over brief: Retry uses Color/primary.
/// Figma over the icon rule: the close icon is 18 px and the arrow 14 px.
class IqVideoPreview extends StatefulWidget {
  const IqVideoPreview({
    super.key,
    this.state = IqVideoPreviewState.ready,
    this.name = 'kudi-box-signup.mp4',
    this.duration = '0:42',
    this.showDuration = false,
    this.meta,
    this.progress = 0.64,
    this.thumbnail,
    this.heroTag,
    this.showRemove = true,
    this.onPlay,
    this.onRemove,
    this.onRetry,
  });

  final IqVideoPreviewState state;
  final String name;
  final String duration;
  final bool showDuration;
  final String? meta;
  final double progress;
  final Widget? thumbnail;
  final Object? heroTag;
  final bool showRemove;
  final VoidCallback? onPlay;
  final VoidCallback? onRemove;
  final VoidCallback? onRetry;

  static const Duration pop = IqDurations.appear;
  static const Duration press = IqDurations.press;

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
  late final Animation<double> _pop = _ready.drive(
    CurveTween(curve: IqCurves.easeOut),
  );

  /// The upload just finished: the thread stays to fill to the end.
  bool _finishing = false;

  /// The full thread folds away.
  bool _folded = false;
  Timer? _fold;

  bool get _reduced => MediaQuery.disableAnimationsOf(context);

  @override
  void didUpdateWidget(IqVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final state = widget.state;
    if (state == oldWidget.state) return;
    _fold?.cancel();
    _finishing =
        state == IqVideoPreviewState.ready &&
        oldWidget.state == IqVideoPreviewState.uploading &&
        !_reduced;
    _folded = false;
    if (_finishing) {
      _fold = Timer(IqDurations.swap, () {
        if (mounted) setState(() => _folded = true);
      });
    }
    if (state == IqVideoPreviewState.ready) _ready.forward(from: 0);
  }

  @override
  void dispose() {
    _fold?.cancel();
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

  /// The flight between two thumbnails, or a thumbnail and the player.
  static Widget _flight(
    BuildContext context,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext from,
    BuildContext to,
  ) {
    final arriving = (to.widget as Hero).child;
    // Drawn in the navigator's overlay, outside every page's Material, where
    // the stamp's text would take the framework's fallback style.
    return Material(
      type: MaterialType.transparency,
      child: direction == HeroFlightDirection.push
          ? arriving
          : Stack(
              fit: StackFit.expand,
              children: [
                arriving,
                FadeTransition(
                  opacity: animation,
                  child: (from.widget as Hero).child,
                ),
              ],
            ),
    );
  }

  Widget _thumbnail() {
    final heroTag = widget.heroTag;
    final thumbnail = ColoredBox(color: IqColors.brand, child: _contents());
    return SizedBox(
      height: 200,
      child: heroTag == null
          ? thumbnail
          : Hero(
              tag: heroTag,
              curve: IqCurves.easeInOut,
              flightShuttleBuilder: _flight,
              child: thumbnail,
            ),
    );
  }

  Widget _contents() {
    final state = widget.state;
    final reduced = _reduced;
    final pop = _pop;
    return Stack(
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
          tactile: false,
          onTap: state == IqVideoPreviewState.ready ? widget.onPlay : null,
          semanticLabel: 'Play',
          hint: 'Play',
          behavior: HitTestBehavior.deferToChild,
          builder: (context, pressed) => AnimatedScale(
            scale: pressed && !reduced ? IqScale.playPress : 1,
            duration: pressMotion(context, pressed),
            curve: IqCurves.easeOut,
            child: FadeTransition(
              opacity: pop,
              child: AnimatedBuilder(
                animation: pop,
                builder: (context, child) => Transform.scale(
                  scale: reduced
                      ? 1
                      : IqScale.pop + (1 - IqScale.pop) * pop.value,
                  child: child,
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
        ),
        if (state == IqVideoPreviewState.ready && widget.showDuration)
          Positioned(
            left: IqSpace.s3,
            bottom: IqSpace.s3,
            child: FadeTransition(
              opacity: pop,
              child: AnimatedBuilder(
                animation: pop,
                builder: (context, child) => Transform.translate(
                  offset: Offset(
                    0,
                    reduced ? 0 : IqTravel.tick * (1 - pop.value),
                  ),
                  child: child,
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
          ),
        // Figma's 310, 12 is the tilted frame's origin; this is its
        // circle measured from the thumbnail's top right corner.
        // 44 pt hit area around the 36 px sticker.
        if (widget.showRemove)
          Positioned(
            top: 6,
            right: 4,
            width: 44,
            height: 44,
            child: IqPressable(
              onTap: widget.onRemove,
              semanticLabel: 'Remove',
              builder: (context, pressed) => Transform.rotate(
                angle: -6 * math.pi / 180,
                child: Container(
                  margin: const EdgeInsets.all(4),
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
                if (state == IqVideoPreviewState.uploading || _finishing)
                  Collapse(
                    open: !_folded,
                    child: Padding(
                      padding: const EdgeInsets.only(top: IqSpace.s0p5),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: Container(
                          width: 100,
                          height: 4,
                          color: IqColors.line,
                          alignment: Alignment.centerLeft,
                          child: AnimatedFractionallySizedBox(
                            duration: motion(context, IqDurations.swap),
                            curve: IqCurves.easeOut,
                            widthFactor: _finishing
                                ? 1
                                : widget.progress.clamp(0.0, 1.0),
                            heightFactor: 1,
                            child: const ColoredBox(color: IqColors.accent),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (failed) ...[
            const SizedBox(width: IqSpace.s3),
            IqPressable(
              onTap: widget.onRetry,
              builder: (context, pressed) => ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: PressDim(
                  pressed: pressed,
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
            ),
          ],
        ],
      ),
    );
  }
}
