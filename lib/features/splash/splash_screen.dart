import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/backend.dart';
import '../../core/motion.dart';
import '../../core/session.dart';
import '../../core/transitions.dart';
import '../../core/updates.dart';
import '../../data/app_config.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/brand_logo.dart';
import '../entry/landing_screen.dart';
import '../onboarding/onboarding_draft.dart';
import 'splash_mark.dart';

/// Boot splash (Figma B · Splash 1 to 4): the mark lights grey to bulb to
/// brush, then settles into the lockup and hands off to the app.
///
/// Motion (MOTION-SPEC 6.1, 3.9), one controller, ease in and out: on the
/// first launch the Figma timeline plays (Dark holds 300, Spark 500, holds
/// 400, Lit 700, holds 500, Settled 600, holds 600; the progress fills to
/// 32, 92 and 120 of 120); later launches, and reduced motion, hold Dark
/// for 300, crossfade to Settled in place over 400 and hold 600. Then the
/// hand-off, 400: signed out, the wordmark travels onto the landing logo
/// while the paper comes up and the cream file gives way to the ink one,
/// and the landing takes over with no transition; signed in or mid
/// onboarding (and under reduced motion), the next screen dissolves in.
/// Either way the status bar turns dark 200 into the hand-off.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  /// Set once the light-up has played on this device.
  static const litKey = 'splash.lit';

  /// Where the settled wordmark stands on a [size] screen, for a screen that
  /// takes it over.
  static Rect wordmarkRect(Size size) => Rect.fromCenter(
    center: Offset(
      size.width / 2,
      size.height * _Frame.markCentreY / _Frame.frame,
    ),
    width: _Frame.wordmarkWidth,
    height: _Frame.wordmarkHeight,
  );

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
  );
  late _Timeline _timeline;
  bool _started = false;
  bool _handedOff = false;
  bool _holding = false;
  bool _landed = false;
  OverlayEntry? _statusHold;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final lit = ref
        .read(sharedPreferencesProvider)
        .getBool(SplashScreen.litKey);
    _timeline = _Timeline(
      full: !reduced && lit != true,
      lockup: !reduced && !ref.read(sessionProvider).signedIn,
    );
    _clock
      ..duration = _timeline.total
      ..addListener(_onTick)
      ..forward();
    unawaited(ref.read(updatesProvider.notifier).check());
    final config = ref.read(appConfigProvider.notifier);
    unawaited(
      ref.read(backendProvider.notifier).check().whenComplete(config.refresh),
    );
  }

  Duration get _now => _timeline.total * _clock.value;

  void _onTick() {
    final now = _now;
    if (!_handedOff && now >= _timeline.handoff) _handOff();
    if (_statusHold != null &&
        now >= _timeline.handoff + IqSplashTiming.statusBarAt) {
      _releaseStatusBar();
    }
    if (_timeline.lockup && !_holding && !_landed && _clock.isCompleted) {
      _landed = true;
      context.go(Routes.landing, extra: Arrival.lockup);
    }
  }

  void _handOff() {
    _handedOff = true;
    ref.read(sharedPreferencesProvider).setBool(SplashScreen.litKey, true);
    final updates = ref.read(updatesProvider.notifier);
    final backend = ref.read(backendProvider.notifier);
    if (!updates.checking && !backend.checking) {
      _leave();
      return;
    }
    // The settled splash holds up to 2 s past its own run for the version
    // and health checks, from the hand-off itself whatever frame crossed it;
    // no answer by then opens the app as usual.
    _holding = true;
    _clock
      ..stop()
      ..value =
          _timeline.handoff.inMicroseconds / _timeline.total.inMicroseconds;
    Future.wait([
      updates.settled(UpdatesNotifier.splashWait),
      backend.settled(UpdatesNotifier.splashWait),
    ]).then((_) {
      if (!mounted) return;
      _holding = false;
      _leave();
      if (!_landed) _clock.forward();
    });
  }

  void _leave() {
    unawaited(ref.read(backendProvider.notifier).lock());
    if (ref.read(updatesProvider.notifier).required) {
      _clock.stop();
      _landed = true;
      context.go(
        Routes.update,
        extra: MediaQuery.disableAnimationsOf(context) ? null : Arrival.lockup,
      );
      return;
    }
    if (_timeline.lockup) return;
    final session = ref.read(sessionProvider);
    final String next;
    if (!session.signedIn) {
      next = Routes.landing;
    } else {
      final draft = ref.read(onboardingDraftProvider);
      next = onboardingLaunchRoute(session, draft) ?? Routes.home;
    }
    _holdStatusBar();
    context.go(next, extra: Arrival.splash);
  }

  /// The next screen dissolves in over the splash; this strip keeps the
  /// splash's light status bar above it until 200 in.
  void _holdStatusBar() {
    final top = MediaQuery.paddingOf(context).top;
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: top + 1,
        child: const IgnorePointer(
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light,
            child: SizedBox.expand(),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(entry);
    _statusHold = entry;
  }

  void _releaseStatusBar() {
    final entry = _statusHold;
    _statusHold = null;
    entry
      ?..remove()
      ..dispose();
  }

  @override
  void dispose() {
    final entry = _statusHold;
    _statusHold = null;
    if (entry != null) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        entry
          ..remove()
          ..dispose();
      });
    }
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return AnimatedBuilder(
      animation: _clock,
      builder: (context, _) {
        final frame = _timeline.frameAt(_now, media.size, media.padding.top);
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: frame.darkStatusBar
              ? SystemUiOverlayStyle.dark
              : SystemUiOverlayStyle.light,
          child: Scaffold(
            backgroundColor: Color.lerp(
              IqColors.brandDark,
              IqColors.bg,
              frame.paper,
            ),
            body: Stack(
              children: [
                Positioned(
                  left: frame.tileCentre.dx - frame.tile / 2,
                  top: frame.tileCentre.dy - frame.tile / 2,
                  width: frame.tile,
                  height: frame.tile,
                  child: Opacity(
                    opacity: frame.tileOpacity,
                    child: SplashMark(pose: frame.mark, tile: frame.tile),
                  ),
                ),
                Positioned(
                  left: frame.wordmarkCentre.dx - _Frame.wordmarkWidth / 2,
                  top: frame.wordmarkCentre.dy - _Frame.wordmarkHeight / 2,
                  width: _Frame.wordmarkWidth,
                  height: _Frame.wordmarkHeight,
                  child: Opacity(
                    opacity: frame.wordmarkOpacity,
                    child: Transform.scale(
                      scale: frame.wordmarkScale,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Opacity(
                            opacity: 1 - frame.inkLogo,
                            child: const IqBrandLogo(tone: IqBrandTone.onDark),
                          ),
                          if (frame.inkLogo > 0)
                            Opacity(
                              opacity: frame.inkLogo,
                              child: const IqBrandLogo(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: media.size.width / 2 - _Frame.progressWidth / 2,
                  top:
                      media.size.height *
                          _Frame.progressCentreY /
                          _Frame.frame -
                      _Frame.progressHeight / 2,
                  width: _Frame.progressWidth,
                  height: _Frame.progressHeight,
                  child: Opacity(
                    opacity: frame.progressOpacity,
                    child: _Progress(fraction: frame.progress),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// When things happen on this launch's splash.
class _Timeline {
  _Timeline({required this.full, required this.lockup});

  /// The full Figma light-up rather than the in-place crossfade.
  final bool full;

  /// The wordmark travels onto the landing logo rather than a dissolve.
  final bool lockup;

  static const _darkHold = IqSplashTiming.darkHold;
  static final _sparkAt = _darkHold;
  static final _sparkEnd = _sparkAt + IqSplashTiming.toSpark;
  static final _litAt = _sparkEnd + IqSplashTiming.sparkHold;
  static final _litEnd = _litAt + IqSplashTiming.toLit;
  static final _settleAt = _litEnd + IqSplashTiming.litHold;
  static final _settleEnd = _settleAt + IqSplashTiming.toSettled;
  static final _crossfadeEnd = _darkHold + IqSplashTiming.settleInPlace;

  Duration get handoff =>
      (full ? _settleEnd : _crossfadeEnd) + IqSplashTiming.settledHold;

  Duration get total => handoff + IqDurations.handoff;

  static double _progress(Duration now, Duration from, Duration to) =>
      IqCurves.easeInOut.transform(
        ((now - from).inMicroseconds / (to - from).inMicroseconds).clamp(
          0.0,
          1.0,
        ),
      );

  _Frame frameAt(Duration now, Size size, double safeTop) {
    final frame = full ? _lightUp(now, size) : _inPlace(now, size);
    if (!lockup || now < handoff) return frame;
    final at = now - handoff;
    final travel = _progress(at, Duration.zero, IqDurations.handoff);
    final logoHeight =
        LandingScreen.logoWidth * _Frame.wordmarkHeight / _Frame.wordmarkWidth;
    final landing = Offset(
      size.width / 2,
      safeTop + LandingScreen.logoTop + logoHeight / 2,
    );
    return frame.copyWith(
      paper: IqCurves.easeOut.transform(
        (at.inMicroseconds / IqDurations.handoff.inMicroseconds).clamp(0, 1),
      ),
      wordmarkCentre: Offset.lerp(frame.wordmarkCentre, landing, travel),
      wordmarkScale: lerpDouble(
        1,
        LandingScreen.logoWidth / _Frame.wordmarkWidth,
        travel,
      ),
      inkLogo: _progress(
        at,
        IqSplashTiming.logoSwapFrom,
        IqSplashTiming.logoSwapTo,
      ),
      darkStatusBar: at >= IqSplashTiming.statusBarAt,
    );
  }

  _Frame _lightUp(Duration now, Size size) {
    final (from, to, t) = switch (now) {
      _ when now < _sparkAt => (SplashPhase.dark, SplashPhase.dark, 0.0),
      _ when now < _litAt => (
        SplashPhase.dark,
        SplashPhase.spark,
        _progress(now, _sparkAt, _sparkEnd),
      ),
      _ when now < _settleAt => (
        SplashPhase.spark,
        SplashPhase.lit,
        _progress(now, _litAt, _litEnd),
      ),
      _ => (
        SplashPhase.lit,
        SplashPhase.settled,
        _progress(now, _settleAt, _settleEnd),
      ),
    };
    return _Frame.lerp(_Frame.of(from, size), _Frame.of(to, size), t);
  }

  /// Dark crossfades to Settled where each stands: nothing travels or
  /// scales (Figma 142:5873 "Reduced motion: Dark → Settled crossfade.").
  _Frame _inPlace(Duration now, Size size) {
    final t = _progress(now, _darkHold, _crossfadeEnd);
    final dark = _Frame.of(SplashPhase.dark, size);
    final settled = _Frame.of(SplashPhase.settled, size);
    return dark.copyWith(
      tileOpacity: 1 - t,
      wordmarkCentre: settled.wordmarkCentre,
      wordmarkOpacity: t,
      progressOpacity: 1 - t,
    );
  }
}

/// Everything the splash draws at one moment, against the real screen;
/// positions come from the 390 x 844 Figma frame. The Dark pose centres the
/// mark where the native splash draws it, so the boot has no jump; the
/// Spark move settles it on the Figma baseline (centre at 400 of 844).
class _Frame {
  const _Frame({
    required this.tile,
    required this.tileCentre,
    required this.tileOpacity,
    required this.mark,
    required this.wordmarkCentre,
    required this.wordmarkOpacity,
    required this.progress,
    required this.progressOpacity,
    this.wordmarkScale = 1,
    this.inkLogo = 0,
    this.paper = 0,
    this.darkStatusBar = false,
  });

  static const double frame = 844;
  static const double markCentreY = 400;
  static const double wordmarkWidth = 210;
  static const double wordmarkHeight = 52;
  static const double progressWidth = 120;
  static const double progressHeight = 2;
  static const double progressCentreY = 746;
  static const double settledTile = 130;
  static const double settledTileShift = 79;
  static const double wordmarkEntryShift = 8;

  final double tile;
  final Offset tileCentre;
  final double tileOpacity;
  final SplashMarkPose mark;
  final Offset wordmarkCentre;
  final double wordmarkOpacity;
  final double wordmarkScale;

  /// How far the wordmark has gone from the cream file to the ink one.
  final double inkLogo;
  final double progress;
  final double progressOpacity;

  /// How far the background has gone from brand-dark to paper.
  final double paper;
  final bool darkStatusBar;

  static _Frame of(SplashPhase phase, Size size) {
    final settled = phase == SplashPhase.settled;
    final baseline = size.height * markCentreY / frame;
    return _Frame(
      tile: settled ? settledTile : SplashMark.designTile,
      tileCentre: Offset(
        settled ? size.width / 2 - settledTileShift : size.width / 2,
        phase == SplashPhase.dark ? size.height / 2 : baseline,
      ),
      tileOpacity: settled ? 0 : 1,
      mark: SplashMarkPose.of(phase),
      wordmarkCentre: Offset(
        size.width / 2 + (settled ? 0 : wordmarkEntryShift),
        baseline,
      ),
      wordmarkOpacity: settled ? 1 : 0,
      progress: switch (phase) {
        SplashPhase.dark => 0,
        SplashPhase.spark => 32 / 120,
        SplashPhase.lit => 92 / 120,
        SplashPhase.settled => 1,
      },
      progressOpacity: settled ? 0 : 1,
    );
  }

  static _Frame lerp(_Frame a, _Frame b, double t) => _Frame(
    tile: lerpDouble(a.tile, b.tile, t)!,
    tileCentre: Offset.lerp(a.tileCentre, b.tileCentre, t)!,
    tileOpacity: lerpDouble(a.tileOpacity, b.tileOpacity, t)!,
    mark: SplashMarkPose.lerp(a.mark, b.mark, t),
    wordmarkCentre: Offset.lerp(a.wordmarkCentre, b.wordmarkCentre, t)!,
    wordmarkOpacity: lerpDouble(a.wordmarkOpacity, b.wordmarkOpacity, t)!,
    progress: lerpDouble(a.progress, b.progress, t)!,
    progressOpacity: lerpDouble(a.progressOpacity, b.progressOpacity, t)!,
  );

  _Frame copyWith({
    double? tileOpacity,
    Offset? wordmarkCentre,
    double? wordmarkOpacity,
    double? wordmarkScale,
    double? inkLogo,
    double? progressOpacity,
    double? paper,
    bool? darkStatusBar,
  }) => _Frame(
    tile: tile,
    tileCentre: tileCentre,
    tileOpacity: tileOpacity ?? this.tileOpacity,
    mark: mark,
    wordmarkCentre: wordmarkCentre ?? this.wordmarkCentre,
    wordmarkOpacity: wordmarkOpacity ?? this.wordmarkOpacity,
    wordmarkScale: wordmarkScale ?? this.wordmarkScale,
    inkLogo: inkLogo ?? this.inkLogo,
    progress: progress,
    progressOpacity: progressOpacity ?? this.progressOpacity,
    paper: paper ?? this.paper,
    darkStatusBar: darkStatusBar ?? this.darkStatusBar,
  );
}

class _Progress extends StatelessWidget {
  const _Progress({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: IqColors.brand,
        borderRadius: BorderRadius.circular(IqRadius.full),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: fraction,
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: IqColors.accent,
              borderRadius: BorderRadius.circular(IqRadius.full),
            ),
          ),
        ),
      ),
    );
  }
}
