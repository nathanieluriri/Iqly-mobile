import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../theme/theme.dart';

enum IqSpotsStampTone {
  plenty,
  low,
  full,
  critical;

  /// The activations colour ladder: Plenty above 25% of spots left, Low from
  /// 10 to 25%, Critical under 10%, Full when none are left.
  static IqSpotsStampTone of(int left, int total) {
    if (left <= 0 || total <= 0) return IqSpotsStampTone.full;
    final share = left / total;
    if (share < 0.1) return IqSpotsStampTone.critical;
    if (share <= 0.25) return IqSpotsStampTone.low;
    return IqSpotsStampTone.plenty;
  }
}

/// Exp/SpotsStamp: spots left as a big figure on a highlighter block, the
/// words beside it, the taken count on the right and a thread filled with
/// the share taken. Fills its parent's width. On appear the marker wipes in
/// left to right (240 ms) while the figure counts up and the thread fills
/// (600 ms ease-out); a spot taken live dips the figure 2 px and nudges the
/// thread (200 ms). Reduced motion: static at the final values.
///
/// [word] defaults to the Figma words per tone. [showOf] hides the taken
/// count and [onInk] turns the words white, as the Hero ticket overrides.
///
/// Figma over brief: a Critical tone (white figure on a red marker).
/// Figma over its note: Low's thread is orange, not brand-dark.
/// Figma over its note: Full has no strikethrough on the figure.
/// Figma over its note: the thread is a plain 4 px bar, not a brush line.
class IqSpotsStamp extends StatefulWidget {
  const IqSpotsStamp({
    super.key,
    this.left = 188,
    this.total = 500,
    this.tone = IqSpotsStampTone.plenty,
    this.word,
    this.showOf = true,
    this.onInk = false,
  });

  final int left;
  final int total;
  final IqSpotsStampTone tone;
  final String? word;
  final bool showOf;
  final bool onInk;

  static const Duration fill = IqDurations.fill;
  static const Duration wipe = IqDurations.mark;
  static const Duration dip = IqDurations.swap;

  @override
  State<IqSpotsStamp> createState() => _IqSpotsStampState();
}

class _IqSpotsStampState extends State<IqSpotsStamp>
    with TickerProviderStateMixin {
  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: IqSpotsStamp.fill,
  );
  late final AnimationController _wipe = AnimationController(
    vsync: this,
    duration: IqSpotsStamp.wipe,
  );
  late final AnimationController _dip = AnimationController(
    vsync: this,
    duration: IqSpotsStamp.dip,
  );
  late final Animation<double> _grow = _fill.drive(
    CurveTween(curve: IqCurves.easeOut),
  );
  late final Animation<double> _reveal = _wipe.drive(
    CurveTween(curve: IqCurves.easeOut),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _fill.value = 1;
      _wipe.value = 1;
    } else {
      _fill.forward();
      _wipe.forward();
    }
  }

  @override
  void didUpdateWidget(IqSpotsStamp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.left < oldWidget.left &&
        !MediaQuery.disableAnimationsOf(context)) {
      _dip.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _fill.dispose();
    _wipe.dispose();
    _dip.dispose();
    super.dispose();
  }

  double get _share {
    if (widget.total <= 0) return 1;
    return ((widget.total - widget.left) / widget.total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final look = _SpotsLook.of(widget.tone);
    final word = widget.word ?? look.word;
    final taken = widget.total - widget.left;
    final grow = _grow;
    final wipe = _reveal;
    return AnimatedBuilder(
      animation: Listenable.merge([grow, wipe, _dip]),
      builder: (context, _) {
        final bump = math.sin(_dip.value * math.pi);
        final count = (widget.left * grow.value).round();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 32,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // The words give way (ellipsis) before the row overflows
                  // at large text sizes; the figure never does.
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: IqSpace.s1p5),
                      child: Row(
                        children: [
                          Transform.translate(
                            offset: Offset(0, IqTravel.dip * bump),
                            child: _marker(look, count, wipe.value),
                          ),
                          const SizedBox(width: IqSpace.s2),
                          Flexible(
                            child: Text(
                              word,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: IqText.bodyStrong.copyWith(
                                color: widget.onInk
                                    ? IqColors.primaryFg
                                    : look.wordInk,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.showOf)
                    Text(
                      '$taken / ${widget.total} taken'.toUpperCase(),
                      maxLines: 1,
                      softWrap: false,
                      style: IqText.mono.copyWith(color: IqColors.fg2),
                    ),
                ],
              ),
            ),
            const SizedBox(height: IqSpace.s2),
            SizedBox(
              height: 6,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: Container(
                    height: 4,
                    color: IqColors.line,
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: (_share * grow.value + 0.01 * bump).clamp(
                        0.0,
                        1.0,
                      ),
                      heightFactor: 1,
                      child: ColoredBox(color: look.thread),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _marker(_SpotsLook look, int count, double reveal) {
    return Stack(
      children: [
        Positioned.fill(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: reveal,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: look.marker,
                  borderRadius: BorderRadius.circular(IqRadius.sm),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: IqSpace.s1p5,
            vertical: 1,
          ),
          child: Text(
            '$count',
            maxLines: 1,
            softWrap: false,
            style: IqText.figure.copyWith(color: look.countInk),
          ),
        ),
      ],
    );
  }
}

class _SpotsLook {
  const _SpotsLook({
    required this.marker,
    required this.countInk,
    required this.wordInk,
    required this.thread,
    required this.word,
  });

  final Color marker;
  final Color countInk;
  final Color wordInk;
  final Color thread;
  final String word;

  static _SpotsLook of(IqSpotsStampTone tone) => switch (tone) {
    IqSpotsStampTone.plenty => const _SpotsLook(
      marker: IqColors.okSoft,
      countInk: IqColors.brand,
      wordInk: IqColors.brand,
      thread: IqColors.ok,
      word: 'left',
    ),
    IqSpotsStampTone.low => const _SpotsLook(
      marker: IqColors.accentSoft,
      countInk: IqColors.brand,
      wordInk: IqColors.accentStrong,
      thread: IqColors.accentStrong,
      word: 'left',
    ),
    IqSpotsStampTone.critical => const _SpotsLook(
      marker: IqColors.err,
      countInk: IqColors.primaryFg,
      wordInk: IqColors.err,
      thread: IqColors.err,
      word: 'left · almost gone',
    ),
    IqSpotsStampTone.full => const _SpotsLook(
      marker: IqColors.line,
      countInk: IqColors.fg3,
      wordInk: IqColors.fg3,
      thread: IqColors.line2,
      word: 'left · full',
    ),
  };
}
