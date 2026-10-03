import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/session.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import 'splash_mark.dart';

/// Boot splash (Figma B · Splash 1 to 4): the mark lights grey to bulb to
/// brush, then settles into the lockup and dissolves into the app.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  SplashPhase _phase = SplashPhase.dark;
  Duration _duration = Duration.zero;
  bool _started = false;

  /// Each step: the phase to enter, how long the previous phase holds, and
  /// how long the Smart Animate transition takes.
  static const _timeline = [
    (
      SplashPhase.spark,
      Duration(milliseconds: 300),
      Duration(milliseconds: 500),
    ),
    (SplashPhase.lit, Duration(milliseconds: 400), Duration(milliseconds: 700)),
    (
      SplashPhase.settled,
      Duration(milliseconds: 500),
      Duration(milliseconds: 600),
    ),
  ];
  static const _settledHold = Duration(milliseconds: 600);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _run(reducedMotion: MediaQuery.disableAnimationsOf(context));
  }

  Future<void> _run({required bool reducedMotion}) async {
    if (reducedMotion) {
      await _wait(_timeline.first.$2);
      if (!mounted) return;
      _go(SplashPhase.settled, const Duration(milliseconds: 400));
      await _wait(const Duration(milliseconds: 400));
    } else {
      for (final (phase, hold, move) in _timeline) {
        await _wait(hold);
        if (!mounted) return;
        _go(phase, move);
        await _wait(move);
      }
    }
    await _wait(_settledHold);
    if (!mounted) return;
    final signedIn = ref.read(sessionProvider).signedIn;
    context.go(signedIn ? Routes.home : Routes.landing);
  }

  void _go(SplashPhase phase, Duration duration) {
    setState(() {
      _phase = phase;
      _duration = duration;
    });
  }

  Future<void> _wait(Duration d) => Future<void>.delayed(d);

  @override
  Widget build(BuildContext context) {
    final pose = _Pose.of(_phase, MediaQuery.sizeOf(context));
    const curve = Curves.easeInOut;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: IqColors.brandDark,
        body: Stack(
          children: [
            AnimatedPositioned(
              duration: _duration,
              curve: curve,
              left: pose.tileLeft,
              top: pose.tileTop,
              width: pose.tile,
              height: pose.tile,
              child: AnimatedOpacity(
                duration: _duration,
                curve: curve,
                opacity: pose.tileOpacity,
                child: SplashMark(
                  phase: _phase,
                  duration: _duration,
                  tile: pose.tile,
                ),
              ),
            ),
            AnimatedPositioned(
              duration: _duration,
              curve: curve,
              left: pose.wordmarkLeft,
              top: pose.wordmarkTop,
              width: _Pose.wordmarkWidth,
              height: _Pose.wordmarkHeight,
              child: AnimatedOpacity(
                duration: _duration,
                curve: curve,
                opacity: pose.wordmarkOpacity,
                child: SvgPicture.asset('assets/brand/iqly-logo-cream.svg'),
              ),
            ),
            Positioned(
              left: pose.progressLeft,
              top: pose.progressTop,
              width: _Pose.progressWidth,
              height: _Pose.progressHeight,
              child: AnimatedOpacity(
                duration: _duration,
                curve: curve,
                opacity: pose.progressOpacity,
                child: _Progress(fraction: pose.progress, duration: _duration),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Positions from the 390 x 844 Figma frame, expressed against the real
/// screen size. The Dark pose centres the mark exactly where the native splash
/// draws it, so the hand-off has no jump; the Spark move settles it on the
/// Figma baseline (centre at 400 of 844).
class _Pose {
  const _Pose({
    required this.tile,
    required this.tileLeft,
    required this.tileTop,
    required this.tileOpacity,
    required this.wordmarkLeft,
    required this.wordmarkTop,
    required this.wordmarkOpacity,
    required this.progressLeft,
    required this.progressTop,
    required this.progress,
    required this.progressOpacity,
  });

  static const double frameHeight = 844;
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
  final double tileLeft;
  final double tileTop;
  final double tileOpacity;
  final double wordmarkLeft;
  final double wordmarkTop;
  final double wordmarkOpacity;
  final double progressLeft;
  final double progressTop;
  final double progress;
  final double progressOpacity;

  static _Pose of(SplashPhase phase, Size size) {
    final w = size.width;
    final h = size.height;
    final settled = phase == SplashPhase.settled;
    final tile = settled ? settledTile : SplashMark.designTile;
    final centreY = phase == SplashPhase.dark
        ? h / 2
        : h * markCentreY / frameHeight;
    final centreX = settled ? w / 2 - settledTileShift : w / 2;
    final progress = switch (phase) {
      SplashPhase.dark => 0.0,
      SplashPhase.spark => 0.4,
      SplashPhase.lit => 92 / 120,
      SplashPhase.settled => 1.0,
    };
    return _Pose(
      tile: tile,
      tileLeft: centreX - tile / 2,
      tileTop: centreY - tile / 2,
      tileOpacity: settled ? 0 : 1,
      wordmarkLeft:
          w / 2 - wordmarkWidth / 2 + (settled ? 0 : wordmarkEntryShift),
      wordmarkTop: h * markCentreY / frameHeight - wordmarkHeight / 2,
      wordmarkOpacity: settled ? 1 : 0,
      progressLeft: w / 2 - progressWidth / 2,
      progressTop: h * progressCentreY / frameHeight - progressHeight / 2,
      progress: progress,
      progressOpacity: settled ? 0 : 1,
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.fraction, required this.duration});

  final double fraction;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: IqColors.brand,
        borderRadius: BorderRadius.circular(IqRadius.full),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnimatedFractionallySizedBox(
          duration: duration,
          curve: Curves.easeInOut,
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
