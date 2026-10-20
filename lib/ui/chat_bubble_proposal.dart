import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'chat_ticks.dart';
import 'support_sticker.dart';
import 'vector.dart';

enum IqChatBubbleProposalFrom { you, them }

enum IqChatBubbleProposalTail { on, off }

/// Inline keeps the time beside a short last line; Stacked puts it under
/// the text, at the end.
enum IqChatBubbleProposalLayout { inline, stacked }

/// Exp/ChatBubble (proposal): a message on the chat canvas, radius 10 with
/// the xs shadow, at most 312 wide. Yours sit right on brand ink with your
/// ticks; theirs left on paper, a [sender] line over them where a thread
/// has more than one voice (iQLY support signs with its sticker). The first
/// of a run from one side has the tail, its top corner squared. [media]
/// rides above the text.
class IqChatBubbleProposal extends StatelessWidget {
  const IqChatBubbleProposal({
    super.key,
    this.from = IqChatBubbleProposalFrom.them,
    this.tail = IqChatBubbleProposalTail.on,
    this.layout = IqChatBubbleProposalLayout.stacked,
    this.body = 'Hi Adaeze, Access Bank is still confirming it.',
    this.time = '9:14 am',
    this.sender,
    this.showSticker = false,
    this.ticks,
    this.media,
    this.maxWidth = 312,
  });

  final IqChatBubbleProposalFrom from;
  final IqChatBubbleProposalTail tail;
  final IqChatBubbleProposalLayout layout;
  final String body;
  final String time;
  final String? sender;
  final bool showSticker;

  /// The person's own message only.
  final IqChatTicksState? ticks;
  final Widget? media;
  final double maxWidth;

  static const _radius = Radius.circular(IqRadius.lg);

  bool get _you => from == IqChatBubbleProposalFrom.you;

  @override
  Widget build(BuildContext context) {
    final tailed = tail == IqChatBubbleProposalTail.on;
    final fill = _you ? IqColors.brand : IqColors.card;
    final ink = _you ? IqColors.sidebarFg : IqColors.fg;
    final meta = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: _you ? 0.7 : 1,
          child: Text(
            time,
            style: IqText.small.copyWith(
              color: _you ? IqColors.sidebarFg : IqColors.fg3,
            ),
          ),
        ),
        if (_you && ticks != null) ...[
          const SizedBox(width: IqSpace.s1),
          IqChatTicks(state: ticks!),
        ],
      ],
    );
    final text = body.isEmpty
        ? null
        : Text(body, style: IqText.body.copyWith(color: ink));
    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: IqSpace.s2,
        vertical: IqSpace.s1,
      ),
      child: layout == IqChatBubbleProposalLayout.inline && text != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(child: text),
                const SizedBox(width: IqSpace.s2),
                meta,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ?text,
                if (text != null) const SizedBox(height: IqSpace.s0p5),
                Align(alignment: Alignment.centerRight, child: meta),
              ],
            ),
    );
    final name = sender;
    final bubble = Container(
      padding: const EdgeInsets.all(IqSpace.s1),
      decoration: BoxDecoration(
        color: fill,
        boxShadow: IqShadows.xs,
        borderRadius: BorderRadius.only(
          topLeft: tailed && !_you ? Radius.zero : _radius,
          topRight: tailed && _you ? Radius.zero : _radius,
          bottomLeft: _radius,
          bottomRight: _radius,
        ),
      ),
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_you && name != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  IqSpace.s2,
                  IqSpace.s1,
                  IqSpace.s2,
                  0,
                ),
                child: Row(
                  children: [
                    if (showSticker) ...[
                      const IqSupportSticker(size: IqSupportStickerSize.small),
                      const SizedBox(width: IqSpace.s1p5),
                    ],
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: IqText.smallStrong.copyWith(color: IqColors.fg),
                      ),
                    ),
                  ],
                ),
              ),
            ?media,
            content,
          ],
        ),
      ),
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          bubble,
          if (tailed)
            Positioned(
              top: 0,
              left: _you ? null : -7,
              right: _you ? -7 : null,
              child: IqVector(
                _you
                    ? 'assets/vectors/chat-bubble-tail-you.svg'
                    : 'assets/vectors/chat-bubble-tail-them.svg',
                color: fill,
                width: 8,
                height: 12,
              ),
            ),
        ],
      ),
    );
  }
}
