import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'icon.dart';

enum IqProgressThreadState { progress, ready, error }

/// Exp/ProgressThread: one line of plain words and a count over a 1 pt
/// rule. It judges the long text area; short fields validate inline.
///
/// Figma over brief: since the 5 Oct update the thread is calm: the words,
/// the count and the success or error glyph all sit in fg2, the count reads
/// "1 of 2" in Mob/Small (not mono caps) and the coloured brush rules are
/// hidden layers, so only the line rule shows in every state.
///
/// Motion (spec 5.26, build extension): a state change rolls the words and
/// the count, and the status icon pops in from .6 (220) or fades out (150).
/// Under reduced motion every change lands at once.
///
/// Note over Figma: words too long for the line wrap to a second line; the
/// master is one line.
class IqProgressThread extends StatelessWidget {
  const IqProgressThread({
    super.key,
    this.status = 'Account number next',
    this.count = '1 of 2',
    this.readyText = 'Ready to save',
    this.errorText = 'Fix the account number',
    this.state = IqProgressThreadState.progress,
  });

  final String status;
  final String count;
  final String readyText;
  final String errorText;
  final IqProgressThreadState state;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final (text, icon) = switch (state) {
      IqProgressThreadState.progress => (status, null),
      IqProgressThreadState.ready => (readyText, IqIcons.success),
      IqProgressThreadState.error => (errorText, IqIcons.error),
    };
    final showCount = state != IqProgressThreadState.ready;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            SizedBox.square(
              dimension: 18,
              child: AnimatedSwitcher(
                duration: motion(context, IqDurations.appear),
                reverseDuration: motion(context, IqDurations.crossfade),
                switchInCurve: IqCurves.easeOut,
                switchOutCurve: IqCurves.easeOut,
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation.drive(
                    Tween<double>(begin: IqScale.pop, end: 1),
                  ),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: icon == null
                    ? const SizedBox.shrink()
                    : IqIcon(
                        key: ValueKey(icon),
                        icon,
                        size: 18,
                        color: IqColors.fg2,
                      ),
              ),
            ),
            const SizedBox(width: IqSpace.s1p5),
            Expanded(
              child: _Words(
                text,
                style: IqText.smallStrong.copyWith(color: IqColors.fg2),
                reduced: reduced,
              ),
            ),
            AnimatedSwitcher(
              duration: motion(context, IqDurations.crossfade),
              switchInCurve: IqCurves.easeOut,
              switchOutCurve: IqCurves.easeOut,
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.centerRight,
                children: [...previous, ?current],
              ),
              child: showCount
                  ? Row(
                      key: const ValueKey('count'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: IqSpace.s2),
                        RollingText(
                          count,
                          style: IqText.small.copyWith(color: IqColors.fg2),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: IqSpace.s2),
        const SizedBox(
          height: 6,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 3,
                height: 1,
                child: ColoredBox(color: IqColors.line),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The status words: they roll when they change and fit the line, and wrap
/// to a second line when they do not.
class _Words extends StatelessWidget {
  const _Words(this.text, {required this.style, required this.reduced});

  final String text;
  final TextStyle style;
  final bool reduced;

  @override
  Widget build(BuildContext context) {
    final words = LayoutBuilder(
      builder: (context, box) {
        final painter = TextPainter(
          text: TextSpan(
            text: text,
            style: DefaultTextStyle.of(context).style.merge(style),
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout(maxWidth: box.maxWidth);
        final fits = !painter.didExceedMaxLines;
        painter.dispose();
        if (fits) return RollingText(text, style: style);
        return Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: style,
        );
      },
    );
    if (reduced) return words;
    return AnimatedSize(
      duration: IqDurations.tick,
      curve: IqCurves.easeOut,
      alignment: AlignmentDirectional.topStart,
      child: words,
    );
  }
}
