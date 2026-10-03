import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../theme/theme.dart';

/// The motion values the wallet and withdrawal screens use, named after the
/// MOTION-SPEC §2 tokens. This is the only place they are written down: at
/// integration they point at the shared tokens in lib/core.
abstract final class WalletCurves {
  static const easeOut = Curves.easeOut;
  static const easeIn = Curves.easeIn;
  static const easeInOut = Curves.easeInOut;
  static const linear = Curves.linear;
}

abstract final class WalletDurations {
  static const chain = Duration(milliseconds: 120);
  static const crossfade = Duration(milliseconds: 150);
  static const tick = Duration(milliseconds: 160);
  static const ink = Duration(milliseconds: 180);
  static const swap = Duration(milliseconds: 200);
  static const appear = Duration(milliseconds: 220);
  static const mark = Duration(milliseconds: 240);
  static const enter = Duration(milliseconds: 260);
  static const screen = Duration(milliseconds: 300);
  static const screenBack = Duration(milliseconds: 240);
  static const morph = Duration(milliseconds: 320);
  static const stagger = Duration(milliseconds: 40);
  static const skeletonDelay = Duration(milliseconds: 300);
  static const skeletonMin = Duration(milliseconds: 600);

  /// A list's arrive: six slots 40 apart, each 260 long.
  static const list = Duration(milliseconds: 460);

  /// A moment's entrance, to the end of a Highlight wiping from +240.
  static const moment = Duration(milliseconds: 480);
}

abstract final class WalletTravel {
  static const double tick = 6;
  static const double rise = 8;
  static const double riseCard = 12;
  static const double riseHero = 16;
  static const double screen = 24;

  /// Arrive animates the first six items; the rest render in place.
  static const int staggerSlots = 6;

  /// A flung sheet closes at this speed (px/s), as BottomSheet does.
  static const double flingClose = 700;
}

abstract final class WalletOpacity {
  static const double sheetScrim = .5;
}

/// The duration under the reduced-motion setting: zero, or the crossfade
/// when the change still has to read.
Duration walletMotion(
  BuildContext context,
  Duration normal, {
  bool fade = false,
}) {
  if (!MediaQuery.disableAnimationsOf(context)) return normal;
  return fade ? WalletDurations.crossfade : Duration.zero;
}

/// MOTION-SPEC §2.7. Errors use [errorHaptic] from lib/core/motion.dart.
abstract final class WalletHaptics {
  /// A Primary, Inverse or Danger button tap.
  static Future<void> commit() => HapticFeedback.lightImpact();

  /// The result of the person's own action landed.
  static Future<void> success() => HapticFeedback.successNotification();
}

/// One controller for an entrance; the [Cue]s below it read their own
/// interval. It plays once, the first time it is in view (built in a hidden
/// tab it waits for the tab), and stays finished through rebuilds and tab
/// revisits. Reduced motion: every cue fades in together over the
/// crossfade, nothing moves.
class Choreography extends StatefulWidget {
  const Choreography({
    super.key,
    required this.length,
    required this.child,
    this.play = true,
  });

  final Duration length;
  final Widget child;

  /// False shows the end state at once.
  final bool play;

  static _ChoreographyScope? _of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ChoreographyScope>();

  @override
  State<Choreography> createState() => _ChoreographyState();
}

class _ChoreographyState extends State<Choreography>
    with SingleTickerProviderStateMixin {
  // Reduced motion already picked the crossfade; keep it at 150 rather than
  // the 5% Flutter would scale it to.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
  );
  bool _started = false;
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || !TickerMode.valuesOf(context).enabled) return;
    _started = true;
    _reduced = MediaQuery.disableAnimationsOf(context);
    _controller.duration = _reduced ? WalletDurations.crossfade : widget.length;
    if (widget.play) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _ChoreographyScope(
    controller: _controller,
    length: widget.length,
    reduced: _reduced,
    child: widget.child,
  );
}

class _ChoreographyScope extends InheritedWidget {
  const _ChoreographyScope({
    required this.controller,
    required this.length,
    required this.reduced,
    required super.child,
  });

  final AnimationController controller;
  final Duration length;
  final bool reduced;

  Interval interval(Duration at, Duration length) {
    final total = this.length.inMicroseconds;
    final start = (at.inMicroseconds / total).clamp(0.0, 1.0);
    final end = ((at + length).inMicroseconds / total).clamp(start, 1.0);
    return Interval(start, end, curve: WalletCurves.easeOut);
  }

  @override
  bool updateShouldNotify(_ChoreographyScope old) =>
      old.controller != controller || old.reduced != reduced;
}

/// One beat of a [Choreography]: from [at], over [length], [child] fades in
/// while it rises [rise] (arrive is 12 over 260, appear 8 over 220).
/// [fade] false is settle: a rise with the opacity untouched. [remount]
/// builds the child fresh when the beat starts, so a part that animates on
/// its own (a Highlight wipe) starts with it.
class Cue extends StatelessWidget {
  const Cue({
    super.key,
    required this.child,
    this.at = Duration.zero,
    this.length = WalletDurations.enter,
    this.rise = WalletTravel.riseCard,
    this.fade = true,
    this.remount = false,
  });

  final Widget child;
  final Duration at;
  final Duration length;
  final double rise;
  final bool fade;
  final bool remount;

  /// Arrive for the [index]th item of a list; items past the six slots
  /// render in place.
  static Widget arrive(int index, Widget child) =>
      index < WalletTravel.staggerSlots
      ? Cue(at: WalletDurations.stagger * index, child: child)
      : child;

  /// Settle for the [index]th part of a pushed screen.
  static Widget settle(int index, Widget child) =>
      index < WalletTravel.staggerSlots
      ? Cue(
          at: WalletDurations.stagger * index,
          rise: WalletTravel.rise,
          fade: false,
          child: child,
        )
      : child;

  @override
  Widget build(BuildContext context) {
    final scope = Choreography._of(context);
    if (scope == null) return child;
    final controller = scope.controller;
    if (scope.reduced) {
      return fade ? FadeTransition(opacity: controller, child: child) : child;
    }
    final interval = scope.interval(at, length);
    final progress = controller.drive(CurveTween(curve: interval));
    return AnimatedBuilder(
      animation: progress,
      child: child,
      builder: (context, child) {
        final t = progress.value;
        final started =
            !remount ||
            controller.isCompleted ||
            controller.value >= interval.begin;
        Widget out = KeyedSubtree(key: ValueKey(started), child: child!);
        if (!started) out = Opacity(opacity: 0, child: out);
        out = Transform.translate(
          offset: Offset(0, rise * (1 - t)),
          child: out,
        );
        return fade ? Opacity(opacity: t, child: out) : out;
      },
    );
  }
}

/// A brush that sweeps in left to right on its [Choreography] beat.
class CueWipe extends StatelessWidget {
  const CueWipe({
    super.key,
    required this.child,
    this.at = Duration.zero,
    this.length = WalletDurations.mark,
  });

  final Widget child;
  final Duration at;
  final Duration length;

  @override
  Widget build(BuildContext context) {
    final scope = Choreography._of(context);
    if (scope == null || scope.reduced) {
      return scope == null
          ? child
          : FadeTransition(opacity: scope.controller, child: child);
    }
    final progress = scope.controller.drive(
      CurveTween(curve: scope.interval(at, length)),
    );
    return AnimatedBuilder(
      animation: progress,
      child: child,
      builder: (context, child) =>
          ClipRect(clipper: _SweepClipper(progress.value), child: child),
    );
  }
}

class _SweepClipper extends CustomClipper<Rect> {
  const _SweepClipper(this.reveal);

  final double reveal;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, -size.height, size.width * reveal, size.height * 3);

  @override
  bool shouldReclip(_SweepClipper old) => old.reveal != reveal;
}

/// Text whose changed characters roll (MOTION-SPEC §2.5 roll): the old ones
/// slide up 6 and fade, the new ones slide in from below, 160 ease-out;
/// what both share at the start and the end stays still, and the width
/// eases. It shows its first text plainly. While its route is covered or
/// its tab hidden the change waits, and rolls when it is in view again.
/// Reduced motion: a cut.
class RollingText extends StatefulWidget {
  const RollingText(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<RollingText> createState() => _RollingTextState();
}

class _RollingTextState extends State<RollingText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _roll = AnimationController(
    vsync: this,
    duration: WalletDurations.tick,
  );
  late String _shown = widget.text;
  String? _from;

  bool get _inView => TickerMode.valuesOf(context).enabled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _catchUp();
  }

  @override
  void didUpdateWidget(RollingText old) {
    super.didUpdateWidget(old);
    _catchUp();
  }

  void _catchUp() {
    if (_shown == widget.text || !_inView) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _from = null;
    } else {
      _from = _shown;
      _roll.forward(from: 0).whenCompleteOrCancel(() {
        if (mounted) setState(() => _from = null);
      });
    }
    _shown = widget.text;
  }

  @override
  void dispose() {
    _roll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final from = _from;
    final text = Text(_shown, style: widget.style, maxLines: 1);
    final reduced = MediaQuery.disableAnimationsOf(context);
    final Widget body = from == null
        ? text
        : AnimatedBuilder(
            animation: _roll,
            builder: (context, _) => _rolling(from, _shown, _roll.value),
          );
    if (reduced) return body;
    return AnimatedSize(
      duration: WalletDurations.tick,
      curve: WalletCurves.easeOut,
      alignment: AlignmentDirectional.centerStart,
      child: body,
    );
  }

  Widget _rolling(String from, String to, double value) {
    final t = WalletCurves.easeOut.transform(value);
    var prefix = 0;
    while (prefix < from.length &&
        prefix < to.length &&
        from[prefix] == to[prefix]) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < from.length - prefix &&
        suffix < to.length - prefix &&
        from[from.length - 1 - suffix] == to[to.length - 1 - suffix]) {
      suffix++;
    }
    final oldMiddle = from.substring(prefix, from.length - suffix);
    final newMiddle = to.substring(prefix, to.length - suffix);
    final slots = math.max(oldMiddle.length, newMiddle.length);
    String at(String s, int i) {
      final j = i - (slots - s.length);
      return j < 0 ? '' : s[j];
    }

    Widget glyph(String char, double opacity, double dy) => Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, dy),
        child: Text(char, style: widget.style),
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        if (prefix > 0) Text(to.substring(0, prefix), style: widget.style),
        for (var i = 0; i < slots; i++)
          if (at(oldMiddle, i) == at(newMiddle, i))
            Text(at(newMiddle, i), style: widget.style)
          else
            Stack(
              clipBehavior: Clip.none,
              alignment: AlignmentDirectional.bottomStart,
              children: [
                glyph(at(oldMiddle, i), 1 - t, -WalletTravel.tick * t),
                glyph(at(newMiddle, i), t, WalletTravel.tick * (1 - t)),
              ],
            ),
        if (suffix > 0)
          Text(to.substring(to.length - suffix), style: widget.style),
      ],
    );
  }
}

/// MOTION-SPEC §2.6 LoadingGate: paper for the first 300; the skeleton if
/// the data is still loading; once shown, the skeleton stays at least 600,
/// then fades out over the crossfade while the content arrives. Data inside
/// 300 goes straight to the content. [keepSkeleton] starts on the skeleton
/// (a retry from a failed screen that already shows one).
class LoadingGate extends StatefulWidget {
  const LoadingGate({
    super.key,
    required this.loading,
    required this.skeleton,
    required this.child,
    this.keepSkeleton = false,
  });

  final bool loading;
  final Widget skeleton;
  final Widget child;
  final bool keepSkeleton;

  @override
  State<LoadingGate> createState() => _LoadingGateState();
}

enum _Gate { waiting, skeleton, content }

class _LoadingGateState extends State<LoadingGate> {
  _Gate _gate = _Gate.content;
  bool _fading = false;
  bool _minimumMet = true;
  Timer? _delay;
  Timer? _minimum;

  @override
  void initState() {
    super.initState();
    if (widget.loading) _start();
  }

  @override
  void didUpdateWidget(LoadingGate old) {
    super.didUpdateWidget(old);
    if (widget.loading && !old.loading) _start();
    if (!widget.loading && old.loading) _finish();
  }

  void _start() {
    _delay?.cancel();
    _fading = false;
    if (widget.keepSkeleton) {
      _showSkeleton();
      return;
    }
    _gate = _Gate.waiting;
    _delay = Timer(WalletDurations.skeletonDelay, () {
      if (mounted && widget.loading) setState(_showSkeleton);
    });
  }

  void _showSkeleton() {
    _gate = _Gate.skeleton;
    _minimumMet = false;
    _minimum?.cancel();
    _minimum = Timer(WalletDurations.skeletonMin, () {
      _minimumMet = true;
      if (mounted && !widget.loading) setState(_toContent);
    });
  }

  void _finish() {
    if (_gate == _Gate.waiting) {
      _delay?.cancel();
      _gate = _Gate.content;
    } else if (_gate == _Gate.skeleton && _minimumMet) {
      _toContent();
    }
  }

  void _toContent() {
    _fading = _gate == _Gate.skeleton;
    _gate = _Gate.content;
  }

  @override
  void dispose() {
    _delay?.cancel();
    _minimum?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return switch (_gate) {
      _Gate.waiting => const SizedBox.shrink(),
      _Gate.skeleton => widget.skeleton,
      _Gate.content => Stack(
        children: [
          widget.child,
          if (_fading)
            Positioned.fill(
              child: IgnorePointer(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 1, end: 0),
                  duration: walletMotion(context, WalletDurations.crossfade),
                  curve: WalletCurves.easeIn,
                  onEnd: () => setState(() => _fading = false),
                  builder: (context, opacity, child) =>
                      Opacity(opacity: opacity, child: child),
                  child: widget.skeleton,
                ),
              ),
            ),
        ],
      ),
    };
  }
}

/// A row added while the list is in view: its slot opens (240 ease-out),
/// then it arrives (fade and rise 12 over 260). Reduced motion: it fades in.
class ExpandIn extends StatefulWidget {
  const ExpandIn({super.key, required this.child});

  final Widget child;

  @override
  State<ExpandIn> createState() => _ExpandInState();
}

class _ExpandInState extends State<ExpandIn>
    with SingleTickerProviderStateMixin {
  static final _length = WalletDurations.mark + WalletDurations.enter;
  static final _split =
      WalletDurations.mark.inMicroseconds / _length.inMicroseconds;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
  );
  late final Animation<double> _open = _controller.drive(
    CurveTween(curve: Interval(0, _split, curve: WalletCurves.easeOut)),
  );
  late final Animation<double> _arrive = _controller.drive(
    CurveTween(curve: Interval(_split, 1, curve: WalletCurves.easeOut)),
  );
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isAnimating || _controller.isCompleted) return;
    _reduced = MediaQuery.disableAnimationsOf(context);
    _controller.duration = _reduced ? WalletDurations.crossfade : _length;
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduced) {
      return FadeTransition(opacity: _controller, child: widget.child);
    }
    return SizeTransition(
      sizeFactor: _open,
      alignment: AlignmentDirectional.topStart,
      child: AnimatedBuilder(
        animation: _arrive,
        child: widget.child,
        builder: (context, child) => Opacity(
          opacity: _arrive.value,
          child: Transform.translate(
            offset: Offset(0, WalletTravel.riseCard * (1 - _arrive.value)),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// MOTION-SPEC §3.1 and §3.2: the page comes in from 24 to the right and
/// fades in (300 ease-out), the page it covers drifts 24 left and fades
/// (ease-in); back reverses over 240. iOS keeps the native slide for the
/// edge swipe. Reduced motion: a 150 crossfade.
Page<T> walletPushPage<T>(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  if (defaultTargetPlatform == TargetPlatform.iOS &&
      !MediaQuery.disableAnimationsOf(context)) {
    return CupertinoPage<T>(key: state.pageKey, child: child);
  }
  final reduced = MediaQuery.disableAnimationsOf(context);
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: reduced
        ? WalletDurations.crossfade
        : WalletDurations.screen,
    reverseTransitionDuration: reduced
        ? WalletDurations.crossfade
        : WalletDurations.screenBack,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (reduced) return FadeTransition(opacity: animation, child: child);
      final incoming = animation.drive(CurveTween(curve: WalletCurves.easeOut));
      final fadeIn = animation.drive(
        CurveTween(curve: const Interval(0, .6, curve: WalletCurves.easeOut)),
      );
      final outgoing = secondaryAnimation.drive(
        CurveTween(curve: WalletCurves.easeIn),
      );
      final fadeOut = secondaryAnimation.drive(
        CurveTween(curve: const Interval(0, .5, curve: WalletCurves.easeIn)),
      );
      return AnimatedBuilder(
        animation: Listenable.merge([incoming, outgoing]),
        child: child,
        builder: (context, child) => Transform.translate(
          offset: Offset(
            WalletTravel.screen * (1 - incoming.value) -
                WalletTravel.screen * outgoing.value,
            0,
          ),
          child: FadeTransition(
            opacity: fadeIn,
            child: FadeTransition(
              opacity: ReverseAnimation(fadeOut),
              child: child,
            ),
          ),
        ),
      );
    },
  );
}

/// MOTION-SPEC §3.3: the sheet rises from the bottom edge over 300 ease-out
/// with the brand scrim fading to .5, drops over 200 (the reversed curve
/// reads ease-in). A drag on [SheetGrip] follows the finger and the scrim
/// fades with it; let go past half the height or flung down and it closes,
/// otherwise it settles back (200 ease-out). Tapping the scrim closes it.
/// Reduced motion: it fades in place over 150; a drag still follows.
Page<T> walletSheetPage<T>(
  BuildContext context,
  GoRouterState state,
  Widget sheet,
) {
  final reduced = MediaQuery.disableAnimationsOf(context);
  return CustomTransitionPage<T>(
    key: state.pageKey,
    opaque: false,
    barrierDismissible: true,
    barrierColor: Colors.transparent,
    transitionDuration: reduced
        ? WalletDurations.crossfade
        : WalletDurations.screen,
    reverseTransitionDuration: reduced
        ? WalletDurations.crossfade
        : WalletDurations.swap,
    child: sheet,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        _SheetFrame(animation: animation, reduced: reduced, child: child),
  );
}

class _SheetFrame extends StatefulWidget {
  const _SheetFrame({
    required this.animation,
    required this.reduced,
    required this.child,
  });

  final Animation<double> animation;
  final bool reduced;
  final Widget child;

  @override
  State<_SheetFrame> createState() => _SheetFrameState();
}

class _SheetFrameState extends State<_SheetFrame>
    with SingleTickerProviderStateMixin {
  final _sheet = GlobalKey();
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: WalletDurations.swap,
  )..addListener(() => setState(() => _drag = _settleFrom * (1 - _eased)));
  late final Animation<double> _rise = widget.animation.drive(
    CurveTween(curve: WalletCurves.easeOut),
  );
  double _drag = 0;
  double _settleFrom = 0;
  double _height = 1;

  double get _eased => WalletCurves.easeOut.transform(_settle.value);

  void _onDrag(double dy) {
    _height = _sheet.currentContext?.size?.height ?? _height;
    _settle.stop();
    setState(() => _drag = math.max(0, _drag + dy));
  }

  void _onRelease(double velocity) {
    if (_drag > _height / 2 || velocity > WalletTravel.flingClose) {
      Navigator.of(context).maybePop();
      return;
    }
    _settleFrom = _drag;
    if (widget.reduced) {
      setState(() => _drag = 0);
    } else {
      _settle.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dragged = _drag == 0 ? 0.0 : (_drag / _height).clamp(0.0, 1.0);
    return _SheetDrag(
      onDrag: _onDrag,
      onRelease: _onRelease,
      child: AnimatedBuilder(
        animation: _rise,
        child: widget.child,
        builder: (context, child) {
          final shown = widget.reduced ? widget.animation.value : _rise.value;
          return Stack(
            children: [
              // The sheet's own Close button is the labelled way out.
              Positioned.fill(
                child: ExcludeSemantics(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).maybePop(),
                    child: ColoredBox(
                      color: IqColors.brand.withValues(
                        alpha: WalletOpacity.sheetScrim * shown * (1 - dragged),
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Opacity(
                  opacity: widget.reduced ? shown : 1,
                  child: FractionalTranslation(
                    translation: Offset(0, widget.reduced ? 0 : 1 - shown),
                    child: Transform.translate(
                      offset: Offset(0, _drag),
                      child: KeyedSubtree(key: _sheet, child: child!),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SheetDrag extends InheritedWidget {
  const _SheetDrag({
    required this.onDrag,
    required this.onRelease,
    required super.child,
  });

  final ValueChanged<double> onDrag;
  final ValueChanged<double> onRelease;

  @override
  bool updateShouldNotify(_SheetDrag old) => false;
}

/// Wraps the part of a sheet that drags it (the grabber and its top bar).
class SheetGrip extends StatelessWidget {
  const SheetGrip({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final drag = context.getInheritedWidgetOfExactType<_SheetDrag>();
    if (drag == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      excludeFromSemantics: true,
      onVerticalDragUpdate: (details) => drag.onDrag(details.delta.dy),
      onVerticalDragEnd: (details) =>
          drag.onRelease(details.velocity.pixelsPerSecond.dy),
      child: child,
    );
  }
}
