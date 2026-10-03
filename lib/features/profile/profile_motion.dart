/// Every motion value the Profile and settings screens use, named after the
/// motion spec's tokens (MOTION-SPEC §2), so they swap for the shared
/// IqCurves, IqDurations, IqTravel and IqHaptics in this one file. Import it
/// with the `motion` prefix.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

const easeOut = Curves.easeOut;

/// The autosave check pop, about 4% overshoot on a .6 to 1 scale.
const stamp = Cubic(0.175, 0.885, 0.32, 1.275);

const crossfade = Duration(milliseconds: 150);
const tick = Duration(milliseconds: 160);
const swap = Duration(milliseconds: 200);
const appear = Duration(milliseconds: 220);
const mark = Duration(milliseconds: 240);
const enter = Duration(milliseconds: 260);
const screen = Duration(milliseconds: 300);
const screenBack = Duration(milliseconds: 240);
const morph = Duration(milliseconds: 320);
const stagger = Duration(milliseconds: 40);

/// A moment's title and body appear after its illustration (§6.8, §6.11).
const momentTitleAt = Duration(milliseconds: 80);
const momentBodyAt = Duration(milliseconds: 120);

/// IqTravel, in px.
const double rise = 8;
const double riseCard = 12;
const double riseHero = 16;
const double screenShift = 24;

const double popFrom = .6;
const double restampFrom = 1.15;

/// Items after the sixth render in place: a stagger covers the first
/// viewport only.
const staggerCap = 6;

/// [normal] under the current reduced-motion setting: zero, or the
/// crossfade for anything that must still read as a change.
Duration duration(BuildContext context, Duration normal, {bool fade = false}) {
  if (!MediaQuery.disableAnimationsOf(context)) return normal;
  return fade ? crossfade : Duration.zero;
}

Future<void> selectHaptic() => HapticFeedback.selectionClick();
Future<void> commitHaptic() => HapticFeedback.lightImpact();
Future<void> destructiveHaptic() => HapticFeedback.mediumImpact();
Future<void> successHaptic() => HapticFeedback.successNotification();

/// One controller for a screen's entrance (the spec's Stagger): each [Cue]
/// below plays its move on its own Interval of it. [play] false renders
/// everything in place (tab revisits). Under reduced motion the fading cues
/// fade in together over the crossfade and the rest show in place.
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.length,
    required this.child,
    this.play = true,
  });

  final Duration length;
  final Widget child;
  final bool play;

  /// A list of [slots] items arriving 40 apart.
  static Duration listLength(int slots) =>
      stagger * (slots.clamp(1, staggerCap) - 1) + enter;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.length,
    animationBehavior: AnimationBehavior.preserve,
  );
  bool _started = false;
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (!widget.play) {
      _controller.value = 1;
      return;
    }
    if (_reduced) _controller.duration = crossfade;
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _EntranceScope(
    animation: _controller,
    reduced: _reduced,
    length: widget.length,
    child: widget.child,
  );
}

class _EntranceScope extends InheritedWidget {
  const _EntranceScope({
    required this.animation,
    required this.reduced,
    required this.length,
    required super.child,
  });

  final Animation<double> animation;
  final bool reduced;
  final Duration length;

  @override
  bool updateShouldNotify(_EntranceScope old) =>
      animation != old.animation || reduced != old.reduced;
}

/// A move on the [Entrance] above: from [at] for [length], the child rises
/// [travel] px into place and, unless [fade] is false (settle), fades in.
class Cue extends StatelessWidget {
  const Cue({
    super.key,
    required this.child,
    this.at = Duration.zero,
    this.length = enter,
    this.travel = riseCard,
    this.fade = true,
  });

  /// Arrive (fade and rise 12, 260 EO) in list slot [slot], 40 apart.
  factory Cue.arrive(int slot, {Key? key, required Widget child}) => Cue(
    key: key,
    at: stagger * slot,
    length: slot < staggerCap ? enter : Duration.zero,
    child: child,
  );

  /// Settle (rise 8, 260 EO, opacity untouched): pushed content that is
  /// ready rides the push.
  factory Cue.settle(int slot, {Key? key, required Widget child}) => Cue(
    key: key,
    at: stagger * slot,
    length: slot < staggerCap ? enter : Duration.zero,
    travel: rise,
    fade: false,
    child: child,
  );

  /// Appear (fade and rise 8, 220 EO) from [at].
  const Cue.appear({super.key, required this.child, this.at = Duration.zero})
    : length = appear,
      travel = rise,
      fade = true;

  /// An illustration arriving: fade and rise 16 over 320 EO.
  const Cue.hero({super.key, required this.child, this.at = Duration.zero})
    : length = morph,
      travel = riseHero,
      fade = true;

  final Widget child;
  final Duration at;
  final Duration length;
  final double travel;
  final bool fade;

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_EntranceScope>();
    if (scope == null || length == Duration.zero) return child;
    if (scope.reduced) {
      return fade
          ? FadeTransition(
              opacity: scope.animation,
              alwaysIncludeSemantics: true,
              child: child,
            )
          : child;
    }
    final total = scope.length.inMicroseconds;
    final begin = (at.inMicroseconds / total).clamp(0.0, 1.0);
    final end = ((at + length).inMicroseconds / total).clamp(begin, 1.0);
    final progress = scope.animation.drive(
      CurveTween(curve: Interval(begin, end, curve: easeOut)),
    );
    final moving = AnimatedBuilder(
      animation: progress,
      child: child,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, travel * (1 - progress.value)),
        child: child,
      ),
    );
    if (!fade) return moving;
    return FadeTransition(
      opacity: progress,
      alwaysIncludeSemantics: true,
      child: moving,
    );
  }
}

/// Lands [child] each time [trigger] changes, and on its first build when
/// [onMount] is set: scale [from] to 1 on the stamp curve with the opacity
/// on the first half (a pop from .6), or a re-stamp from 1.15 over 160 EO.
/// With [hideAtRest] it draws only while landing, so an overlay can stamp
/// over its twin. Reduced motion: shown at once.
class Stamp extends StatefulWidget {
  const Stamp({
    super.key,
    required this.trigger,
    required this.child,
    this.from = popFrom,
    this.hideAtRest = false,
    this.onMount = false,
  });

  final int trigger;
  final Widget child;
  final double from;
  final bool hideAtRest;
  final bool onMount;

  @override
  State<Stamp> createState() => _StampState();
}

class _StampState extends State<Stamp> with SingleTickerProviderStateMixin {
  late final AnimationController _land = AnimationController(
    vsync: this,
    duration: widget.from < 1 ? swap : tick,
    value: 1,
  );
  late final Animation<double> _scale = _land.drive(
    Tween(
      begin: widget.from,
      end: 1.0,
    ).chain(CurveTween(curve: widget.from < 1 ? stamp : easeOut)),
  );
  late final Animation<double> _opacity = widget.from < 1
      ? _land.drive(CurveTween(curve: const Interval(0, .5, curve: easeOut)))
      : kAlwaysCompleteAnimation;
  bool _mounted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_mounted) return;
    _mounted = true;
    if (widget.onMount && !MediaQuery.disableAnimationsOf(context)) {
      _land.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(Stamp old) {
    super.didUpdateWidget(old);
    if (old.trigger == widget.trigger) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _land.value = 1;
    } else {
      _land.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _land.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final landed = ScaleTransition(
      scale: _scale,
      child: FadeTransition(opacity: _opacity, child: widget.child),
    );
    if (!widget.hideAtRest) return landed;
    return AnimatedBuilder(
      animation: _land,
      child: landed,
      builder: (context, child) =>
          _land.isAnimating ? child! : const SizedBox(),
    );
  }
}

/// Push (§3.1, §3.2): the page comes in from +24 and fades in over the
/// first 60% of 300 EO; back reverses over 240, so it leaves looking EI.
/// iOS keeps the native page and its edge swipe (the spec's fallback).
/// Reduced motion: a 150 crossfade.
Page<void> pushPage(BuildContext context, GoRouterState state, Widget child) {
  final reduced = MediaQuery.disableAnimationsOf(context);
  if (!reduced && Theme.of(context).platform == TargetPlatform.iOS) {
    return CupertinoPage<void>(key: state.pageKey, child: child);
  }
  return _MotionPage(
    key: state.pageKey,
    duration: reduced ? crossfade : screen,
    reverseDuration: reduced ? crossfade : screenBack,
    transitions: (context, animation, secondaryAnimation, child) {
      if (reduced) return FadeTransition(opacity: animation, child: child);
      final shift = animation.drive(CurveTween(curve: easeOut));
      final opacity = animation.drive(
        CurveTween(curve: const Interval(0, .6, curve: easeOut)),
      );
      return FadeTransition(
        opacity: opacity,
        child: AnimatedBuilder(
          animation: shift,
          child: child,
          builder: (context, child) => Transform.translate(
            offset: Offset(screenShift * (1 - shift.value), 0),
            child: child,
          ),
        ),
      );
    },
    child: child,
  );
}

/// Flow hand-off (§3.5): the next flow fades in over 300 EO on top of the
/// last, which stays still. Reduced motion: 150.
Page<void> handoffPage(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  final reduced = MediaQuery.disableAnimationsOf(context);
  return _MotionPage(
    key: state.pageKey,
    duration: reduced ? crossfade : screen,
    reverseDuration: reduced ? crossfade : screen,
    transitions: (context, animation, secondaryAnimation, child) =>
        FadeTransition(
          opacity: animation.drive(CurveTween(curve: easeOut)),
          child: child,
        ),
    child: child,
  );
}

class _MotionPage extends Page<void> {
  const _MotionPage({
    super.key,
    required this.child,
    required this.duration,
    required this.reverseDuration,
    required this.transitions,
  });

  final Widget child;
  final Duration duration;
  final Duration reverseDuration;
  final RouteTransitionsBuilder transitions;

  @override
  Route<void> createRoute(BuildContext context) => _MotionRoute(this);
}

/// Its controller keeps its duration under reduced motion (Flutter would
/// cut it to 5%), so the reduced-motion crossfade really takes 150.
class _MotionRoute extends PageRoute<void> {
  _MotionRoute(_MotionPage page) : super(settings: page);

  _MotionPage get _page => settings as _MotionPage;

  @override
  Duration get transitionDuration => _page.duration;

  @override
  Duration get reverseTransitionDuration => _page.reverseDuration;

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  AnimationController createAnimationController() => AnimationController(
    duration: transitionDuration,
    reverseDuration: reverseTransitionDuration,
    debugLabel: debugLabel,
    vsync: navigator!,
    animationBehavior: AnimationBehavior.preserve,
  );

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => Semantics(
    scopesRoute: true,
    explicitChildNodes: true,
    child: _page.child,
  );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => _page.transitions(context, animation, secondaryAnimation, child);
}
