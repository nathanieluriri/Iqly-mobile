import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/patches.dart';
import '../../core/transitions.dart';
import '../../core/updates.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/brand_logo.dart';
import '../../ui/button.dart';

/// The official logomark as a glass: faded when empty, full colour rising
/// behind a wave to [level] (Figma B · Patch · fill motion). [wave] is the
/// wave's sideways drift, 0 to 1 per period; [still] draws a flat edge for
/// reduced motion.
class IqFillMark extends StatelessWidget {
  const IqFillMark({
    super.key,
    required this.level,
    this.wave = 0,
    this.still = false,
  });

  static const double size = 96;

  final double level;
  final double wave;
  final bool still;

  @override
  Widget build(BuildContext context) {
    const mark = IqBrandLogo(
      mark: IqBrandMark.logomark,
      width: size,
      height: size,
    );
    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          const Opacity(opacity: IqOpacity.patchEmpty, child: mark),
          if (level >= 1)
            mark
          else if (level > 0)
            ClipPath(
              clipper: _WaveClipper(level: level, wave: wave, still: still),
              child: mark,
            ),
        ],
      ),
    );
  }
}

class _WaveClipper extends CustomClipper<Path> {
  const _WaveClipper({
    required this.level,
    required this.wave,
    required this.still,
  });

  final double level;
  final double wave;
  final bool still;

  @override
  Path getClip(Size size) {
    final w = size.width;
    // The wave flattens near empty and full so no crest peeks past either end.
    final edge = still ? 0 : math.min(1, math.min(level, 1 - level) / 0.1);
    final a = IqPatchFill.wave * w / IqFillMark.size * edge;
    final y = size.height * (1 - level);
    final path = Path()..moveTo(-w + wave * w, y);
    for (var i = 0; i < 4; i++) {
      final x = -w + wave * w + i * w / 2;
      final peak = i.isEven ? y - a : y + a;
      path.cubicTo(x + w / 6, peak, x + w / 3, peak, x + w / 2, y);
    }
    return path
      ..lineTo(w * 2, size.height)
      ..lineTo(-w, size.height)
      ..close();
  }

  @override
  bool shouldReclip(_WaveClipper old) => old.level != level || old.wave != wave;
}

/// The filling mark on its own, rising and waving as Updating iQLY does,
/// for a wait with no dialog: a full-screen cover while the account is let
/// go. Reduced motion: no wave, the level holds at half.
class IqFillLoader extends StatefulWidget {
  const IqFillLoader({super.key});

  @override
  State<IqFillLoader> createState() => _IqFillLoaderState();
}

class _IqFillLoaderState extends State<IqFillLoader>
    with TickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: IqDurations.patchWave,
  );
  late final AnimationController _level = AnimationController(vsync: this);
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced) {
      _wave.stop();
      _level.value = IqPatchFill.stepped;
    } else if (!_wave.isAnimating) {
      _wave.repeat();
      _level.animateTo(
        IqPatchFill.hold,
        duration: IqDurations.patchRise,
        curve: const _Rise(),
      );
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    _level.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_wave, _level]),
      builder: (context, _) =>
          IqFillMark(level: _level.value, wave: _wave.value, still: _reduced),
    );
  }
}

/// A page body while its data loads: the filling mark in the middle
/// (owner, 18 Oct: no page waits blank).
class IqPageLoading extends StatelessWidget {
  const IqPageLoading({super.key, this.label = 'Loading'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      liveRegion: true,
      child: const Center(child: IqFillLoader()),
    );
  }
}

/// The patch dialog (Figma B · Patch, 1322:26867 / 1322:27353 / 1322:27844):
/// Updating iQLY while the patch downloads, Update applied once it is on
/// disk (its Close only takes the dialog down; the patch boots on the next
/// open), Couldn't update when it fails. It cannot be dismissed while updating; the
/// glass rises toward 85% with the wave moving, fills in 400 ms when done
/// (with the success haptic) and drains in 400 ms on a failure. The copy
/// crossfades in 150 ms. Reduced motion: no wave, the level steps 0, 50, 100.
class IqPatchDialog extends StatefulWidget {
  const IqPatchDialog({
    super.key,
    required this.phase,
    this.onClose,
    this.onContinue,
  });

  static const double width = 326;
  static const double radius = 24;

  final PatchPhase phase;
  final VoidCallback? onClose;
  final VoidCallback? onContinue;

  @override
  State<IqPatchDialog> createState() => _IqPatchDialogState();
}

class _IqPatchDialogState extends State<IqPatchDialog>
    with TickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: IqDurations.patchWave,
  );
  late final AnimationController _level = AnimationController(vsync: this);
  bool _reduced = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (!_started) {
      _started = true;
      _follow(null);
    }
  }

  @override
  void didUpdateWidget(IqPatchDialog old) {
    super.didUpdateWidget(old);
    if (old.phase != widget.phase) _follow(old.phase);
  }

  void _follow(PatchPhase? from) {
    final phase = widget.phase;
    if (phase == PatchPhase.ready && from != null) {
      IqHaptics.success.play();
    }
    if (_reduced) {
      _wave.stop();
      _level.value = switch (phase) {
        PatchPhase.downloading => IqPatchFill.stepped,
        PatchPhase.ready => 1,
        _ => 0,
      };
      return;
    }
    switch (phase) {
      case PatchPhase.downloading:
        _wave.repeat();
        _level.animateTo(
          IqPatchFill.hold,
          duration: IqDurations.patchRise,
          curve: const _Rise(),
        );
      case PatchPhase.ready:
        _level
            .animateTo(
              1,
              duration: IqDurations.patchFill,
              curve: IqCurves.easeOut,
            )
            .whenComplete(_wave.stop);
      case PatchPhase.failed:
      case PatchPhase.idle:
        _level
            .animateTo(
              0,
              duration: IqDurations.patchFill,
              curve: IqCurves.easeOut,
            )
            .whenComplete(_wave.stop);
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    _level.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (title, body) = switch (widget.phase) {
      PatchPhase.ready => (
        'Update applied',
        'Some bugs were fixed over the air. Restart the app for the fixes '
            'to fully appear.',
      ),
      PatchPhase.failed => (
        "Couldn't update",
        'Check your connection. iQLY will try again the next time you open '
            'it.',
      ),
      _ => (
        'Updating iQLY',
        'Getting the latest fixes. This takes a few seconds.',
      ),
    };
    return Container(
      width: IqPatchDialog.width,
      padding: const EdgeInsets.fromLTRB(IqSpace.s6, 28, IqSpace.s6, 28),
      decoration: BoxDecoration(
        color: IqColors.card,
        borderRadius: BorderRadius.circular(IqPatchDialog.radius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: Listenable.merge([_wave, _level]),
            builder: (context, _) => IqFillMark(
              level: _level.value,
              wave: _wave.value,
              still: _reduced,
            ),
          ),
          const SizedBox(height: IqSpace.s4),
          AnimatedSize(
            duration: IqDurations.crossfade,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: IqDurations.crossfade,
              child: Column(
                key: ValueKey(widget.phase),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: IqText.title.copyWith(color: IqColors.fg),
                  ),
                  const SizedBox(height: IqSpace.s2),
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: IqText.body.copyWith(color: IqColors.fg2),
                  ),
                  const SizedBox(height: IqSpace.s4),
                  ..._footer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _footer() => switch (widget.phase) {
    PatchPhase.ready => [
      IqButton(
        label: 'Close',
        showIcon: false,
        width: double.infinity,
        onTap: widget.onClose,
      ),
    ],
    PatchPhase.failed => [
      IqButton(
        label: 'Continue',
        width: double.infinity,
        onTap: widget.onContinue,
      ),
    ],
    _ => [
      Text(
        'Downloading update'.toUpperCase(),
        textAlign: TextAlign.center,
        style: IqText.mono.copyWith(color: IqColors.fg3),
      ),
    ],
  };
}

/// Eases toward its end like a filling glass: about 60% of [IqPatchFill.hold]
/// in the first 3 s of [IqDurations.patchRise].
class _Rise extends Curve {
  const _Rise();

  @override
  double transformInternal(double t) {
    final span = IqDurations.patchRise.inMilliseconds / 1000 / IqPatchFill.tau;
    return (1 - math.exp(-t * span)) / (1 - math.exp(-span));
  }
}

/// Shows the patch dialog over the app once there is a patch to tell about,
/// never over the splash or Time to update, and takes it down when the
/// phase goes back to idle.
class PatchPresenter extends ConsumerStatefulWidget {
  const PatchPresenter({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<PatchPresenter> createState() => _PatchPresenterState();
}

class _PatchPresenterState extends ConsumerState<PatchPresenter> {
  Route<void>? _route;

  @override
  void initState() {
    super.initState();
    widget.router.routerDelegate.addListener(_schedule);
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_schedule);
    super.dispose();
  }

  // The dialog has no page of its own, so it belongs to the page it was
  // pushed over and goes, without completing, when that page is replaced
  // (the splash handing over to Discover). After each route change it waits
  // for the new pages and comes back over them if it is gone.
  void _schedule() {
    WidgetsBinding.instance
      ..addPostFrameCallback((_) => _present())
      ..ensureVisualUpdate();
  }

  bool get _clear {
    final path = widget.router.routerDelegate.currentConfiguration.uri.path;
    return path != Routes.splash &&
        path != Routes.update &&
        !ref.read(updatesProvider.notifier).required;
  }

  void _present() {
    if (!mounted || (_route?.isActive ?? false)) return;
    if (ref.read(patchesProvider) == PatchPhase.idle || !_clear) return;
    final navigator = widget.router.routerDelegate.navigatorKey.currentState;
    if (navigator == null) return;
    final route = _PatchRoute();
    _route = route;
    navigator.push(route).whenComplete(() {
      if (_route == route) _route = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(patchesProvider, (previous, next) {
      final route = _route;
      if (next == PatchPhase.idle) {
        if (route != null && route.isActive) {
          route.navigator?.removeRoute(route);
        }
        _route = null;
      } else {
        _schedule();
      }
    });
    return widget.child;
  }
}

class _PatchRoute extends PageRouteBuilder<void> {
  _PatchRoute()
    : super(
        opaque: false,
        barrierDismissible: false,
        barrierColor: IqScrim.fg,
        transitionDuration: IqDurations.crossfade,
        reverseTransitionDuration: IqDurations.crossfade,
        pageBuilder: (context, _, _) => const _PatchPage(),
        transitionsBuilder: (context, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      );
}

class _PatchPage extends ConsumerWidget {
  const _PatchPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patches = ref.read(patchesProvider.notifier);
    return PopScope(
      canPop: false,
      child: Material(
        type: MaterialType.transparency,
        child: Center(
          child: IqPatchDialog(
            phase: ref.watch(patchesProvider),
            onClose: patches.dismiss,
            onContinue: patches.dismiss,
          ),
        ),
      ),
    );
  }
}
