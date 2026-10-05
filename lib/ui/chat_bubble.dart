import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'tilt.dart';
import 'video_preview.dart';

enum IqChatBubbleFrom { you, support }

/// Exp/ChatBubble: a help-thread message. Yours sit right in brand ink;
/// support sits left on paper under the tilted iQ sticker. Time in Mob/Small
/// (no longer mono, 5 Oct update). A
/// recording can ride under the text ([showAttachment], the nested
/// Exp/VideoPreview, [attachment] to override it).
///
/// A new bubble scales from .96 at its tail corner and fades in, 220 ms
/// ease-out, its time stamp fading in with it; the attachment fades in 120
/// ms after it. Support's sticker and name stay put: the typing bubble
/// before a reply already shows them. Reduced motion: fade only. Set
/// [animate] false for bubbles already on screen.
///
/// Figma over its note: the attachment fills the bubble width (272 or 270)
/// instead of keeping the master's 358 thumbnail.
class IqChatBubble extends StatefulWidget {
  const IqChatBubble({
    super.key,
    this.from = IqChatBubbleFrom.you,
    this.body =
        'I did all three steps and saved ₦1,000 on Thursday. I sent proof '
        'of step 2 yesterday and it still says Checking.',
    this.time = 'Today, 2:20 pm',
    this.name = 'iQLY support',
    this.showAttachment = false,
    this.attachment,
    this.animate = true,
  });

  final IqChatBubbleFrom from;
  final String body;
  final String time;
  final String name;
  final bool showAttachment;
  final Widget? attachment;
  final bool animate;

  static const Duration arrive = IqDurations.appear;
  static const Duration attachmentDelay = IqDurations.chain;

  @override
  State<IqChatBubble> createState() => _IqChatBubbleState();
}

class _IqChatBubbleState extends State<IqChatBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration:
        IqChatBubble.arrive +
        IqChatBubble.attachmentDelay +
        IqChatBubble.arrive,
  );
  late final Animation<double> _bubbleIn = _in.drive(
    CurveTween(curve: _span(Duration.zero, IqChatBubble.arrive)),
  );
  late final Animation<double> _attachmentIn = _in.drive(
    CurveTween(
      curve: _span(
        IqChatBubble.arrive + IqChatBubble.attachmentDelay,
        IqChatBubble.arrive,
      ),
    ),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.animate) {
      _in.forward();
    } else {
      _in.value = 1;
    }
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  Interval _span(Duration start, Duration length) {
    final total = _in.duration!.inMilliseconds;
    return Interval(
      start.inMilliseconds / total,
      (start + length).inMilliseconds / total,
      curve: IqCurves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final you = widget.from == IqChatBubbleFrom.you;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final bubbleIn = _bubbleIn;
    final attachmentIn = _attachmentIn;
    const r = Radius.circular(IqRadius.xl2);
    const tail = Radius.circular(4);
    final bubble = Container(
      width: 300,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: IqSpace.s3),
      decoration: BoxDecoration(
        color: you ? IqColors.brand : IqColors.card,
        border: you ? null : Border.all(color: IqColors.brandLine2),
        borderRadius: you
            ? const BorderRadius.only(
                topLeft: r,
                topRight: r,
                bottomLeft: r,
                bottomRight: tail,
              )
            : const BorderRadius.only(
                topLeft: r,
                topRight: r,
                bottomLeft: tail,
                bottomRight: r,
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.body,
            style: IqText.body.copyWith(
              color: you ? IqColors.sidebarFg : IqColors.fg,
            ),
          ),
          if (widget.showAttachment) ...[
            const SizedBox(height: IqSpace.s2p5),
            FadeTransition(
              opacity: attachmentIn,
              child: widget.attachment ?? const IqVideoPreview(),
            ),
          ],
        ],
      ),
    );
    return Column(
      crossAxisAlignment: you
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!you) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IqTilt(
                degrees: 6,
                child: Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: IqColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    'iQ',
                    style: IqText.label.copyWith(color: IqColors.brand),
                  ),
                ),
              ),
              const SizedBox(width: IqSpace.s2),
              Text(
                widget.name,
                style: IqText.smallStrong.copyWith(color: IqColors.fg),
              ),
            ],
          ),
          const SizedBox(height: IqSpace.s1p5),
        ],
        FadeTransition(
          opacity: bubbleIn,
          child: AnimatedBuilder(
            animation: bubbleIn,
            builder: (context, child) => Transform.scale(
              scale: reduced
                  ? 1
                  : IqScale.soft + (1 - IqScale.soft) * bubbleIn.value,
              alignment: you ? Alignment.bottomRight : Alignment.bottomLeft,
              child: child,
            ),
            child: bubble,
          ),
        ),
        const SizedBox(height: IqSpace.s1p5),
        FadeTransition(
          opacity: bubbleIn,
          child: Text(
            widget.time.toUpperCase(),
            style: IqText.mono.copyWith(color: IqColors.fg3),
          ),
        ),
        Text(widget.time, style: IqText.small.copyWith(color: IqColors.fg3)),
      ],
    );
  }
}
