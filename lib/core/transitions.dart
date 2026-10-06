import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../theme/theme.dart';
import 'motion.dart';

/// Which way a page move reads (spec 4.1): pass [NavDirection.back] as the
/// `extra` of a `go` that steps back, and the page mirrors the push.
enum NavDirection { forward, back }

/// Where a hand-off starts (spec 3.5): pass [Arrival.splash] as `extra` for
/// the Figma 400 ms dissolve, [Arrival.lockup] when the splash has already
/// moved its wordmark onto the landing logo (spec 3.9), so the page takes
/// over with no transition, and [Arrival.sheet] for the page a sheet was
/// dragged up into: it fades in over the sheet, now blank paper filling the
/// screen, and leaves as a push does.
enum Arrival { splash, lockup, sheet }

/// The scrims under sheets and overlays, from their Figma frames (spec 2.3).
abstract final class IqScrim {
  /// Filters, Polls, Withdraw and the ConfirmSheet.
  static final Color sheet = _brand(IqOpacity.sheetScrim);

  /// The picker sheets.
  static final Color picker = _brand(IqOpacity.pickerScrim);

  /// The share sheet.
  static final Color share = _brand(IqOpacity.shareScrim);

  /// The first-run tip.
  static final Color tip = _brand(IqOpacity.tipScrim);

  static Color _brand(double opacity) =>
      IqColors.brand.withValues(alpha: opacity);
}

/// A page deeper into a flow (spec 3.1, 3.2): it slides 24 in from the
/// right as it fades in, 300 ms, while the page beneath slides 24 left and
/// fades; back plays it in reverse over 240, and iOS swipes it back from
/// the left edge. Reduced motion: a 150 ms crossfade, nothing slides.
Page<T> pushPage<T>(GoRouterState state, Widget child) =>
    _IqPage<T>(state, child, _Move.of(state.extra, _Move.push));

/// A page from another flow (spec 3.5): it fades in over the page it
/// replaces, which stays still, 300 ms, or 400 from the splash.
Page<T> handoffPage<T>(GoRouterState state, Widget child) =>
    _IqPage<T>(state, child, _Move.of(state.extra, _Move.handoff));

/// A lens over the same chrome (spec 3.7): the page fades in place over
/// 200 ms while the page beneath stays still; a cut under reduced motion.
Page<T> lensPage<T>(GoRouterState state, Widget child) =>
    _IqPage<T>(state, child, _Move.lens);

/// A route over the same chrome with no transition at all (spec 3.7, the
/// Saved lens): the chrome reads as still and the page fades its own
/// content in.
Page<T> stillPage<T>(GoRouterState state, Widget child) => NoTransitionPage<T>(
  key: state.pageKey,
  name: state.name ?? state.path,
  arguments: _arguments(state),
  restorationId: state.pageKey.value,
  child: PulseScope(child: child),
);

/// A sheet hosted as a route page (spec 3.3), on [scrim]. With [expand], a
/// drag up past the open sheet lifts it to the top of the screen, and let
/// go past half way (or flung) the sheet blanks to paper and [expand] opens
/// its page, which it should push with [Arrival.sheet] as `extra`.
Page<T> sheetPage<T>(
  GoRouterState state,
  Widget child, {
  required Color scrim,
  ValueChanged<BuildContext>? expand,
}) => _IqSheetPage<T>(state, child, scrim, expand);

/// Opens [builder] as a sheet on [scrim] (spec 3.3) and completes with what
/// it pops.
Future<T?> showIqSheet<T>(
  BuildContext context,
  WidgetBuilder builder, {
  required Color scrim,
}) {
  return Navigator.of(context).push<T>(
    IqSheetRoute<T>(
      builder: builder,
      scrim: scrim,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    ),
  );
}

/// Runs [action] once the route around [context] has finished arriving, so
/// a sheet's search field takes the keyboard after the rise (spec 3.3); at
/// once under reduced motion.
///
/// The hero controller holds a pushed page route offstage for its first
/// frame, and the route's animation reads as complete while it is, so the
/// wait only starts once the route is back onstage.
void whenArrived(BuildContext context, VoidCallback action) {
  final route = ModalRoute.of(context);
  if (route == null || MediaQuery.disableAnimationsOf(context)) {
    action();
    return;
  }
  void wait() {
    if (!context.mounted) return;
    if (route.offstage) {
      WidgetsBinding.instance.addPostFrameCallback((_) => wait());
      return;
    }
    final animation = route.animation!;
    if (animation.isCompleted) {
      action();
      return;
    }
    late final AnimationStatusListener listener;
    listener = (status) {
      if (status.isAnimating) return;
      animation.removeStatusListener(listener);
      if (status.isCompleted) action();
    };
    animation.addStatusListener(listener);
  }

  wait();
}

/// Runs [action] once no page stands over the one around [context]: at once
/// when none does, else as soon as the last page above has gone, so a
/// change that lands while a page is still on its way out over this one
/// (or arrives at the start of a pop, as a paused provider's does) plays
/// where it is seen (spec 5.28, 7.5). Never runs once [context] is gone.
void whenUncovered(BuildContext context, VoidCallback action) {
  final above = _pageAbove(context);
  if (above == null) {
    action();
    return;
  }
  late final AnimationStatusListener listener;
  listener = (status) {
    if (!status.isDismissed) return;
    above.removeStatusListener(listener);
    if (context.mounted) whenUncovered(context, action);
  };
  above.addStatusListener(listener);
}

/// The move of the nearest page standing over the one around [context], or
/// still coming or going over it, through every navigator it sits in.
Animation<double>? _pageAbove(BuildContext context) {
  for (
    var page = context.getInheritedWidgetOfExactType<_PageScope>();
    page != null;
    page = page.route.navigator?.context
        .getInheritedWidgetOfExactType<_PageScope>()
  ) {
    final above = page.route.secondaryAnimation;
    if (above != null && !above.isDismissed) return above;
  }
  return null;
}

/// Lets what a page holds find its route without depending on its state.
class _PageScope extends InheritedWidget {
  const _PageScope({required this.route, required super.child});

  final ModalRoute<dynamic> route;

  @override
  bool updateShouldNotify(_PageScope old) => route != old.route;
}

enum _Move {
  push(IqDurations.screen, IqDurations.screenBack),
  back(IqDurations.screenBack, IqDurations.screenBack),
  handoff(IqDurations.screen, IqDurations.screenBack),
  splash(IqDurations.handoff, IqDurations.screenBack),
  expand(IqDurations.swap, IqDurations.screenBack),
  lens(IqDurations.swap, IqDurations.swap),
  cut(Duration.zero, IqDurations.screenBack);

  const _Move(this.enter, this.exit);

  final Duration enter;
  final Duration exit;

  bool get slides => slidesIn || this == expand;

  bool get slidesIn => this == push || this == back;

  Duration get reduced =>
      this == lens || this == cut ? Duration.zero : IqDurations.crossfade;

  static _Move of(Object? extra, _Move fallback) => switch (extra) {
    NavDirection.back => back,
    Arrival.splash => splash,
    Arrival.lockup => cut,
    Arrival.sheet => expand,
    _ => fallback,
  };
}

Map<String, String> _arguments(GoRouterState state) => {
  ...state.pathParameters,
  ...state.uri.queryParameters,
};

class _IqPage<T> extends Page<T> {
  _IqPage(GoRouterState state, this.child, this.move)
    : super(
        key: state.pageKey,
        name: state.name ?? state.path,
        arguments: _arguments(state),
        restorationId: state.pageKey.value,
      );

  final Widget child;
  final _Move move;

  @override
  Route<T> createRoute(BuildContext context) => _IqPageRoute<T>(this);
}

/// Reads reduced motion when a transition starts, so each one is either
/// full or reduced from its first frame to its last. The controller keeps
/// its duration under the platform's reduced motion setting, which would
/// otherwise cut the 150 ms crossfades to a frame.
mixin _ReducedMotion<T> on TransitionRoute<T> {
  bool reduced = false;

  @override
  AnimationController createAnimationController() => AnimationController(
    duration: transitionDuration,
    reverseDuration: reverseTransitionDuration,
    debugLabel: debugLabel,
    vsync: navigator!,
    animationBehavior: AnimationBehavior.preserve,
  );

  void _read() {
    final media = navigator?.context
        .getInheritedWidgetOfExactType<MediaQuery>();
    reduced = media?.data.disableAnimations ?? false;
  }

  void _sync() {
    _read();
    controller!
      ..duration = transitionDuration
      ..reverseDuration = reverseTransitionDuration;
  }

  @override
  void install() {
    _read();
    super.install();
  }

  @override
  TickerFuture didPush() {
    _sync();
    return super.didPush();
  }

  @override
  bool didPop(T? result) {
    _sync();
    return super.didPop(result);
  }
}

class _IqPageRoute<T> extends PageRoute<T> with _ReducedMotion<T> {
  _IqPageRoute(_IqPage<T> page) : _move = page.move, super(settings: page);

  final _Move _move;
  _IqPageRoute<dynamic>? _cover;
  Route<dynamic>? _next;

  late final Animation<double> _fadeIn = animation!.drive(
    CurveTween(
      curve: _move.slidesIn
          ? const Interval(0, 0.6, curve: IqCurves.easeOut)
          : IqCurves.easeOut,
    ),
  );
  late final Animation<double> _crossfadeIn = animation!.drive(
    CurveTween(curve: IqCurves.easeOut),
  );
  late final Animation<double> _fadeOut = secondaryAnimation!.drive(
    Tween<double>(
      begin: 1,
      end: 0,
    ).chain(CurveTween(curve: const Interval(0, 0.5, curve: IqCurves.easeIn))),
  );

  AnimationController get _swipe => controller!;

  @override
  bool get opaque => true;

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => reduced ? _move.reduced : _move.enter;

  @override
  Duration get reverseTransitionDuration =>
      reduced ? _move.reduced : _move.exit;

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) =>
      nextRoute is _IqPageRoute;

  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) =>
      _move.slides;

  @override
  void didChangeNext(Route<dynamic>? nextRoute) {
    _next = nextRoute;
    if (nextRoute is _IqPageRoute) _cover = nextRoute;
    super.didChangeNext(nextRoute);
  }

  /// Popped, replaced, or covered by another page; a sheet over it leaves
  /// it on screen.
  bool get _leaving {
    if (!isActive) return true;
    final next = _next;
    return !isCurrent && next is TransitionRoute && next.opaque;
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: _heroes(
        context,
        PulseScope(
          child: _HeldInsets(
            route: this,
            child: _PageScope(
              route: this,
              child: (settings as _IqPage<T>).child,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final swiping = navigator!.userGestureInProgress;
    final width = MediaQuery.sizeOf(context).width;

    var inX = 0.0;
    Animation<double> inFade = reduced ? _crossfadeIn : _fadeIn;
    var outX = 0.0;
    Animation<double> outFade = kAlwaysCompleteAnimation;
    if (swiping) {
      inX = width * (1 - animation.value);
      inFade = kAlwaysCompleteAnimation;
      outX = -IqTravel.screen * secondaryAnimation.value;
    } else if (!reduced) {
      if (_move.slidesIn ||
          (_move.slides && animation.status == AnimationStatus.reverse)) {
        final from = _move == _Move.back ? -IqTravel.screen : IqTravel.screen;
        inX = from * (1 - IqCurves.easeOut.transform(animation.value));
      }
      final to = _cover?._move == _Move.back
          ? IqTravel.screen
          : -IqTravel.screen;
      outX = to * IqCurves.easeIn.transform(secondaryAnimation.value);
      outFade = _fadeOut;
    }

    Widget page = child;
    if (_move.slides && Theme.of(context).platform == TargetPlatform.iOS) {
      page = _BackSwipe(route: this, child: page);
    }
    return Transform.translate(
      offset: Offset(outX, 0),
      child: FadeTransition(
        opacity: outFade,
        child: Transform.translate(
          offset: Offset(inX, 0),
          child: FadeTransition(opacity: inFade, child: page),
        ),
      ),
    );
  }
}

/// The hero controller looks for heroes from inside each page, below the
/// route's transitions, so heroes are switched off for reduced motion here.
Widget _heroes(BuildContext context, Widget page) =>
    HeroMode(enabled: !MediaQuery.disableAnimationsOf(context), child: page);

/// A page on its way out keeps the insets it last had while it was the
/// current page, so it holds still while a keyboard comes or goes over it
/// (spec 4.5): one closing as the next page arrives, or the next page's own
/// rising as this one leaves.
class _HeldInsets extends StatefulWidget {
  const _HeldInsets({required this.route, required this.child});

  final _IqPageRoute<dynamic> route;
  final Widget child;

  @override
  State<_HeldInsets> createState() => _HeldInsetsState();
}

class _HeldInsetsState extends State<_HeldInsets> {
  MediaQueryData? _held;

  @override
  Widget build(BuildContext context) {
    // Only to rebuild when the page stops or starts being the current one.
    ModalRoute.isCurrentOf(context);
    final media = MediaQuery.of(context);
    final held = _held;
    if (!widget.route._leaving || held == null) {
      _held = media;
      return MediaQuery(data: media, child: widget.child);
    }
    return MediaQuery(
      data: media.copyWith(
        padding: held.padding,
        viewPadding: held.viewPadding,
        viewInsets: held.viewInsets,
      ),
      child: widget.child,
    );
  }
}

/// The iOS back swipe from the left edge (spec 3.2): the page follows the
/// finger, then pops when dragged past half the width or flung right at a
/// width a second, or settles back, carrying on at the finger's speed (see
/// [_settle]). Under reduced motion it still follows the finger and ends
/// with a cut.
class _BackSwipe extends StatefulWidget {
  const _BackSwipe({required this.route, required this.child});

  final _IqPageRoute<dynamic> route;
  final Widget child;

  @override
  State<_BackSwipe> createState() => _BackSwipeState();
}

class _BackSwipeState extends State<_BackSwipe> {
  static const double _edge = 20;

  late final HorizontalDragGestureRecognizer _drag =
      HorizontalDragGestureRecognizer(debugOwner: this)
        ..onStart = _start
        ..onUpdate = _update
        ..onEnd = _end
        ..onCancel = _cancel;
  NavigatorState? _navigator;
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
  }

  void _down(PointerDownEvent event) {
    if (widget.route.popGestureEnabled) _drag.addPointer(event);
  }

  void _start(DragStartDetails details) {
    _navigator = widget.route.navigator!..didStartUserGesture();
  }

  void _update(DragUpdateDetails details) {
    if (_navigator == null) return;
    widget.route._swipe.value -= details.primaryDelta! / context.size!.width;
  }

  void _end(DragEndDetails details) =>
      _finish(details.velocity.pixelsPerSecond.dx / context.size!.width);

  void _cancel() => _finish(0);

  /// [velocity] in widths a second, rightwards.
  void _finish(double velocity) {
    final navigator = _navigator;
    if (navigator == null) return;
    _navigator = null;
    final route = widget.route;
    final controller = route._swipe;
    final bool pop;
    if (!route.isCurrent) {
      pop = !route.isActive;
    } else if (velocity.abs() >= 1) {
      pop = velocity > 0;
    } else {
      pop = controller.value < 0.5;
    }
    if (pop && route.isCurrent) navigator.pop();
    _settle(
      controller,
      pop ? 0 : 1,
      IqDurations.screenBack,
      _reduced,
      speed: pop ? velocity : -velocity,
    );
    _whenSettled(controller, navigator.didStopUserGesture);
  }

  @override
  void dispose() {
    _drag.dispose();
    final navigator = _navigator;
    if (navigator != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigator.mounted) navigator.didStopUserGesture();
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: math.max(_edge, MediaQuery.paddingOf(context).left),
          child: Listener(
            onPointerDown: _down,
            behavior: HitTestBehavior.translucent,
          ),
        ),
      ],
    );
  }
}

/// Sends a route's [controller] to [target] when the finger lets go, ease-out
/// from the [speed] it let go at (controller units a second, towards
/// [target]), so the move carries on at the finger's pace rather than
/// speeding up. A finger slower than a whole move a second settles at that
/// pace; the settle never takes less than the remaining share of [full]
/// (spec 3.2, 3.3) nor more than twice [full]. At once under reduced motion.
void _settle(
  AnimationController controller,
  double target,
  Duration full,
  bool reduced, {
  required double speed,
}) {
  final left = (controller.value - target).abs();
  if (reduced || left == 0) {
    controller.value = target;
    return;
  }
  final carry =
      left * _easeOutLead / math.max(speed, 1) * Duration.microsecondsPerSecond;
  final length = Duration(
    microseconds: carry
        .clamp(left * full.inMicroseconds, 2.0 * full.inMicroseconds)
        .round(),
  );
  if (target == 0) {
    controller.animateBack(0, duration: length, curve: IqCurves.easeOut);
  } else {
    controller.animateTo(1, duration: length, curve: IqCurves.easeOut);
  }
}

/// How many times its average speed [IqCurves.easeOut] sets off at: its
/// first control point sits on the origin, so the second one sets the slope
/// it leaves at.
final double _easeOutLead = () {
  final ease = IqCurves.easeOut as Cubic;
  return ease.d / ease.c;
}();

void _whenSettled(AnimationController controller, VoidCallback done) {
  if (!controller.isAnimating) {
    done();
    return;
  }
  late final AnimationStatusListener listener;
  listener = (status) {
    if (status.isAnimating) return;
    controller.removeStatusListener(listener);
    done();
  };
  controller.addStatusListener(listener);
}

class _IqSheetPage<T> extends Page<T> {
  _IqSheetPage(GoRouterState state, this.child, this.scrim, this.expand)
    : super(
        key: state.pageKey,
        name: state.name ?? state.path,
        arguments: _arguments(state),
        restorationId: state.pageKey.value,
      );

  final Widget child;
  final Color scrim;
  final ValueChanged<BuildContext>? expand;

  @override
  Route<T> createRoute(BuildContext context) => IqSheetRoute<T>(
    settings: this,
    scrim: scrim,
    expand: expand,
    barrierLabel: Localizations.of<MaterialLocalizations>(
      context,
      MaterialLocalizations,
    )?.modalBarrierDismissLabel,
  );
}

/// The one sheet route (spec 3.3): the sheet rises from the bottom edge in
/// 300 ms as its scrim fades in, drops in 200 ms when it closes, and follows a drag
/// down (past half its height or a 700 px/s fling closes it). It fades in
/// place under reduced motion. The page beneath stays put. With [expand] it
/// also follows a drag up to the top of the screen and hands over to its
/// page there (see [sheetPage]).
///
/// The rise moves the route's page from outside it, as a page route's
/// slide does, so a hero flying into the sheet heads straight for where it
/// comes to rest (spec 4.4).
class IqSheetRoute<T> extends PageRoute<T> with _ReducedMotion<T> {
  IqSheetRoute({
    this.builder,
    required this.scrim,
    this.barrierLabel,
    this.expand,
    super.settings,
  });

  /// Opens the page the sheet was dragged up into.
  final ValueChanged<BuildContext>? expand;

  /// How far the sheet is lifted towards the top of the screen (0 to 1).
  late final AnimationController _lift = AnimationController(
    vsync: navigator!,
    duration: IqDurations.swap,
  );

  /// How far the lifted sheet has blanked to paper for its page.
  late final AnimationController _blank = AnimationController(
    vsync: navigator!,
    duration: IqDurations.crossfade,
  );

  bool _expanding = false;

  /// How far the sheet around [context] is lifted towards the top of the
  /// screen, for a sheet that squares its corners as it goes.
  static Animation<double> liftOf(BuildContext context) {
    final route = context.getInheritedWidgetOfExactType<_PageScope>()?.route;
    return route is IqSheetRoute ? route._lift : kAlwaysDismissedAnimation;
  }

  void _expand(BuildContext context) {
    if (_expanding) return;
    _expanding = true;
    controller!.reverseDuration = reverseTransitionDuration;
    _blank.forward().whenCompleteOrCancel(() {
      if (isActive && context.mounted) expand!(context);
    });
  }

  @override
  void dispose() {
    _lift.dispose();
    _blank.dispose();
    super.dispose();
  }

  /// Builds the sheet; null when a [sheetPage] hosts it.
  final WidgetBuilder? builder;

  /// The scrim at full strength.
  final Color scrim;

  @override
  final String? barrierLabel;

  bool _locked = false;
  bool _dragging = false;
  final _box = GlobalKey();

  AnimationController get _sheet => controller!;

  /// Holds the sheet against scrim taps and drags until it pops itself.
  void lock() {
    if (_locked) return;
    _locked = true;
    changedInternalState();
  }

  @override
  bool get opaque => false;

  @override
  bool get maintainState => true;

  @override
  Color get barrierColor => scrim;

  @override
  bool get barrierDismissible => !_locked;

  @override
  Curve get barrierCurve => IqCurves.easeOut;

  @override
  Duration get transitionDuration =>
      reduced ? IqDurations.crossfade : IqDurations.sheetRise;

  /// Expanded, the blank sheet stays up under its page until the page is
  /// in.
  @override
  Duration get reverseTransitionDuration => _expanding
      ? IqDurations.screen
      : reduced
      ? IqDurations.crossfade
      : IqDurations.sheetDrop;

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) => false;

  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) => false;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final page = settings;
    final sheet = page is _IqSheetPage ? page.child : builder!(context);
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: _heroes(
        context,
        PulseScope(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: _SheetDrag(
              key: _box,
              route: this,
              child: _PageScope(route: this, child: sheet),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final t = animation.value;
    final fading =
        MediaQuery.disableAnimationsOf(context) && !_dragging && !_expanding;
    final up = _dragging || _expanding ? 1.0 : IqCurves.easeOut.transform(t);
    final drop = _dragging ? 1 - t : 1 - up;
    if (expand == null) {
      return _SheetLift(
        sheet: _box,
        drop: fading ? 0 : drop,
        child: Opacity(
          opacity: fading ? IqCurves.easeOut.transform(t) : 1,
          child: child,
        ),
      );
    }
    return AnimatedBuilder(
      animation: Listenable.merge([_lift, _blank]),
      child: child,
      builder: (context, child) => _SheetLift(
        sheet: _box,
        drop: fading ? 0 : drop,
        lift: _lift.value,
        top: MediaQuery.paddingOf(context).top,
        blank: _blank.value > 0,
        child: Opacity(
          opacity:
              (fading ? IqCurves.easeOut.transform(t) : 1) * (1 - _blank.value),
          child: child,
        ),
      ),
    );
  }
}

/// Lowers the sheet at the foot of [child], a page that fills the screen,
/// by [drop] times the height of the [sheet] box.
///
/// Lifted, it raises the sheet [lift] of the way to [top], the foot of the
/// status bar, filling the status bar with paper as it goes and the screen
/// under the sheet's foot with paper at once; [blank] lays
/// paper under the sheet, so a sheet fading out leaves paper behind.
class _SheetLift extends SingleChildRenderObjectWidget {
  const _SheetLift({
    required this.sheet,
    required this.drop,
    this.lift = 0,
    this.top = 0,
    this.blank = false,
    required super.child,
  });

  final GlobalKey sheet;
  final double drop;
  final double lift;
  final double top;
  final bool blank;

  @override
  _RenderSheetLift createRenderObject(BuildContext context) =>
      _RenderSheetLift(sheet, drop)
        .._lift = lift
        .._top = top
        .._blank = blank;

  @override
  void updateRenderObject(BuildContext context, _RenderSheetLift render) =>
      render
        ..drop = drop
        ..lifted(lift, top, blank);
}

class _RenderSheetLift extends RenderProxyBox {
  _RenderSheetLift(this._sheet, this._drop);

  final GlobalKey _sheet;
  double _drop;
  double _lift = 0;
  double _top = 0;
  bool _blank = false;

  void lifted(double lift, double top, bool blank) {
    if (lift == _lift && top == _top && blank == _blank) return;
    _lift = lift;
    _top = top;
    _blank = blank;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  /// The shift last painted, so taps and transforms between frames match
  /// what is on screen; the sheet's height is only safe to read at paint.
  Offset _shift = Offset.zero;

  set drop(double value) {
    if (value == _drop) return;
    _drop = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final sheet = _sheet.currentContext?.findRenderObject();
    final height = sheet is RenderBox && sheet.hasSize
        ? sheet.size.height
        : size.height;
    final reach = math.max(0.0, size.height - height - _top);
    _shift = Offset(0, _drop * height - _lift * reach);
    final paper = Paint()..color = IqColors.bg;
    if (_lift > 0) {
      context.canvas
        ..drawRect(
          offset & Size(size.width, _top),
          Paint()..color = IqColors.bg.withValues(alpha: _lift),
        )
        ..drawRect(
          offset + Offset(0, size.height + _shift.dy) &
              Size(size.width, -_shift.dy),
          paper,
        );
    }
    if (_blank) {
      context.canvas.drawRect(
        offset + _shift + Offset(0, size.height - height) &
            Size(size.width, height),
        paper,
      );
    }
    super.paint(context, offset + _shift);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      result.addWithPaintOffset(
        offset: _shift,
        position: position,
        hitTest: (result, position) =>
            super.hitTestChildren(result, position: position),
      );

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) =>
      transform.translateByDouble(_shift.dx, _shift.dy, 0, 1);
}

class _SheetDrag extends StatefulWidget {
  const _SheetDrag({super.key, required this.route, required this.child});

  final IqSheetRoute<dynamic> route;
  final Widget child;

  @override
  State<_SheetDrag> createState() => _SheetDragState();
}

class _SheetDragState extends State<_SheetDrag> {
  static const double _fling = 700;

  NavigatorState? _navigator;
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
  }

  void _start(DragStartDetails details) {
    final route = widget.route;
    if (route._locked || !route.isCurrent || !route.animation!.isCompleted) {
      return;
    }
    route._dragging = true;
    _navigator = route.navigator!..didStartUserGesture();
  }

  /// How far the sheet can lift: from its top to the foot of the status
  /// bar.
  double get _reach {
    final screen = MediaQuery.of(widget.route.navigator!.context);
    return math.max(
      1.0,
      screen.size.height - context.size!.height - screen.padding.top,
    );
  }

  void _update(DragUpdateDetails details) {
    if (_navigator == null) return;
    final route = widget.route;
    final sheet = route._sheet;
    final delta = details.primaryDelta!;
    final lift = route._lift;
    if (route.expand != null &&
        (lift.value > 0 || (delta < 0 && sheet.value >= 1))) {
      lift.value = (lift.value - delta / _reach).clamp(0.0, 1.0);
      return;
    }
    sheet.value = (sheet.value - delta / context.size!.height).clamp(0.0, 1.0);
  }

  void _end(DragEndDetails details) =>
      _finish(details.velocity.pixelsPerSecond.dy);

  void _cancel() => _finish(0);

  /// [velocity] in px a second, downwards.
  void _finish(double velocity) {
    final navigator = _navigator;
    if (navigator == null) return;
    _navigator = null;
    final route = widget.route;
    if (route._lift.value > 0) {
      _finishLift(navigator, velocity);
      return;
    }
    final sheet = route._sheet;
    final close = !route.isActive || velocity >= _fling || sheet.value < 0.5;
    if (close && route.isCurrent) navigator.pop();
    final down = velocity / context.size!.height;
    _settle(
      sheet,
      close ? 0 : 1,
      IqDurations.swap,
      _reduced,
      speed: close ? down : -down,
    );
    _whenSettled(sheet, () {
      route._dragging = false;
      navigator.didStopUserGesture();
    });
  }

  /// A drag up past the open sheet ends: past half way or flung up it lifts
  /// to the top and hands over to its page, otherwise it settles back.
  void _finishLift(NavigatorState navigator, double velocity) {
    final route = widget.route;
    final lift = route._lift;
    final expand =
        route.isCurrent && (velocity <= -_fling || lift.value >= 0.5);
    final up = -velocity / _reach;
    _settle(
      lift,
      expand ? 1 : 0,
      IqDurations.swap,
      _reduced,
      speed: expand ? up : -up,
    );
    _whenSettled(lift, () {
      route._dragging = false;
      navigator.didStopUserGesture();
      if (expand && mounted) route._expand(context);
    });
  }

  @override
  void dispose() {
    final navigator = _navigator;
    if (navigator != null) {
      widget.route._dragging = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigator.mounted) navigator.didStopUserGesture();
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragStart: _start,
      onVerticalDragUpdate: _update,
      onVerticalDragEnd: _end,
      onVerticalDragCancel: _cancel,
      child: widget.child,
    );
  }
}

/// The Dock's tab switch: a cut (designer answers, 5 Oct). Hidden branches
/// sit offstage with their tickers off, keeping their stacks and scroll.
class TabBranches extends StatelessWidget {
  const TabBranches({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  /// The navigatorContainerBuilder for a StatefulShellRoute.
  static Widget builder(
    BuildContext context,
    StatefulNavigationShell shell,
    List<Widget> children,
  ) => TabBranches(currentIndex: shell.currentIndex, children: children);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < children.length; i++)
          Offstage(
            offstage: i != currentIndex,
            child: TickerMode(enabled: i == currentIndex, child: children[i]),
          ),
      ],
    );
  }
}

/// How the page around [context] came in: [NavDirection.back] when a `go`
/// marked back brought it, so its entrance does not replay (spec 2.6).
NavDirection arrivalOf(BuildContext context) {
  final route = ModalRoute.of(context);
  return route is _IqPageRoute && route._move == _Move.back
      ? NavDirection.back
      : NavDirection.forward;
}

/// Holds [child] 40 ms behind its page while the page slides in, so a
/// step's control trails its title (spec 4.1); mirrored for a page coming
/// back from the left. Still at rest, during a back swipe and under
/// reduced motion.
class PushTrail extends StatelessWidget {
  const PushTrail({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route is! _IqPageRoute || !route._move.slides) return child;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final animation = route.animation!;
    final lag =
        IqDurations.stagger.inMicroseconds / route._move.enter.inMicroseconds;
    final from = route._move == _Move.back ? -IqTravel.screen : IqTravel.screen;
    // One tree shape throughout: a wrapper that came and went would rebuild
    // the control, and a field in it would drop the keyboard.
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        var dx = 0.0;
        if (!reduced &&
            animation.status == AnimationStatus.forward &&
            route.navigator?.userGestureInProgress != true) {
          final t = animation.value;
          final page = IqCurves.easeOut.transform(t);
          final own = IqCurves.easeOut.transform(
            ((t - lag) / (1 - lag)).clamp(0.0, 1.0),
          );
          dx = from * (page - own);
        }
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}

/// The chrome two pages share (spec 4.1, 4.3).
abstract final class ChromeTags {
  static const back = 'chrome.back';
  static const stepMark = 'chrome.stepmark';
  static const autosave = 'chrome.autosave';
  static const skip = 'chrome.skip';
  static const next = 'chrome.next';
}

/// Draws a [ChromeHero] in flight: [progress] runs 0 to 1 from the leaving
/// page's [from] look to the arriving page's [to], whichever way the pages
/// move.
typedef ChromeShuttle = Widget Function(
  BuildContext context,
  Animation<double> progress,
  Widget from,
  Widget to,
);

/// Chrome that two pages share holds still while the pages move (spec 4.1,
/// 4.3): a Hero whose two ends sit in the same place, drawn in flight by
/// [shuttle], or as the arriving page draws it. The pages' own copies stay
/// hit-testable under the flight, so a back tap halfway through a push
/// still lands. Under reduced motion it turns its hero off and the chrome
/// crossfades with its page.
///
/// A navigator takes one hero per tag from each page, so a page that holds
/// two of its states at once, one dissolving into the next, turns heroes
/// off in the state it is leaving ([Dissolve] does): the chrome of the
/// state that stays flies from the frame it is built.
class ChromeHero extends StatelessWidget {
  const ChromeHero({
    super.key,
    required this.tag,
    required this.child,
    this.shuttle,
  });

  final Object tag;
  final Widget child;
  final ChromeShuttle? shuttle;

  /// The two looks crossfade (ease-out over the move) with no dip where
  /// they agree: the look for which [richer] is true fades over the other,
  /// which stays whole beneath it; two equally rich looks hold still.
  static ChromeShuttle crossfade(bool Function(Widget look) richer) =>
      (context, progress, from, to) {
        final up = richer(to);
        if (up == richer(from)) return to;
        final eased = progress.drive(CurveTween(curve: IqCurves.easeOut));
        return Stack(
          clipBehavior: Clip.none,
          children: up
              ? [from, FadeTransition(opacity: eased, child: to)]
              : [
                  to,
                  FadeTransition(opacity: ReverseAnimation(eased), child: from),
                ],
        );
      };

  /// Whether chrome built at [context] may carry its own [ChromeHero]: it is
  /// not inside another Hero (heroes do not nest) nor drawn in a flight.
  static bool canCarry(BuildContext context) =>
      context.findAncestorWidgetOfExactType<Hero>() == null &&
      context.findAncestorWidgetOfExactType<_InFlight>() == null;

  @override
  Widget build(BuildContext context) {
    final shuttle = this.shuttle;
    return Hero(
      tag: tag,
      curve: IqCurves.linear,
      flightShuttleBuilder: (context, animation, direction, fromHero, toHero) {
        final from = (fromHero.widget as Hero).child;
        final to = (toHero.widget as Hero).child;
        final push = direction == HeroFlightDirection.push;
        // The flight is drawn in the navigator's overlay, outside every
        // page's Material, where text would take the framework's fallback
        // style (a yellow double underline).
        return _InFlight(
          child: Material(
            type: MaterialType.transparency,
            child: shuttle == null
                ? (push ? to : from)
                : shuttle(
                    context,
                    push ? animation : ReverseAnimation(animation),
                    from,
                    to,
                  ),
          ),
        );
      },
      placeholderBuilder: (context, size, child) =>
          Opacity(opacity: 0, child: child),
      child: child,
    );
  }
}

/// Marks chrome drawn in a [ChromeHero]'s flight.
class _InFlight extends StatelessWidget {
  const _InFlight({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// The lens switch (spec 3.7): [cross] lays what the [child] last drew
/// below a line (the lens chips' bottom edge) over whatever comes next and
/// fades it out over 200 ms, so the new content reads as fading in,
/// ease-out, while the chrome above the line holds still. A card on both
/// lenses draws the same under and over, so it stays steady, and nothing
/// blanks between the two. A cut under reduced motion.
class LensCrossfade extends StatefulWidget {
  const LensCrossfade({super.key, required this.child});

  final Widget child;

  /// Crosses what the nearest [LensCrossfade] around [context] shows below
  /// the bottom edge of [line] into what it shows next.
  static void cross(BuildContext context, {required BuildContext line}) =>
      context.findAncestorStateOfType<_LensCrossfadeState>()?._cross(line);

  @override
  State<LensCrossfade> createState() => _LensCrossfadeState();
}

class _LensCrossfadeState extends State<LensCrossfade>
    with SingleTickerProviderStateMixin {
  final _content = GlobalKey();
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: IqDurations.swap,
  )..addStatusListener(_onFade);
  late final Animation<double> _was = ReverseAnimation(
    _fade.drive(CurveTween(curve: IqCurves.easeOut)),
  );
  ui.Image? _image;
  double _line = 0;

  void _onFade(AnimationStatus status) {
    if (status.isCompleted && mounted) setState(_drop);
  }

  void _drop() {
    _image?.dispose();
    _image = null;
  }

  void _cross(BuildContext line) {
    if (MediaQuery.disableAnimationsOf(context)) return;
    // A pick and the filter change it makes both ask in one frame, and the
    // last frame drawn is the same for both.
    if (_fade.isAnimating && _fade.value == 0) return;
    final content = _content.currentContext?.findRenderObject();
    final edge = line.findRenderObject();
    if (content is! _RenderLastFrame ||
        edge is! RenderBox ||
        !edge.attached ||
        !edge.hasSize) {
      return;
    }
    final image = content.take(MediaQuery.devicePixelRatioOf(context));
    if (image == null) return;
    setState(() {
      _drop();
      _image = image;
      _line = edge
          .localToGlobal(edge.size.bottomLeft(Offset.zero), ancestor: content)
          .dy;
    });
    _fade.forward(from: 0);
  }

  @override
  void dispose() {
    _fade.dispose();
    _drop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    // The last frame holds a crossing still under way, so a second pick
    // starts from what is on screen.
    return _LastFrame(
      key: _content,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (image != null)
            IgnorePointer(
              child: ClipRect(
                clipper: _Below(_line),
                child: FadeTransition(
                  opacity: _was,
                  child: RawImage(image: image, fit: BoxFit.fill),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A repaint boundary that can hand over the last frame it drew.
class _LastFrame extends SingleChildRenderObjectWidget {
  const _LastFrame({super.key, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderLastFrame();
}

class _RenderLastFrame extends RenderProxyBox {
  @override
  bool get isRepaintBoundary => true;

  /// The last frame drawn here, [ratio] pixels to the point.
  ui.Image? take(double ratio) {
    final layer = this.layer;
    if (layer is! OffsetLayer || !attached || !hasSize) return null;
    return layer.toImageSync(Offset.zero & size, pixelRatio: ratio);
  }
}

class _Below extends CustomClipper<Rect> {
  const _Below(this.top);

  final double top;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(0, top, size.width, size.height);

  @override
  bool shouldReclip(_Below old) => old.top != top;
}

/// Same screen, new state (spec 3.4): [child], told apart by its key,
/// crosses over the old one, 300 ms ease-out both ways (the exit reads
/// ease-in); a 150 ms crossfade under reduced motion. The old state offers
/// no heroes on its way out ([ChromeHero]).
class Dissolve extends StatelessWidget {
  const Dissolve({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: motion(context, IqDurations.screen, fade: true),
      switchInCurve: IqCurves.easeOut,
      switchOutCurve: IqCurves.easeOut,
      // Each switch carries the key of the state it wraps, so a state that
      // turns from coming to leaving keeps its widgets and their state.
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [
          for (final leaving in previous)
            HeroMode(key: leaving.key, enabled: false, child: leaving),
          if (current != null) HeroMode(key: current.key, child: current),
        ],
      ),
      child: child,
    );
  }
}

/// The first-run overlay (spec 3.8): after [delay] the [scrim] fades in over
/// 240 ms and [card] arrives 60 later, fading in as it rises 16 and grows
/// from .96 over 280. When [shown] turns off the card drops 8 and fades in
/// 160 as the scrim goes in 200, and the screen beneath takes taps at once.
/// Reduced motion fades both in and out in 150. [top] places the card.
/// [statusBar] styles the status bar while the scrim is at least half in.
class IqOverlay extends StatefulWidget {
  const IqOverlay({
    super.key,
    required this.shown,
    required this.scrim,
    required this.card,
    required this.top,
    this.delay = Duration.zero,
    this.statusBar,
  });

  final bool shown;
  final Color scrim;
  final Widget card;
  final double Function(BoxConstraints constraints) top;
  final Duration delay;
  final SystemUiOverlayStyle? statusBar;

  @override
  State<IqOverlay> createState() => _IqOverlayState();
}

class _IqOverlayState extends State<IqOverlay> with TickerProviderStateMixin {
  static const _cardLag = Duration(milliseconds: 60);
  static const _cardIn = Duration(milliseconds: 280);
  static const _cardOut = Duration(milliseconds: 160);

  late final AnimationController _in = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
  );
  late final AnimationController _out = AnimationController(
    vsync: this,
    value: widget.shown ? 0 : 1,
    animationBehavior: AnimationBehavior.preserve,
  )..addStatusListener(_onOut);
  Animation<double> _scrimIn = kAlwaysCompleteAnimation;
  Animation<double> _cardInAt = kAlwaysCompleteAnimation;
  Animation<double> _scrimGone = kAlwaysDismissedAnimation;
  Animation<double> _cardGone = kAlwaysDismissedAnimation;
  bool _reduced = false;
  bool _started = false;

  void _onOut(AnimationStatus status) {
    if (status.isCompleted && mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_started) return;
    _started = true;
    if (widget.shown) _playIn();
  }

  @override
  void didUpdateWidget(IqOverlay old) {
    super.didUpdateWidget(old);
    if (old.shown == widget.shown) return;
    if (widget.shown) {
      _out.value = 0;
      _playIn();
    } else {
      _playOut();
    }
  }

  Animation<double> _span(
    AnimationController clock,
    Duration from,
    Duration length,
    Curve curve,
  ) {
    final total = clock.duration!.inMicroseconds;
    return clock.drive(
      CurveTween(
        curve: Interval(
          from.inMicroseconds / total,
          (from + length).inMicroseconds / total,
          curve: curve,
        ),
      ),
    );
  }

  void _playIn() {
    if (_reduced) {
      _in.duration = IqDurations.crossfade;
      _scrimIn = _cardInAt = _in.drive(CurveTween(curve: IqCurves.easeOut));
    } else {
      _in.duration = widget.delay + _cardLag + _cardIn;
      _scrimIn = _span(_in, widget.delay, IqDurations.mark, IqCurves.easeOut);
      _cardInAt = _span(
        _in,
        widget.delay + _cardLag,
        _cardIn,
        IqCurves.easeOut,
      );
    }
    _in.forward(from: 0);
  }

  void _playOut() {
    _out.duration = _reduced ? IqDurations.crossfade : IqDurations.swap;
    final curve = CurveTween(curve: IqCurves.easeIn);
    _scrimGone = _out.drive(curve);
    _cardGone = _reduced
        ? _scrimGone
        : _span(_out, Duration.zero, _cardOut, IqCurves.easeIn);
    _out.forward(from: 0);
  }

  @override
  void dispose() {
    _in.dispose();
    _out.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.shown && _out.isCompleted) return const SizedBox.shrink();
    final both = Listenable.merge([_in, _out]);
    final scrim = _Product(_scrimIn, ReverseAnimation(_scrimGone));
    return IgnorePointer(
      ignoring: !widget.shown,
      child: Material(
        type: MaterialType.transparency,
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              Positioned.fill(
                child: _ScrimStatusBar(
                  style: widget.statusBar,
                  opacity: scrim,
                  child: FadeTransition(
                    opacity: scrim,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {},
                      child: ColoredBox(color: widget.scrim),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: widget.top(constraints),
                left: 0,
                right: 0,
                child: Center(
                  child: FadeTransition(
                    opacity: _Product(_cardInAt, ReverseAnimation(_cardGone)),
                    child: AnimatedBuilder(
                      animation: both,
                      child: widget.card,
                      builder: (context, child) {
                        if (_reduced) return child!;
                        final come = _cardInAt.value;
                        return Transform.translate(
                          offset: Offset(
                            0,
                            IqTravel.riseHero * (1 - come) +
                                IqTravel.rise * _cardGone.value,
                          ),
                          child: Transform.scale(
                            scale: IqScale.soft + (1 - IqScale.soft) * come,
                            child: child,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Puts [style] on the status bar while the scrim is at least half in.
class _ScrimStatusBar extends AnimatedWidget {
  const _ScrimStatusBar({
    required this.style,
    required Animation<double> opacity,
    required this.child,
  }) : super(listenable: opacity);

  final SystemUiOverlayStyle? style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final style = this.style;
    final up = (listenable as Animation<double>).value >= 0.5;
    if (style == null || !up) return child;
    return AnnotatedRegion<SystemUiOverlayStyle>(value: style, child: child);
  }
}

class _Product extends CompoundAnimation<double> {
  _Product(Animation<double> first, Animation<double> next)
    : super(first: first, next: next);

  @override
  double get value => first.value * next.value;
}
