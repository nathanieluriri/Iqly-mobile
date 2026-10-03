import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The kit's easings (spec 2.1). A reversed controller plays its curve
/// backwards, so an exit keeps the entrance curve and reads as an ease-in:
/// never pass a reverse or switch-out ease-in.
abstract final class IqCurves {
  /// Arrive, respond, press, settle, fills, wipes, sheet rise (EASE_OUT).
  static const Curve easeOut = Cubic(0, 0, 0.58, 1);

  /// Leave, in implicit animations and forward-driven exits (EASE_IN).
  static const Curve easeIn = Cubic(0.42, 0, 1, 1);

  /// Morphs of things that stay on screen (EASE_IN_AND_OUT).
  static const Curve easeInOut = Cubic(0.42, 0, 0.58, 1);

  /// Gesture-driven progress, rotations and the halo fade.
  static const Curve linear = Curves.linear;

  /// Breathing loops.
  static const Curve breath = Cubic(0.445, 0.05, 0.55, 0.95);

  /// The autosave check pop, about 4% over on a .6 to 1 scale.
  static const Curve stamp = Cubic(0.175, 0.885, 0.32, 1.275);
}

/// The kit's timings (spec 2.2).
abstract final class IqDurations {
  /// Sticker drop, card .98, chip .96, press fills.
  static const press = Duration(milliseconds: 120);

  /// Everything a press changed, coming back.
  static const release = Duration(milliseconds: 160);

  /// Least time a press stays drawn after a quick tap.
  static const pressHold = Duration(milliseconds: 100);

  /// Text links, ghosts and row fills going down (they come back in [release]).
  static const dim = Duration(milliseconds: 100);

  /// ConfirmSheet Remove sinks before the sheet drops.
  static const sink = Duration(milliseconds: 100);

  /// The next beat of a chain: next row Active, attachment, pick then close.
  static const chain = Duration(milliseconds: 120);

  /// Reduced-motion swaps, stamp and tag kind changes, quick fades.
  static const crossfade = Duration(milliseconds: 150);

  /// Digit roll, check draw, help line reveal, label colour, switch.
  static const tick = Duration(milliseconds: 160);

  /// A dot inks, the highlighter slides off, tile flash, banner leaves.
  static const ink = Duration(milliseconds: 180);

  /// Dock pill, pops, dip, picker value, sheet exit, fade-through, peel.
  static const swap = Duration(milliseconds: 200);

  /// One element appears: fade and rise 8, sticker pop, chat bubble.
  static const appear = Duration(milliseconds: 220);

  /// Marker wipe, stamp land, banner arrives, thread draws, shake.
  static const mark = Duration(milliseconds: 240);

  /// Arrive and settle.
  static const enter = Duration(milliseconds: 260);

  /// ConfirmSheet rise.
  static const sheetConfirm = Duration(milliseconds: 280);

  /// Push, sheet rise, dissolve, flow hand-off, landing focus.
  static const screen = Duration(milliseconds: 300);

  /// Pop and landing unfocus.
  static const screenBack = Duration(milliseconds: 240);

  /// Shared elements, ProofTile into VideoPreview.
  static const morph = Duration(milliseconds: 320);

  /// The splash dissolve.
  static const handoff = Duration(milliseconds: 400);

  /// Thread fills, count-ups, poll share bars.
  static const fill = Duration(milliseconds: 600);

  /// Between arriving items.
  static const stagger = Duration(milliseconds: 40);

  /// Wait before any skeleton shows.
  static const skeletonDelay = Duration(milliseconds: 300);

  /// Least skeleton time once shown.
  static const skeletonMin = Duration(milliseconds: 600);

  /// PullIndicator Done before the row collapses.
  static const doneHold = Duration(milliseconds: 800);

  /// The first-run tip waits for Home to arrive.
  static const tipWait = Duration(milliseconds: 600);

  /// Content arriving behind a skeleton's fade (spec 2.6).
  static const lag = Duration(milliseconds: 60);

  /// Illustrations and hero icons arrive: fade and rise 16 (spec 5.29).
  static const illustration = Duration(milliseconds: 320);

  /// An Urgency tone change, once (spec 5.14).
  static const tone = Duration(milliseconds: 400);

  /// An unsaved ticket stays in the Saved list this long before it folds
  /// away (spec 5.12).
  static const unsave = Duration(milliseconds: 300);

  /// Loop: Countdown Hot halo, Banner Urgent clock, ClaimStamp Checking dot.
  static const pulse = Duration(milliseconds: 1400);

  /// Loop: one full breath of the TimelineRow Current ring.
  static const ringBreath = Duration(milliseconds: 1600);

  /// Loop: the ProofTile sticker while empty.
  static const stickerBreath = Duration(milliseconds: 2400);

  /// Loop: skeleton bars, all in phase.
  static const skeletonPulse = Duration(milliseconds: 900);

  /// Loop: one PullIndicator turn.
  static const refreshTurn = Duration(milliseconds: 900);

  /// Loop: one Button spinner turn.
  static const spinnerTurn = Duration(milliseconds: 1000);

  /// Loop: the support typing dots.
  static const typingDots = Duration(milliseconds: 600);

  /// Loop: the landing LineArt cycle.
  static const lineArt = Duration(milliseconds: 5400);

  /// Loop: the BalanceHero ink wash drift.
  static const inkWash = Duration(milliseconds: 24000);
}

/// The splash light-up (spec 6.1): the hold before each move, then the move.
abstract final class IqSplashTiming {
  /// Dark holds before the Spark move.
  static const darkHold = Duration(milliseconds: 300);

  /// Dark to Spark.
  static const toSpark = Duration(milliseconds: 500);

  /// Spark holds before the Lit move.
  static const sparkHold = Duration(milliseconds: 400);

  /// Spark to Lit.
  static const toLit = Duration(milliseconds: 700);

  /// Lit holds before the Settled move.
  static const litHold = Duration(milliseconds: 500);

  /// Lit to Settled.
  static const toSettled = Duration(milliseconds: 600);

  /// Settled holds before the hand-off.
  static const settledHold = Duration(milliseconds: 600);

  /// Dark to Settled in place: reduced motion and later launches.
  static const settleInPlace = Duration(milliseconds: 400);
}

/// Distances in logical pixels (spec 2.3).
abstract final class IqTravel {
  /// The pill's drop onto its shadow (the Figma Pressed variants).
  static const double pressDrop = 3;

  /// The sticker shadow offset, and how far the peel travels.
  static const double sticker = 4;

  /// SpotsStamp dip and the shake amplitude.
  static const double dip = 2;

  /// Help line rise, typing dots bob, arrow nudge.
  static const double nudge = 4;

  /// Digit roll and the duration stamp slide.
  static const double tick = 6;

  /// Appear and settle.
  static const double rise = 8;

  /// Arrive.
  static const double riseCard = 12;

  /// Illustrations and the TipCard.
  static const double riseHero = 16;

  /// Push and pop shift.
  static const double screen = 24;

  /// Pull distance that arms a refresh.
  static const double pullArm = 64;

  /// Space the refreshing row holds (40 row and 12 gap).
  static const double refreshSlot = 52;
}

/// Scales (spec 2.3).
abstract final class IqScale {
  /// Card and ticket press.
  static const double cardPress = 0.98;

  /// Chip press; it pops back to 1 on select.
  static const double chipPress = 0.96;

  /// Play sticker press.
  static const double playPress = 0.92;

  /// Bookmark icon press.
  static const double bookmarkPress = 0.9;

  /// Where a pop starts.
  static const double pop = 0.6;

  /// Where a stamp lands from.
  static const double stampLand = 1.15;

  /// The step bubble pop's peak.
  static const double bubblePop = 1.1;

  /// The halo at the end of a beat.
  static const double halo = 1.8;

  /// The breathing ring's peak.
  static const double ring = 1.3;

  /// The breathing sticker's peak.
  static const double stickerBreath = 1.04;

  /// Chat bubble and TipCard on arrival, BrandBubble press.
  static const double soft = 0.96;

  /// The NextFab disc as its peel starts.
  static const double peel = 0.92;

  /// The newly lit Dock glyph.
  static const double dockGlyph = 0.85;
}

/// Opacities (spec 2.3).
abstract final class IqOpacity {
  /// A halo at the start of its beat.
  static const double halo = 0.35;

  /// A halo standing still, under reduced motion or without the pulse.
  static const double haloStill = 0.2;

  /// The breathing ring.
  static const double ring = 0.25;

  /// Text links and ghosts while pressed.
  static const double pressed = 0.6;

  /// The TipCard scrim on brand.
  static const double tipScrim = 0.6;

  /// Filters, Polls, Withdraw and ConfirmSheet scrims on brand.
  static const double sheetScrim = 0.5;

  /// Picker sheet scrims on brand.
  static const double pickerScrim = 0.3;

  /// The share sheet scrim on brand.
  static const double shareScrim = 0.35;
}

/// [normal] unless reduced motion is on: then nothing, or the 150 ms
/// crossfade when [fade] keeps the change readable.
Duration motion(BuildContext context, Duration normal, {bool fade = false}) {
  if (!MediaQuery.disableAnimationsOf(context)) return normal;
  return fade ? IqDurations.crossfade : Duration.zero;
}

/// How long a pressed look takes to follow [pressed]: [IqDurations.press]
/// down, [IqDurations.release] back up, a cut back up under reduced motion.
Duration pressMotion(BuildContext context, bool pressed) {
  if (pressed) return IqDurations.press;
  return motion(context, IqDurations.release);
}

/// The haptic moments (spec 2.7). The platform setting decides whether they
/// play; reduced motion does not change them.
enum IqHaptics {
  /// Chips, switches, option rows, bookmarks, dock tabs, poll picks.
  select,

  /// Primary and Inverse buttons, the NextFab, the Email provider button.
  commit,

  /// The start of a destructive confirm's sink (the Danger button).
  destructive,

  /// The result of the user's action lands.
  success,

  /// The user's action failed.
  error;

  /// Plays it; an error is the iOS error pattern, a medium impact on Android.
  Future<void> play() => switch (this) {
    select => HapticFeedback.selectionClick(),
    commit => HapticFeedback.lightImpact(),
    destructive => HapticFeedback.mediumImpact(),
    success => HapticFeedback.successNotification(),
    error =>
      defaultTargetPlatform == TargetPlatform.iOS
          ? HapticFeedback.errorNotification()
          : HapticFeedback.mediumImpact(),
  };
}

/// The kit's error language, shared so every row fails the same way: the
/// ProofTile shake, the Highlight wipe, and a help line that rises into
/// place. Under reduced motion nothing moves; the error just appears.
abstract final class ErrorMotion {
  static const Duration shake = IqDurations.mark;
  static const Duration wipe = IqDurations.mark;
  static const Duration reveal = IqDurations.tick;
  static const double shakeDistance = IqTravel.dip;
  static const int shakeTimes = 3;
  static const double rise = IqTravel.nudge;
}

/// The haptic that goes with a failed submit.
Future<void> errorHaptic() => IqHaptics.error.play();

/// Shakes [child] 2 px three times over 240 ms each time [trigger] changes
/// (a count of failed submits, say).
class Shake extends StatefulWidget {
  const Shake({super.key, required this.trigger, required this.child});

  final int trigger;
  final Widget child;

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: ErrorMotion.shake,
  );
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void didUpdateWidget(Shake old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger && !_reduced) _shake.forward(from: 0);
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shake,
      child: widget.child,
      builder: (context, child) => Transform.translate(
        offset: Offset(
          ErrorMotion.shakeDistance *
              math.sin(_shake.value * math.pi * 2 * ErrorMotion.shakeTimes),
          0,
        ),
        child: child,
      ),
    );
  }
}

/// A one-shot entrance: starts on its first build, or when first seen,
/// after [delay].
abstract class _Entrance extends StatefulWidget {
  const _Entrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.whenSeen = false,
  });

  final Widget child;
  final Duration delay;
  final bool whenSeen;
}

abstract class _EntranceState<T extends _Entrance> extends State<T>
    with SingleTickerProviderStateMixin {
  /// The move's own length with motion on.
  Duration get length;

  /// Under reduced motion: true fades in over 150 ms, false shows at once.
  bool get fadesWhenReduced => false;

  Widget buildMove(BuildContext context, Animation<double> progress);

  late final AnimationController clock = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
  );
  Animation<double> _progress = kAlwaysDismissedAnimation;
  bool reduced = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reduced = MediaQuery.disableAnimationsOf(context);
    if (!widget.whenSeen || (reduced && !fadesWhenReduced)) _start();
  }

  void _start() {
    if (_started || !mounted) return;
    _started = true;
    if (reduced && !fadesWhenReduced) {
      clock.value = 1;
      _progress = clock;
      return;
    }
    final move = reduced ? IqDurations.crossfade : length;
    final delay = reduced ? Duration.zero : widget.delay;
    final total = delay + move;
    clock.duration = total;
    _progress = clock.drive(
      CurveTween(
        curve: Interval(
          delay.inMicroseconds / total.inMicroseconds,
          1,
          curve: IqCurves.easeOut,
        ),
      ),
    );
    clock.forward();
    if (SchedulerBinding.instance.schedulerPhase !=
        SchedulerPhase.persistentCallbacks) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final move = buildMove(context, _progress);
    if (!widget.whenSeen) return move;
    return FirstSeen(onSeen: _start, child: move);
  }
}

/// Wipes [child] in along [axis], left to right or top to bottom, as the
/// Highlight marker does (spec 2.5 wipe and draw): 240 ms ease-out by
/// default, 160 for a check. Paints unclipped once it has landed; shown at
/// once under reduced motion.
class Wipe extends _Entrance {
  const Wipe({
    super.key,
    required super.child,
    super.delay,
    super.whenSeen,
    this.axis = Axis.horizontal,
    this.duration = ErrorMotion.wipe,
  });

  final Axis axis;
  final Duration duration;

  @override
  State<Wipe> createState() => _WipeState();
}

class _WipeState extends _EntranceState<Wipe> {
  @override
  Duration get length => widget.duration;

  @override
  Widget buildMove(BuildContext context, Animation<double> progress) {
    return AnimatedBuilder(
      animation: progress,
      child: widget.child,
      builder: (context, child) => ClipRect(
        clipper: _WipeClipper(progress.value, widget.axis),
        clipBehavior: clock.isCompleted ? Clip.none : Clip.hardEdge,
        child: child,
      ),
    );
  }
}

class _WipeClipper extends CustomClipper<Rect> {
  const _WipeClipper(this.reveal, this.axis);

  final double reveal;
  final Axis axis;

  @override
  Rect getClip(Size size) => switch (axis) {
    Axis.horizontal => Rect.fromLTWH(
      0,
      -size.height,
      size.width * reveal,
      size.height * 3,
    ),
    Axis.vertical => Rect.fromLTWH(
      -size.width,
      0,
      size.width * 3,
      size.height * reveal,
    ),
  };

  @override
  bool shouldReclip(_WipeClipper oldClipper) =>
      oldClipper.reveal != reveal || oldClipper.axis != axis;
}

/// Fades [child] in as it rises 4 px into place, 160 ms ease-out (spec 2.5
/// reveal). Screen readers get it from the first frame; shown at once under
/// reduced motion.
class Reveal extends _Entrance {
  const Reveal({super.key, required super.child, super.delay});

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends _EntranceState<Reveal> {
  @override
  Duration get length => ErrorMotion.reveal;

  @override
  Widget buildMove(BuildContext context, Animation<double> progress) {
    return AnimatedBuilder(
      animation: progress,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: progress.value,
        alwaysIncludeSemantics: true,
        child: Transform.translate(
          offset: Offset(0, ErrorMotion.rise * (1 - progress.value)),
          child: child,
        ),
      ),
    );
  }
}

/// Fades [child] in as it rises 8 px, 220 ms ease-out (spec 2.5 appear);
/// fades only, 150 ms, under reduced motion.
class Appear extends _Entrance {
  const Appear({super.key, required super.child, super.delay, super.whenSeen});

  @override
  State<Appear> createState() => _AppearState();
}

class _AppearState extends _EntranceState<Appear> {
  @override
  Duration get length => IqDurations.appear;

  @override
  bool get fadesWhenReduced => true;

  @override
  Widget buildMove(BuildContext context, Animation<double> progress) {
    return FadeTransition(
      opacity: progress,
      child: AnimatedBuilder(
        animation: progress,
        child: widget.child,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, reduced ? 0 : IqTravel.rise * (1 - progress.value)),
          child: child,
        ),
      ),
    );
  }
}

/// Fades [child] in as it grows from .6 about its centre, 220 ms ease-out
/// (spec 2.5 pop); fades only, 150 ms, under reduced motion.
class Pop extends _Entrance {
  const Pop({super.key, required super.child, super.delay, super.whenSeen});

  @override
  State<Pop> createState() => _PopState();
}

class _PopState extends _EntranceState<Pop> {
  @override
  Duration get length => IqDurations.appear;

  @override
  bool get fadesWhenReduced => true;

  @override
  Widget buildMove(BuildContext context, Animation<double> progress) {
    return FadeTransition(
      opacity: progress,
      child: AnimatedBuilder(
        animation: progress,
        child: widget.child,
        builder: (context, child) => Transform.scale(
          scale: reduced ? 1 : IqScale.pop + (1 - IqScale.pop) * progress.value,
          child: child,
        ),
      ),
    );
  }
}

/// The two ways a list comes in (spec 2.5).
enum StaggerMove {
  /// Fade and rise 12, for data that lands after its page.
  arrive,

  /// Rise 8 only, riding a push.
  settle,
}

/// Plays [move] down a list once, item i starting i × 40 ms in, on one
/// controller; items from the seventh stand still (spec 2.6). With [play]
/// false the items show in place; turning it on plays the move. Under
/// reduced motion arrive fades everything in together, 150 ms.
class Stagger extends StatefulWidget {
  const Stagger({
    super.key,
    required this.child,
    this.move = StaggerMove.arrive,
    this.play = true,
  });

  final Widget child;
  final StaggerMove move;
  final bool play;

  /// How many items move; the rest render in place.
  static const int moving = 6;

  static final Duration _length =
      IqDurations.stagger * (moving - 1) + IqDurations.enter;

  @override
  State<Stagger> createState() => _StaggerState();
}

class _StaggerState extends State<Stagger> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
  );
  bool _reduced = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_started) return;
    _started = true;
    if (widget.play) {
      _play();
    } else {
      _clock.value = 1;
    }
  }

  @override
  void didUpdateWidget(Stagger old) {
    super.didUpdateWidget(old);
    if (widget.play && !old.play) _play();
  }

  void _play() {
    if (_reduced && widget.move == StaggerMove.settle) {
      _clock.value = 1;
      return;
    }
    _clock.duration = _reduced ? IqDurations.crossfade : Stagger._length;
    _clock.forward(from: 0);
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _StaggerScope(
    clock: _clock,
    move: widget.move,
    reduced: _reduced,
    child: widget.child,
  );
}

class _StaggerScope extends InheritedWidget {
  const _StaggerScope({
    required this.clock,
    required this.move,
    required this.reduced,
    required super.child,
  });

  final Animation<double> clock;
  final StaggerMove move;
  final bool reduced;

  @override
  bool updateShouldNotify(_StaggerScope old) =>
      clock != old.clock || move != old.move || reduced != old.reduced;
}

/// One item of the nearest [Stagger], [index] in reading order (titles too).
class StaggerItem extends StatelessWidget {
  const StaggerItem({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_StaggerScope>();
    if (scope == null || index >= Stagger.moving) return child;
    final arrive = scope.move == StaggerMove.arrive;
    if (scope.reduced) {
      if (!arrive) return child;
      return FadeTransition(
        opacity: scope.clock.drive(CurveTween(curve: IqCurves.easeOut)),
        child: child,
      );
    }
    final total = Stagger._length.inMicroseconds;
    final start = IqDurations.stagger * index;
    final t = scope.clock.drive(
      CurveTween(
        curve: Interval(
          start.inMicroseconds / total,
          (start + IqDurations.enter).inMicroseconds / total,
          curve: IqCurves.easeOut,
        ),
      ),
    );
    final rise = arrive ? IqTravel.riseCard : IqTravel.rise;
    final moved = AnimatedBuilder(
      animation: t,
      child: child,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, rise * (1 - t.value)),
        child: child,
      ),
    );
    return arrive ? FadeTransition(opacity: t, child: moved) : moved;
  }
}

/// Rolls the characters of [text] that change: the old slide up 6 and fade
/// out as the new rise from +6 and fade in, 160 ms ease-out, while the rest
/// stand still and the width eases (spec 2.5 roll). A cut under reduced
/// motion; never rolls on its first build.
class RollingText extends StatefulWidget {
  const RollingText(this.text, {super.key, required this.style, this.overflow});

  final String text;
  final TextStyle style;

  /// How the text gives way when it does not fit, between rolls.
  final TextOverflow? overflow;

  @override
  State<RollingText> createState() => _RollingTextState();
}

class _RollingTextState extends State<RollingText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _roll = AnimationController(
    vsync: this,
    duration: IqDurations.tick,
  )..addStatusListener(_onStatus);
  late final Animation<double> _t = _roll.drive(
    CurveTween(curve: IqCurves.easeOut),
  );
  String? _from;

  void _onStatus(AnimationStatus status) {
    if (status.isCompleted && mounted) setState(() => _from = null);
  }

  @override
  void didUpdateWidget(RollingText old) {
    super.didUpdateWidget(old);
    if (old.text == widget.text) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _roll.value = 0;
      _from = null;
      return;
    }
    _from = old.text;
    _roll.forward(from: 0);
  }

  @override
  void dispose() {
    _roll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final from = _from;
    final Widget text;
    if (from == null) {
      text = Text(
        widget.text,
        maxLines: 1,
        softWrap: false,
        overflow: widget.overflow,
        style: widget.style,
      );
    } else {
      text = _rolling(context, from);
    }
    // AnimatedSize cannot run at zero duration, so reduced motion goes
    // without it.
    return Semantics(
      label: widget.text,
      excludeSemantics: true,
      child: MediaQuery.disableAnimationsOf(context)
          ? text
          : AnimatedSize(
              duration: IqDurations.tick,
              curve: IqCurves.easeOut,
              alignment: AlignmentDirectional.centerStart,
              clipBehavior: Clip.none,
              child: text,
            ),
    );
  }

  /// The new text stands with its changed run see-through while that run
  /// rises in over it and the old run leaves; layout is the final string's.
  Widget _rolling(BuildContext context, String from) {
    final base = DefaultTextStyle.of(context).style.merge(widget.style);
    final clear = base.copyWith(color: base.color?.withValues(alpha: 0));
    final to = widget.text.characters.toList();
    final was = from.characters.toList();
    var head = 0;
    while (head < to.length && head < was.length && to[head] == was[head]) {
      head++;
    }
    var tail = 0;
    while (tail < to.length - head &&
        tail < was.length - head &&
        to[to.length - 1 - tail] == was[was.length - 1 - tail]) {
      tail++;
    }
    TextSpan spans(List<String> chars, {required bool moving}) {
      final still = moving ? clear : null;
      final changed = moving ? null : clear;
      return TextSpan(
        style: base,
        children: [
          TextSpan(text: chars.take(head).join(), style: still),
          TextSpan(
            text: chars.sublist(head, chars.length - tail).join(),
            style: changed,
          ),
          TextSpan(
            text: chars.sublist(chars.length - tail).join(),
            style: still,
          ),
        ],
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Text.rich(spans(to, moving: false), maxLines: 1, softWrap: false),
        Positioned(
          left: 0,
          top: 0,
          child: AnimatedBuilder(
            animation: _t,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, -IqTravel.tick * _t.value),
              child: Opacity(opacity: 1 - _t.value, child: child),
            ),
            child: Text.rich(
              spans(was, moving: true),
              maxLines: 1,
              softWrap: false,
            ),
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          child: AnimatedBuilder(
            animation: _t,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, IqTravel.tick * (1 - _t.value)),
              child: Opacity(opacity: _t.value, child: child),
            ),
            child: RichText(
              text: spans(to, moving: true),
              maxLines: 1,
              softWrap: false,
              textScaler: MediaQuery.textScalerOf(context),
              textDirection: Directionality.of(context),
            ),
          ),
        ),
      ],
    );
  }
}

/// Counts from 0 up to [value] over 600 ms ease-out once seen, laid out at
/// the final figure's width so nothing reflows (spec 2.5 count); the final
/// figure at once under reduced motion. [format] writes the figure.
class CountUp extends StatefulWidget {
  const CountUp({
    super.key,
    required this.value,
    required this.style,
    this.format,
  });

  final int value;
  final TextStyle style;
  final String Function(int value)? format;

  @override
  State<CountUp> createState() => _CountUpState();
}

class _CountUpState extends State<CountUp> with SingleTickerProviderStateMixin {
  late final AnimationController _count = AnimationController(
    vsync: this,
    duration: IqDurations.fill,
  );
  late final Animation<double> _t = _count.drive(
    CurveTween(curve: IqCurves.easeOut),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _count.value = 1;
  }

  void _start() {
    if (mounted && _count.isDismissed) _count.forward();
  }

  @override
  void dispose() {
    _count.dispose();
    super.dispose();
  }

  String _write(int value) => widget.format?.call(value) ?? '$value';

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    final painter = TextPainter(
      text: TextSpan(text: _write(widget.value), style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width.ceilToDouble();
    painter.dispose();
    return Semantics(
      label: _write(widget.value),
      excludeSemantics: true,
      child: FirstSeen(
        onSeen: _start,
        child: SizedBox(
          width: width,
          child: AnimatedBuilder(
            animation: _t,
            builder: (context, _) => Text(
              _write((widget.value * _t.value).round()),
              maxLines: 1,
              softWrap: false,
              style: widget.style,
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows [child] while [open] (spec 2.5): closing folds its height away in
/// 200 ms ease-in as it fades in 150; opening unfolds in 240 ms ease-out,
/// then the child arrives. A cut under reduced motion.
class Collapse extends StatefulWidget {
  const Collapse({super.key, required this.open, required this.child});

  final bool open;
  final Widget child;

  @override
  State<Collapse> createState() => _CollapseState();
}

class _CollapseState extends State<Collapse> with TickerProviderStateMixin {
  late final AnimationController _size = AnimationController(
    vsync: this,
    value: widget.open ? 1 : 0,
  );
  late final AnimationController _fade = AnimationController(
    vsync: this,
    value: widget.open ? 1 : 0,
  );

  @override
  void didUpdateWidget(Collapse old) {
    super.didUpdateWidget(old);
    if (old.open == widget.open) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _size.value = _fade.value = widget.open ? 1 : 0;
    } else if (widget.open) {
      _size
          .animateTo(1, duration: IqDurations.mark, curve: IqCurves.easeOut)
          .whenCompleteOrCancel(() {
            if (mounted && widget.open && _size.isCompleted) {
              _fade.animateTo(
                1,
                duration: IqDurations.enter,
                curve: IqCurves.easeOut,
              );
            }
          });
    } else {
      _fade.animateBack(
        0,
        duration: IqDurations.crossfade,
        curve: IqCurves.easeIn,
      );
      _size.animateBack(0, duration: IqDurations.swap, curve: IqCurves.easeIn);
    }
  }

  @override
  void dispose() {
    _size.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _size,
      alignment: const Alignment(-1, -1),
      child: FadeTransition(
        opacity: _fade,
        child: AnimatedBuilder(
          animation: _fade,
          child: widget.child,
          builder: (context, child) => Transform.translate(
            offset: Offset(
              0,
              widget.open ? IqTravel.riseCard * (1 - _fade.value) : 0,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The fade-through's two halves on a 0 to 1 switch (spec 2.5): the new
/// child fades in from 20% ease-out, the old one is gone by 40% ease-in.
abstract final class FadeThroughCurves {
  /// The incoming child's opacity.
  static const Curve incoming = Interval(0.2, 1, curve: IqCurves.easeOut);

  /// How far the outgoing child has faded.
  static const Curve outgoing = Interval(0, 0.4, curve: IqCurves.easeIn);
}

/// Swaps [child], told apart by its key, with the fade-through: nothing
/// moves, 200 ms, a cut under reduced motion (spec 2.5).
class FadeThrough extends StatelessWidget {
  const FadeThrough({
    super.key,
    required this.child,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: motion(context, IqDurations.swap),
      switchInCurve: FadeThroughCurves.incoming,
      // The outgoing child runs its animation from 1 back to 0, so its half
      // is flipped to read forward in time.
      switchOutCurve: const FlippedCurve(FadeThroughCurves.outgoing),
      layoutBuilder: (current, previous) =>
          Stack(alignment: alignment, children: [...previous, ?current]),
      child: child,
    );
  }
}

/// What a [SkeletonGate] shows (spec 2.6).
enum GatePhase {
  /// Paper, for the first 300 ms of a load.
  waiting,

  /// The skeleton, held at least 600 ms once shown.
  skeleton,

  /// The skeleton fading out over the content as it arrives.
  handover,

  /// The content.
  content,
}

/// Builds a [SkeletonGate.builder] for [phase]; [skeletonOpacity] runs the
/// skeleton's fade in the hand-over and stands at 1 before it.
typedef SkeletonGateBuilder = Widget Function(
  BuildContext context,
  GatePhase phase,
  Animation<double> skeletonOpacity,
);

/// The spec's LoadingGate (spec 2.6, 5.15), the wait for a list's data:
/// paper for 300 ms; then, if it is still loading, the skeleton, held at
/// least 600 ms; then the skeleton fades out over 150 ms ease-in while the
/// content arrives from +60. Data inside 300 ms goes straight to the
/// content. [onOpen] runs when a load opens onto the content, with how long
/// the content's arrival waits, so the screen can play its arrive. Reduced
/// motion keeps the timings and makes the hand-over a 150 ms crossfade.
class SkeletonGate extends StatefulWidget {
  /// Shows [skeleton], then [child], in one box.
  const SkeletonGate({
    super.key,
    required this.loading,
    required Widget this.skeleton,
    required Widget this.child,
    this.onOpen,
  }) : builder = null;

  /// Lets the screen place each phase itself (as slivers, say).
  const SkeletonGate.builder({
    super.key,
    required this.loading,
    required SkeletonGateBuilder this.builder,
    this.onOpen,
  }) : skeleton = null,
       child = null;

  final bool loading;
  final Widget? skeleton;
  final Widget? child;
  final SkeletonGateBuilder? builder;
  final ValueChanged<Duration>? onOpen;

  @override
  State<SkeletonGate> createState() => _SkeletonGateState();
}

class _SkeletonGateState extends State<SkeletonGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: IqDurations.crossfade,
    animationBehavior: AnimationBehavior.preserve,
  )..addStatusListener(_onFade);
  late final Animation<double> _skeletonOpacity = ReverseAnimation(
    _fade.drive(CurveTween(curve: IqCurves.easeIn)),
  );
  GatePhase _phase = GatePhase.content;
  Timer? _wait;
  Timer? _hold;
  bool _held = true;
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    if (widget.loading) _start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void didUpdateWidget(SkeletonGate old) {
    super.didUpdateWidget(old);
    if (widget.loading && !old.loading) _start();
    if (!widget.loading && old.loading) _land();
  }

  void _start() {
    _wait?.cancel();
    _hold?.cancel();
    _fade.value = 0;
    _held = true;
    _phase = GatePhase.waiting;
    _wait = Timer(IqDurations.skeletonDelay, () {
      if (!mounted || !widget.loading) return;
      setState(() {
        _phase = GatePhase.skeleton;
        _held = false;
        _hold = Timer(IqDurations.skeletonMin, () {
          _held = true;
          if (mounted && !widget.loading) setState(_handOver);
        });
      });
    });
  }

  void _land() {
    switch (_phase) {
      case GatePhase.waiting:
        _wait?.cancel();
        _phase = GatePhase.content;
        widget.onOpen?.call(Duration.zero);
      case GatePhase.skeleton:
        if (_held) _handOver();
      case GatePhase.handover || GatePhase.content:
        break;
    }
  }

  void _handOver() {
    _phase = GatePhase.handover;
    _fade.forward(from: 0);
    widget.onOpen?.call(_reduced ? Duration.zero : IqDurations.lag);
  }

  void _onFade(AnimationStatus status) {
    if (status.isCompleted && mounted && _phase == GatePhase.handover) {
      setState(() => _phase = GatePhase.content);
    }
  }

  @override
  void dispose() {
    _wait?.cancel();
    _hold?.cancel();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final builder = widget.builder;
    if (builder != null) return builder(context, _phase, _skeletonOpacity);
    final content = _phase == GatePhase.handover || _phase == GatePhase.content;
    final skeleton =
        _phase == GatePhase.skeleton || _phase == GatePhase.handover;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        if (content)
          KeyedSubtree(key: const ValueKey('content'), child: widget.child!),
        if (skeleton)
          KeyedSubtree(
            key: const ValueKey('skeleton'),
            child: IgnorePointer(
              ignoring: _phase == GatePhase.handover,
              child: FadeTransition(
                opacity: _skeletonOpacity,
                child: widget.skeleton!,
              ),
            ),
          ),
      ],
    );
  }
}

/// Plays a list's arrive (spec 2.6, 5.17) through the [Arrivals] it is
/// given to.
class ArrivalsController {
  _ArrivalsState? _state;
  Duration? _pending;

  /// Opens a wave: the [ArriveItem]s built for the first time before the
  /// frame ends arrive in reading order, 40 ms apart, after [after]. Call it
  /// when data the person waited for lands (a first load, a new page, new
  /// items from a refresh), never for revisits or lens changes.
  void play({Duration after = Duration.zero}) {
    final state = _state;
    if (state == null) {
      _pending = after;
    } else {
      state._play(after);
    }
  }
}

/// Hosts the arrive waves of the list below it (spec 2.6): each wave runs on
/// one clock, and every [ArriveItem] reads its own interval of it.
class Arrivals extends StatefulWidget {
  const Arrivals({super.key, required this.controller, required this.child});

  final ArrivalsController controller;
  final Widget child;

  @override
  State<Arrivals> createState() => _ArrivalsState();
}

class _ArrivalsState extends State<Arrivals> with TickerProviderStateMixin {
  final _waves = <_Wave>[];
  _Wave? _open;
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    _attach(widget.controller);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    final pending = widget.controller._pending;
    if (pending != null) {
      widget.controller._pending = null;
      _play(pending);
    }
  }

  @override
  void didUpdateWidget(Arrivals old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      if (old.controller._state == this) old.controller._state = null;
      _attach(widget.controller);
    }
  }

  void _attach(ArrivalsController controller) => controller._state = this;

  void _play(Duration after) {
    final wave = _Wave(this, _reduced ? Duration.zero : after, _reduced);
    _waves.add(wave);
    _open = wave;
    wave.clock.forward();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (identical(_open, wave)) _open = null;
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  _Slot? _join() {
    final wave = _open;
    if (wave == null || wave.joined >= Stagger.moving) return null;
    return _Slot(wave, wave.joined++);
  }

  @override
  void dispose() {
    if (widget.controller._state == this) widget.controller._state = null;
    for (final wave in _waves) {
      wave.clock.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _ArrivalsScope(state: this, child: widget.child);
}

class _ArrivalsScope extends InheritedWidget {
  const _ArrivalsScope({required this.state, required super.child});

  final _ArrivalsState state;

  @override
  bool updateShouldNotify(_ArrivalsScope old) => false;
}

class _Wave {
  _Wave(TickerProvider vsync, this.after, this.reduced)
    : clock = AnimationController(
        vsync: vsync,
        duration: reduced ? IqDurations.crossfade : after + _span,
        animationBehavior: AnimationBehavior.preserve,
      );

  /// Six slots 40 apart, the last one's Highlight included.
  static final Duration _span =
      IqDurations.stagger * (Stagger.moving - 1) +
      ArriveItem.markLead +
      IqDurations.mark;

  final AnimationController clock;
  final Duration after;
  final bool reduced;
  int joined = 0;

  Animation<double> span(Duration from, Duration length) {
    final total = clock.duration!.inMicroseconds;
    final start = (from.inMicroseconds / total).clamp(0.0, 1.0);
    final end = ((from + length).inMicroseconds / total).clamp(start, 1.0);
    return clock.drive(
      CurveTween(curve: Interval(start, end, curve: IqCurves.easeOut)),
    );
  }
}

class _Slot {
  _Slot(this.wave, this.index);

  final _Wave wave;
  final int index;

  Duration get start => wave.after + IqDurations.stagger * index;

  Animation<double> arrive() => wave.reduced
      ? wave.clock.drive(CurveTween(curve: IqCurves.easeOut))
      : wave.span(start, IqDurations.enter);

  Animation<double> beat(Duration lead, Duration length) =>
      wave.reduced ? kAlwaysCompleteAnimation : wave.span(start + lead, length);
}

/// One item of the nearest [Arrivals] in reading order (titles count). Built
/// for the first time while a wave is open, it takes the wave's next slot
/// and arrives: fade and rise 12 over 260 ms ease-out, 40 ms after the slot
/// before; from the seventh slot on, or with no wave open, it stands in
/// place. Under reduced motion a wave fades in together over 150 ms. It
/// keeps itself alive in a lazy list, so it never arrives twice.
class ArriveItem extends StatefulWidget {
  const ArriveItem({super.key, required this.child});

  final Widget child;

  /// A Highlight in an arriving row wipes this long after the row starts
  /// (spec 5.13).
  static const markLead = Duration(milliseconds: 120);

  /// A SectionTitle's underline wipes this long after the title starts
  /// (spec 5.25).
  static const underlineLead = Duration(milliseconds: 60);

  /// A beat of the arriving item around [context]: [lead] after the item
  /// starts, over [length], ease-out (shown at once under reduced motion).
  /// Null when there is no item or it is not arriving, so a mark falls back
  /// to playing when first seen.
  static Animation<double>? beatOf(
    BuildContext context, {
    required Duration lead,
    required Duration length,
  }) => context.dependOnInheritedWidgetOfExactType<_ArriveCue>()?.slot?.beat(
    lead,
    length,
  );

  @override
  State<ArriveItem> createState() => _ArriveItemState();
}

class _ArriveItemState extends State<ArriveItem>
    with AutomaticKeepAliveClientMixin {
  _Slot? _slot;
  Animation<double>? _move;
  bool _joined = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_joined) return;
    _joined = true;
    _slot = context
        .getInheritedWidgetOfExactType<_ArrivalsScope>()
        ?.state
        ._join();
    _move = _slot?.arrive();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final move = _move;
    var child = widget.child;
    if (move != null) {
      child = FadeTransition(
        opacity: move,
        child: _slot!.wave.reduced
            ? child
            : AnimatedBuilder(
                animation: move,
                child: child,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, IqTravel.riseCard * (1 - move.value)),
                  child: child,
                ),
              ),
      );
    }
    return _ArriveCue(slot: _slot, child: child);
  }
}

class _ArriveCue extends InheritedWidget {
  const _ArriveCue({required this.slot, required super.child});

  final _Slot? slot;

  @override
  bool updateShouldNotify(_ArriveCue old) => slot != old.slot;
}

/// Fades [child] in as it rises 16, 320 ms ease-out, the way illustrations
/// and hero icons arrive (spec 5.29); fades only, 150 ms, under reduced
/// motion.
class RiseIn extends _Entrance {
  const RiseIn({super.key, required super.child, super.delay, super.whenSeen});

  @override
  State<RiseIn> createState() => _RiseInState();
}

class _RiseInState extends _EntranceState<RiseIn> {
  @override
  Duration get length => IqDurations.illustration;

  @override
  bool get fadesWhenReduced => true;

  @override
  Widget buildMove(BuildContext context, Animation<double> progress) {
    return FadeTransition(
      opacity: progress,
      child: AnimatedBuilder(
        animation: progress,
        child: widget.child,
        builder: (context, child) => Transform.translate(
          offset: Offset(
            0,
            reduced ? 0 : IqTravel.riseHero * (1 - progress.value),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Calls [onSeen] once at least half of [child] is painted inside the
/// screen and its scroll views (spec 2.6), and [onVisible] when that flips.
/// It checks after frames the app draws anyway and never asks for one.
class FirstSeen extends StatefulWidget {
  const FirstSeen({
    super.key,
    required this.child,
    this.onSeen,
    this.onVisible,
  });

  final Widget child;
  final VoidCallback? onSeen;
  final ValueChanged<bool>? onVisible;

  @override
  State<FirstSeen> createState() => _FirstSeenState();
}

class _FirstSeenState extends State<FirstSeen> {
  final _after = _AfterFrame();
  bool _seen = false;
  bool? _visible;
  bool _ticking = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ticking = TickerMode.valuesOf(context).enabled;
    _after.arm(_check);
  }

  @override
  void didUpdateWidget(FirstSeen old) {
    super.didUpdateWidget(old);
    _after.arm(_check);
  }

  void _check() {
    if (!mounted) return;
    final visible = _ticking && _onScreen(context);
    if (visible != _visible) {
      _visible = visible;
      widget.onVisible?.call(visible);
    }
    if (visible && !_seen) {
      _seen = true;
      widget.onSeen?.call();
    }
    if (!_seen || widget.onVisible != null) _after.arm(_check);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Who gets a screen's one looping signal, first to last (spec 2.6).
enum PulsePriority {
  typing,
  urgentBanner,
  hotCountdown,
  checking,
  currentRing,
  proofBreath,
}

/// Grants one looping attention signal at a time (spec 2.6): of the
/// claimants on screen, the highest priority wins, reading order breaking
/// ties; the grant moves as they scroll. Every route page has one; outside
/// a scope every claim is granted.
class PulseScope extends StatefulWidget {
  const PulseScope({super.key, required this.child});

  final Widget child;

  /// Claims the pulse for [context]; [onChange] runs as the grant moves.
  static PulseClaim claim(
    BuildContext context,
    PulsePriority priority,
    VoidCallback onChange,
  ) {
    final scope = context
        .getInheritedWidgetOfExactType<_PulseScopeMarker>()
        ?.state;
    final claim = PulseClaim._(context, priority, onChange, scope);
    scope?._add(claim);
    return claim;
  }

  /// Joins the skeleton beat of the screen around [context] (spec 5.15);
  /// null outside a scope. Skeletons are exempt from the one-pulse rule.
  static SkeletonBeat? joinSkeletonBeat(BuildContext context) => context
      .getInheritedWidgetOfExactType<_PulseScopeMarker>()
      ?.state
      ._joinBeat();

  @override
  State<PulseScope> createState() => _PulseScopeState();
}

/// A skeleton's place on its screen's beat (spec 5.15): every bar on a
/// screen pulses .5 to 1 to .5 over 900 ms in phase, on one clock that the
/// screen's [PulseScope] runs while any skeleton is on it, so a skeleton
/// mounted later joins the beat. Leave it from the skeleton's dispose.
class SkeletonBeat {
  SkeletonBeat._(this.opacity, this._leave);

  /// The bars' opacity.
  final Animation<double> opacity;
  final VoidCallback _leave;

  /// Gives the beat back; the clock stops with the last skeleton.
  void leave() => _leave();

  /// The bars' opacity on [clock], one cycle per turn of the clock.
  static Animation<double> on(Animation<double> clock) =>
      TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0.5, end: 1), weight: 1),
        TweenSequenceItem(tween: Tween(begin: 1, end: 0.5), weight: 1),
      ]).chain(CurveTween(curve: IqCurves.easeInOut)).animate(clock);
}

/// A claimant's hold on its screen's pulse.
class PulseClaim {
  PulseClaim._(this._context, this._priority, this._onChange, this._scope)
    : _granted = _scope == null;

  final BuildContext _context;
  final PulsePriority _priority;
  final VoidCallback _onChange;
  final _PulseScopeState? _scope;
  bool _granted;

  /// Whether the claimant may loop now; otherwise it draws its still look.
  bool get granted => _granted;

  /// Gives the pulse back; call from the claimant's dispose.
  void dispose() => _scope?._remove(this);
}

class _PulseScopeMarker extends InheritedWidget {
  const _PulseScopeMarker({required this.state, required super.child});

  final _PulseScopeState state;

  @override
  bool updateShouldNotify(_PulseScopeMarker old) => false;
}

class _PulseScopeState extends State<PulseScope>
    with SingleTickerProviderStateMixin {
  final _claims = <PulseClaim>[];
  final _after = _AfterFrame();
  AnimationController? _beat;
  Animation<double>? _beatOpacity;
  int _beaters = 0;
  bool _gone = false;

  SkeletonBeat _joinBeat() {
    final beat = _beat ??= AnimationController(
      vsync: this,
      duration: IqDurations.skeletonPulse,
    );
    final opacity = _beatOpacity ??= SkeletonBeat.on(beat);
    if (_beaters++ == 0) beat.repeat();
    var left = false;
    return SkeletonBeat._(opacity, () {
      if (left) return;
      left = true;
      if (--_beaters == 0 && !_gone) beat.stop();
    });
  }

  @override
  void dispose() {
    _gone = true;
    _beat?.dispose();
    super.dispose();
  }

  void _add(PulseClaim claim) {
    _claims.add(claim);
    _after.arm(_resolve);
  }

  void _remove(PulseClaim claim) {
    _claims.remove(claim);
    if (claim._granted) _after.arm(_resolve);
  }

  void _resolve() {
    if (!mounted || _claims.isEmpty) return;
    PulseClaim? winner;
    Offset? winnerAt;
    for (final claim in _claims) {
      final context = claim._context;
      if (!context.mounted || !_onScreen(context)) continue;
      final at = (context.findRenderObject()! as RenderBox).localToGlobal(
        Offset.zero,
      );
      if (winner == null ||
          claim._priority.index < winner._priority.index ||
          (claim._priority == winner._priority &&
              (at.dy < winnerAt!.dy ||
                  (at.dy == winnerAt.dy && at.dx < winnerAt.dx)))) {
        winner = claim;
        winnerAt = at;
      }
    }
    for (final claim in List.of(_claims)) {
      final granted = identical(claim, winner);
      if (claim._granted != granted) {
        claim._granted = granted;
        claim._onChange();
      }
    }
    _after.arm(_resolve);
  }

  @override
  Widget build(BuildContext context) =>
      _PulseScopeMarker(state: this, child: widget.child);
}

/// For a looping attention signal (spec 2.6): [syncPulse] claims the
/// screen's pulse while [wantsPulse] and runs [pulse] only while it is
/// granted and motion is on; [pulsing] says whether to draw the loop or the
/// still look.
mixin PulseLoop<T extends StatefulWidget> on State<T> {
  /// The loop's controller, owned and disposed by the claimant.
  AnimationController get pulse;

  /// Where the signal ranks for the grant.
  PulsePriority get pulsePriority;

  /// Whether the claimant has a loop to show now.
  bool get wantsPulse;

  PulseClaim? _claim;
  bool _pulsing = false;
  bool _reducedPulse = false;

  /// Whether the loop runs; otherwise the claimant draws its still look.
  bool get pulsing => _pulsing;

  /// Call from didChangeDependencies and whenever [wantsPulse] may change.
  void syncPulse() {
    _reducedPulse = MediaQuery.disableAnimationsOf(context);
    if (wantsPulse) {
      _claim ??= PulseScope.claim(context, pulsePriority, _onGrant);
    } else {
      _claim?.dispose();
      _claim = null;
    }
    _apply();
  }

  void _onGrant() {
    if (mounted) setState(_apply);
  }

  void _apply() {
    final run = wantsPulse && (_claim?.granted ?? false) && !_reducedPulse;
    if (run == _pulsing) return;
    _pulsing = run;
    if (run) {
      pulse.repeat();
    } else {
      pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _claim?.dispose();
    super.dispose();
  }
}

/// Runs a check after the next frame the app draws, once per frame, without
/// asking for a frame of its own.
class _AfterFrame {
  bool _armed = false;

  void arm(VoidCallback check) {
    if (_armed) return;
    _armed = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _armed = false;
      check();
    });
  }
}

/// Whether at least half of [context]'s box is painted inside the screen and
/// every scroll view around it.
bool _onScreen(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize) return false;
  if (box.size.isEmpty) return false;
  RenderObject child = box;
  var screen = box;
  for (var parent = box.parent; parent != null; parent = parent.parent) {
    if (!parent.paintsChild(child)) return false;
    if (parent is RenderBox) screen = parent;
    child = parent;
  }
  final bounds = MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  );
  var seen = bounds.intersect(Offset.zero & screen.size);
  for (
    var scroll = context.findAncestorStateOfType<ScrollableState>();
    scroll != null;
    scroll = scroll.context.findAncestorStateOfType<ScrollableState>()
  ) {
    final viewport = scroll.context.findRenderObject();
    if (viewport is RenderBox && viewport.hasSize) {
      seen = seen.intersect(
        MatrixUtils.transformRect(
          viewport.getTransformTo(null),
          Offset.zero & viewport.size,
        ),
      );
    }
  }
  if (seen.width <= 0 || seen.height <= 0) return false;
  return seen.width * seen.height * 2 >= bounds.width * bounds.height;
}
