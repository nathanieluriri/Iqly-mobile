import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/theme.dart';
import 'motion.dart';

/// Which way a page move reads (spec 4.1): pass [NavDirection.back] as the
/// `extra` of a `go` that steps back, and the page mirrors the push.
enum NavDirection { forward, back }

/// Where a hand-off starts (spec 3.5): pass [Arrival.splash] as `extra` for
/// the Figma 400 ms dissolve, [Arrival.lockup] when the splash has already
/// moved its wordmark onto the landing logo (spec 3.9), so the page takes
/// over with no transition.
enum Arrival { splash, lockup }

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

/// A sheet hosted as a route page (spec 3.3), on [scrim].
Page<T> sheetPage<T>(
  GoRouterState state,
  Widget child, {
  required Color scrim,
}) => _IqSheetPage<T>(state, child, scrim);

/// Opens [builder] as a sheet on [scrim] (spec 3.3) and completes with what
/// it pops. [rise] is 300 ms, the ConfirmSheet's 280.
Future<T?> showIqSheet<T>(
  BuildContext context,
  WidgetBuilder builder, {
  required Color scrim,
  Duration rise = IqDurations.screen,
}) {
  return Navigator.of(context).push<T>(
    IqSheetRoute<T>(
      builder: builder,
      scrim: scrim,
      rise: rise,
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

enum _Move {
  push(IqDurations.screen, IqDurations.screenBack),
  back(IqDurations.screenBack, IqDurations.screenBack),
  handoff(IqDurations.screen, IqDurations.screenBack),
  splash(IqDurations.handoff, IqDurations.screenBack),
  lens(IqDurations.swap, IqDurations.swap),
  cut(Duration.zero, IqDurations.screenBack);

  const _Move(this.enter, this.exit);

  final Duration enter;
  final Duration exit;

  bool get slides => this == push || this == back;

  Duration get reduced =>
      this == lens || this == cut ? Duration.zero : IqDurations.crossfade;

  static _Move of(Object? extra, _Move fallback) => switch (extra) {
    NavDirection.back => back,
    Arrival.splash => splash,
    Arrival.lockup => cut,
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

  late final Animation<double> _fadeIn = animation!.drive(
    CurveTween(
      curve: _move.slides
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
    if (nextRoute is _IqPageRoute) _cover = nextRoute;
    super.didChangeNext(nextRoute);
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
      child: PulseScope(child: (settings as _IqPage<T>).child),
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
      if (_move.slides) {
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
    return HeroMode(
      enabled: !reduced,
      child: Transform.translate(
        offset: Offset(outX, 0),
        child: FadeTransition(
          opacity: outFade,
          child: Transform.translate(
            offset: Offset(inX, 0),
            child: FadeTransition(opacity: inFade, child: page),
          ),
        ),
      ),
    );
  }
}

/// The iOS back swipe from the left edge (spec 3.2): the page follows the
/// finger, then pops when dragged past half the width or flung right at a
/// width a second, or settles back, over what is left of 240 ms. Under
/// reduced motion it still follows the finger and ends with a cut.
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
    _settle(controller, pop ? 0 : 1, IqDurations.screenBack, _reduced);
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

/// Sends a route's [controller] to [target] after a gesture: over the
/// remaining share of [full] ease-out, or at once under reduced motion.
void _settle(
  AnimationController controller,
  double target,
  Duration full,
  bool reduced,
) {
  final left = (controller.value - target).abs();
  if (reduced || left == 0) {
    controller.value = target;
  } else if (target == 0) {
    controller.animateBack(0, duration: full * left, curve: IqCurves.easeOut);
  } else {
    controller.animateTo(1, duration: full * left, curve: IqCurves.easeOut);
  }
}

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
  _IqSheetPage(GoRouterState state, this.child, this.scrim)
    : super(
        key: state.pageKey,
        name: state.name ?? state.path,
        arguments: _arguments(state),
        restorationId: state.pageKey.value,
      );

  final Widget child;
  final Color scrim;

  @override
  Route<T> createRoute(BuildContext context) => IqSheetRoute<T>(
    settings: this,
    scrim: scrim,
    barrierLabel: Localizations.of<MaterialLocalizations>(
      context,
      MaterialLocalizations,
    )?.modalBarrierDismissLabel,
  );
}

/// The one sheet route (spec 3.3): the sheet rises from the bottom edge as
/// its scrim fades in, drops in 200 ms when it closes, and follows a drag
/// down (past half its height or a 700 px/s fling closes it). It fades in
/// place under reduced motion. The page beneath stays put.
class IqSheetRoute<T> extends PageRoute<T> with _ReducedMotion<T> {
  IqSheetRoute({
    this.builder,
    required this.scrim,
    this.rise = IqDurations.screen,
    this.barrierLabel,
    super.settings,
  });

  /// Builds the sheet; null when a [sheetPage] hosts it.
  final WidgetBuilder? builder;

  /// The scrim at full strength.
  final Color scrim;

  /// How long the sheet takes to rise.
  final Duration rise;

  @override
  final String? barrierLabel;

  bool _locked = false;
  bool _dragging = false;

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
  Duration get transitionDuration => reduced ? IqDurations.crossfade : rise;

  @override
  Duration get reverseTransitionDuration =>
      reduced ? IqDurations.crossfade : IqDurations.swap;

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
      child: PulseScope(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: _SheetMotion(
            route: this,
            child: _SheetDrag(route: this, child: sheet),
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
  ) => child;
}

class _SheetMotion extends AnimatedWidget {
  _SheetMotion({required this.route, required this.child})
    : super(listenable: route.animation!);

  final IqSheetRoute<dynamic> route;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = route.animation!.value;
    final dragging = route._dragging;
    final fading = MediaQuery.disableAnimationsOf(context) && !dragging;
    final up = dragging ? t : IqCurves.easeOut.transform(t);
    return FractionalTranslation(
      translation: Offset(0, fading ? 0 : 1 - up),
      child: Opacity(
        opacity: fading ? IqCurves.easeOut.transform(t) : 1,
        child: child,
      ),
    );
  }
}

class _SheetDrag extends StatefulWidget {
  const _SheetDrag({required this.route, required this.child});

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

  void _update(DragUpdateDetails details) {
    if (_navigator == null) return;
    final sheet = widget.route._sheet;
    sheet.value = (sheet.value - details.primaryDelta! / context.size!.height)
        .clamp(0.0, 1.0);
  }

  void _end(DragEndDetails details) =>
      _finish(details.velocity.pixelsPerSecond.dy);

  void _cancel() => _finish(0);

  void _finish(double velocity) {
    final navigator = _navigator;
    if (navigator == null) return;
    _navigator = null;
    final route = widget.route;
    final sheet = route._sheet;
    final close = !route.isActive || velocity >= _fling || sheet.value < 0.5;
    if (close && route.isCurrent) navigator.pop();
    _settle(sheet, close ? 0 : 1, IqDurations.swap, _reduced);
    _whenSettled(sheet, () {
      route._dragging = false;
      navigator.didStopUserGesture();
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

/// The Dock's tab switch (spec 3.6): the branch navigators cross with the
/// 200 ms fade-through and nothing moves; hidden branches sit offstage with
/// their tickers off. A cut under reduced motion.
class FadeThroughBranches extends StatefulWidget {
  const FadeThroughBranches({
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
  ) =>
      FadeThroughBranches(currentIndex: shell.currentIndex, children: children);

  @override
  State<FadeThroughBranches> createState() => _FadeThroughBranchesState();
}

class _FadeThroughBranchesState extends State<FadeThroughBranches>
    with SingleTickerProviderStateMixin {
  late final AnimationController _switch = AnimationController(
    vsync: this,
    duration: IqDurations.swap,
    value: 1,
  )..addStatusListener(_onStatus);
  late final Animation<double> _in = _switch.drive(
    CurveTween(curve: FadeThroughCurves.incoming),
  );
  late final Animation<double> _out = _switch.drive(
    Tween<double>(
      begin: 1,
      end: 0,
    ).chain(CurveTween(curve: FadeThroughCurves.outgoing)),
  );
  int? _previous;

  void _onStatus(AnimationStatus status) {
    if (status.isCompleted && _previous != null && mounted) {
      setState(() => _previous = null);
    }
  }

  @override
  void didUpdateWidget(FadeThroughBranches old) {
    super.didUpdateWidget(old);
    if (old.currentIndex == widget.currentIndex) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _previous = null;
      _switch.value = 1;
    } else {
      _previous = old.currentIndex;
      _switch.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _switch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [for (var i = 0; i < widget.children.length; i++) _branch(i)],
    );
  }

  Widget _branch(int index) {
    final current = index == widget.currentIndex;
    final leaving = index == _previous;
    final Animation<double> opacity;
    if (current && _previous != null) {
      opacity = _in;
    } else if (leaving) {
      opacity = _out;
    } else {
      opacity = kAlwaysCompleteAnimation;
    }
    return Offstage(
      offstage: !current && !leaving,
      child: TickerMode(
        enabled: current,
        child: IgnorePointer(
          ignoring: !current,
          child: FadeTransition(
            opacity: opacity,
            child: widget.children[index],
          ),
        ),
      ),
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

  @override
  Widget build(BuildContext context) {
    // The hero controller looks for heroes from inside each page, below
    // the route's transitions, so the switch has to sit here.
    return HeroMode(
      enabled: !MediaQuery.disableAnimationsOf(context),
      child: Hero(
        tag: tag,
        curve: IqCurves.linear,
        flightShuttleBuilder:
            (context, animation, direction, fromHero, toHero) {
              final from = (fromHero.widget as Hero).child;
              final to = (toHero.widget as Hero).child;
              final push = direction == HeroFlightDirection.push;
              final shuttle = this.shuttle;
              if (shuttle == null) return push ? to : from;
              return shuttle(
                context,
                push ? animation : ReverseAnimation(animation),
                from,
                to,
              );
            },
        placeholderBuilder: (context, size, child) =>
            Opacity(opacity: 0, child: child),
        child: child,
      ),
    );
  }
}

/// Same screen, new state (spec 3.4): [child], told apart by its key,
/// crosses over the old one, 300 ms ease-out both ways (the exit reads
/// ease-in); a 150 ms crossfade under reduced motion.
class Dissolve extends StatelessWidget {
  const Dissolve({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: motion(context, IqDurations.screen, fade: true),
      switchInCurve: IqCurves.easeOut,
      switchOutCurve: IqCurves.easeOut,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
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
class IqOverlay extends StatefulWidget {
  const IqOverlay({
    super.key,
    required this.shown,
    required this.scrim,
    required this.card,
    required this.top,
    this.delay = Duration.zero,
  });

  final bool shown;
  final Color scrim;
  final Widget card;
  final double Function(BoxConstraints constraints) top;
  final Duration delay;

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
    return IgnorePointer(
      ignoring: !widget.shown,
      child: Material(
        type: MaterialType.transparency,
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              Positioned.fill(
                child: FadeTransition(
                  opacity: _Product(_scrimIn, ReverseAnimation(_scrimGone)),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    child: ColoredBox(color: widget.scrim),
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

class _Product extends CompoundAnimation<double> {
  _Product(Animation<double> first, Animation<double> next)
    : super(first: first, next: next);

  @override
  double get value => first.value * next.value;
}
