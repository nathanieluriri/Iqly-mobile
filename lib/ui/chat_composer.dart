import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'chat_header.dart' show IqChatRoundButton;
import 'field.dart';
import 'icon.dart';
import 'pressable.dart';
import 'sticker.dart';
import 'text_link.dart';

enum IqChatComposerState { empty, typed, recording }

/// Exp/ChatComposer: the reply bar under a thread. Attach (+) on the left,
/// the Reply field, and the ink disc on its sticker: the mic for a voice
/// note while nothing is typed, the arrow to send once something is.
///
/// Not in Figma, the app's own: the mic is held to record ([onHoldStart],
/// then [onHoldMove] with how far the finger went sideways, and
/// [onHoldEnd] when it lets go or [onHoldCancel] when the hold is lost); a
/// tap is [onVoiceNote]. Recording keeps the bar's height: the red dot and
/// [recordTime] where the field was, Slide to cancel drifting with the
/// finger ([slide], 0 to 1 toward cancel), and the disc grown.
///
/// With a screen reader on (`accessibleNavigation`) a hold cannot be
/// done, so the mic is tapped instead: Record voice note starts
/// ([onHoldStart]), Stop and send ends it ([onHoldEnd]), and a Cancel
/// link takes the place of Slide to cancel ([onHoldCancel]).
class IqChatComposer extends StatelessWidget {
  const IqChatComposer({
    super.key,
    this.state = IqChatComposerState.empty,
    this.placeholder = 'Write to support',
    this.controller,
    this.onAttach,
    this.onSend,
    this.onVoiceNote,
    this.onHoldStart,
    this.onHoldMove,
    this.onHoldEnd,
    this.onHoldCancel,
    this.recordTime = '0:00',
    this.slide = 0,
    this.sending = false,
  });

  final IqChatComposerState state;
  final String placeholder;
  final TextEditingController? controller;
  final VoidCallback? onAttach;
  final VoidCallback? onSend;
  final VoidCallback? onVoiceNote;
  final VoidCallback? onHoldStart;
  final ValueChanged<double>? onHoldMove;
  final VoidCallback? onHoldEnd;
  final VoidCallback? onHoldCancel;
  final String recordTime;
  final double slide;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    final typed = state == IqChatComposerState.typed;
    final recording = state == IqChatComposerState.recording;
    final tapToRecord =
        MediaQuery.accessibleNavigationOf(context) &&
        !typed &&
        !sending &&
        onHoldStart != null;
    final action = sending
        ? null
        : typed
        ? onSend
        : tapToRecord
        ? (recording ? onHoldEnd : onHoldStart)
        : onVoiceNote;
    final holdable = !typed && !sending && !tapToRecord && onHoldStart != null;
    final reply = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IqChatRoundButton(
          icon: IqIcons.plus,
          semanticLabel: 'Attach',
          onTap: sending ? null : onAttach,
        ),
        const SizedBox(width: IqSpace.s2),
        Expanded(
          child: IqField(
            label: 'Reply',
            value: placeholder,
            controller: controller,
            minLines: 1,
            maxLines: 4,
            keyboardType: TextInputType.multiline,
          ),
        ),
      ],
    );
    Widget disc = IqPressable(
      semanticLabel: typed
          ? 'Send'
          : tapToRecord
          ? (recording ? 'Stop and send' : 'Record voice note')
          : recording
          ? 'Recording'
          : 'Voice note',
      semanticHint: typed
          ? null
          : tapToRecord
          ? (recording ? 'Sends the voice note' : 'Tap again to send')
          : recording
          ? null
          : 'Hold to record',
      onTap: action,
      builder: (context, pressed) => SizedBox.square(
        dimension: 44,
        child: AnimatedScale(
          scale: recording ? 1.2 : 1,
          duration: motion(context, IqDurations.swap),
          curve: IqCurves.easeOut,
          child: Sticker(
            radius: 22,
            pressed: pressed,
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: pressed || recording
                    ? IqColors.brandDark
                    : IqColors.brand,
                shape: BoxShape.circle,
              ),
              child: IqIcon(
                typed ? IqIcons.arrow : IqIcons.mic,
                size: 22,
                color: IqColors.primaryFg,
              ),
            ),
          ),
        ),
      ),
    );
    if (holdable) {
      // A semantics long press would start and end the note at once.
      disc = RawGestureDetector(
        excludeFromSemantics: true,
        gestures: {
          LongPressGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                () => LongPressGestureRecognizer(
                  duration: IqDurations.holdToRecord,
                ),
                (hold) {
                  hold.onLongPressStart = (_) => onHoldStart?.call();
                  hold.onLongPressMoveUpdate = (move) =>
                      onHoldMove?.call(move.offsetFromOrigin.dx);
                  hold.onLongPressEnd = (_) => onHoldEnd?.call();
                  hold.onLongPressCancel = () => onHoldCancel?.call();
                },
              ),
        },
        child: disc,
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(
        IqSpace.s3,
        IqSpace.s2,
        IqSpace.s3,
        IqSpace.s2p5,
      ),
      decoration: const BoxDecoration(
        color: IqColors.bg,
        border: Border(top: BorderSide(color: IqColors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Stack(
              children: [
                Opacity(
                  opacity: recording ? 0 : 1,
                  child: IgnorePointer(ignoring: recording, child: reply),
                ),
                if (recording)
                  Positioned.fill(
                    child: _Recording(
                      time: recordTime,
                      slide: slide,
                      onCancel: tapToRecord ? onHoldCancel : null,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: IqSpace.s2),
          disc,
        ],
      ),
    );
  }
}

/// While the mic is held: the red dot and the time, and Slide to cancel
/// drifting left as the finger does, or Cancel to tap ([onCancel]).
class _Recording extends StatelessWidget {
  const _Recording({required this.time, required this.slide, this.onCancel});

  final String time;
  final double slide;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final slide = this.slide.clamp(0.0, 1.0);
    return Semantics(
      liveRegion: true,
      label: 'Recording $time',
      child: Row(
        children: [
          const SizedBox(width: IqSpace.s2),
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: IqColors.err,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: IqSpace.s2),
          ExcludeSemantics(
            child: Text(
              time,
              style: IqText.bodyStrong.copyWith(color: IqColors.fg),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: onCancel != null
                  ? Semantics(
                      container: true,
                      child: IqTextLink(
                        label: 'Cancel',
                        showIcon: false,
                        onTap: onCancel,
                      ),
                    )
                  : Transform.translate(
                      offset: Offset(-IqSpace.s12 * slide, 0),
                      child: Opacity(
                        opacity: 1 - slide * 0.8,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const IqIcon(
                              IqIcons.back,
                              size: 16,
                              color: IqColors.fg3,
                            ),
                            const SizedBox(width: IqSpace.s1),
                            Text(
                              'Slide to cancel',
                              style: IqText.small.copyWith(color: IqColors.fg3),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: IqSpace.s2),
        ],
      ),
    );
  }
}
