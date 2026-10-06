import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/motion.dart';
import '../theme/theme.dart';

/// Figma Exp/Illustration, 200 x 160: an ink layer and an accent layer in
/// token colours, drawn with the icon brush. Bulb, Wallet, Trophy and Bell
/// are empty states; the rest mark onboarding and outcome moments.
enum IqIllustrations {
  bulb('bulb'),
  wallet('wallet'),
  trophy('trophy'),
  bell('bell'),
  card('card'),
  pin('pin'),
  pick('pick'),
  resume('return'),
  cheer('cheer'),
  sprout('sprout'),
  rocket('rocket'),
  megaphone('megaphone');

  const IqIllustrations(this.file);
  final String file;

  String get asset => 'assets/illustrations/$file.svg';

  /// How the accent layer plays (MOTION-SPEC 5.29): brush sweeps wipe left
  /// to right over their own bounds, sparks and lines pop from their own
  /// centre, the Rocket's flame lights from its top edge. Rects are in the
  /// 200 x 160 artboard.
  List<_AccentPart> get _accent => switch (this) {
    bulb => const [_AccentPart.wipe(Rect.fromLTRB(126.2, 1.6, 164.9, 51.1))],
    wallet => const [_AccentPart.wipe(Rect.fromLTRB(73.1, 3.8, 143, 49.4))],
    trophy => const [_AccentPart.wipe(Rect.fromLTRB(146.8, 9, 181.2, 25.3))],
    bell => const [_AccentPart.wipe(Rect.fromLTRB(141.6, 31.4, 161.6, 79.8))],
    card => const [_AccentPart.pop(Rect.fromLTRB(112.5, 70.5, 145.5, 95.5))],
    pick => const [_AccentPart.pop(Rect.fromLTRB(130.5, -3.5, 181.5, 37.5))],
    resume => const [_AccentPart.pop(Rect.fromLTRB(96.5, 64.5, 173.5, 129.5))],
    cheer => const [_AccentPart.pop(Rect.fromLTRB(32.5, -3.5, 169.5, 63.5))],
    megaphone => const [
      _AccentPart.pop(Rect.fromLTRB(154.5, 48.5, 185.5, 111.5)),
    ],
    sprout => const [
      _AccentPart.wipe(
        Rect.fromLTRB(60.5, 148.5, 139.5, 155.5),
        from: Rect.fromLTRB(0, 100, 200, 160),
      ),
      _AccentPart.pop(
        Rect.fromLTRB(158.5, 26.5, 185.5, 59.5),
        from: Rect.fromLTRB(0, 0, 200, 100),
      ),
    ],
    pin => const [
      _AccentPart.wipe(
        Rect.fromLTRB(66.5, 148.5, 133.5, 155.5),
        from: Rect.fromLTRB(0, 110, 200, 160),
      ),
      _AccentPart.pop(
        Rect.fromLTRB(86.5, 52.5, 113.5, 79.5),
        from: Rect.fromLTRB(0, 0, 200, 110),
      ),
    ],
    rocket => const [_AccentPart.flame(Rect.fromLTRB(84.5, 136, 115.5, 159.5))],
  };
}

/// How an illustration comes in (MOTION-SPEC 5.29, 5.32, 6.17).
enum IqIllustrationEntrance {
  /// It stands in place.
  none,

  /// The ink fades in as it rises 16, 320 ms ease-out; the accent plays at
  /// +160 (the Rocket's flame at +200, then the rocket lifts 4 and settles
  /// at +320).
  rise,

  /// The ink fades in as it drops from 12 above, 320 ms ease-out (Resume's
  /// pin); the accent plays at +160.
  drop,
}

/// [entrance] plays once, after [delay], on the first build. Reduced
/// motion: the whole illustration fades in over 150.
class IqIllustration extends StatefulWidget {
  const IqIllustration(
    this.kind, {
    super.key,
    this.width = designWidth,
    this.entrance = IqIllustrationEntrance.none,
    this.delay = Duration.zero,
  });

  final IqIllustrations kind;
  final double width;
  final IqIllustrationEntrance entrance;
  final Duration delay;

  static const double designWidth = 200;
  static const double designHeight = 160;

  @override
  State<IqIllustration> createState() => _IqIllustrationState();
}

class _IqIllustrationState extends State<IqIllustration>
    with SingleTickerProviderStateMixin {
  static final Duration _flameLight = IqDurations.tick;
  static final Duration _flicker = IqDurations.mark;
  static final Duration _lift = IqDurations.mark;

  late final AnimationController _clock = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
  )..addStatusListener(_onStatus);
  bool _playing = false;
  bool _reduced = false;

  bool get _rocket => widget.kind == IqIllustrations.rocket;

  Duration get _accentAt =>
      _rocket ? IqMomentTiming.flameAt : IqMomentTiming.accentAt;

  Duration get _length {
    final accent = _rocket
        ? _flameLight + _flicker * 2
        : widget.kind._accent.any((part) => part.move == _Move.wipe)
        ? IqDurations.mark
        : IqDurations.appear;
    var end = _accentAt + accent;
    if (end < IqDurations.morph) end = IqDurations.morph;
    return widget.delay + end;
  }

  void _onStatus(AnimationStatus status) {
    if (status.isCompleted && mounted) setState(() => _playing = false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_clock.duration != null ||
        widget.entrance == IqIllustrationEntrance.none) {
      return;
    }
    _reduced = MediaQuery.disableAnimationsOf(context);
    _clock.duration = _reduced ? IqDurations.crossfade : _length;
    _playing = true;
    _clock.forward();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  double get _height =>
      widget.width * IqIllustration.designHeight / IqIllustration.designWidth;

  /// The share of the clock between [at] and [at] + [length], eased.
  double _span(Duration at, Duration length, Curve curve) {
    final now = _clock.value * _clock.duration!.inMicroseconds;
    final from = (widget.delay + at).inMicroseconds;
    return curve.transform(
      ((now - from) / length.inMicroseconds).clamp(0.0, 1.0),
    );
  }

  Widget _picture([ColorMapper? layer]) => SvgPicture(
    SvgAssetLoader(widget.kind.asset, colorMapper: layer),
    width: widget.width,
    height: _height,
    excludeFromSemantics: true,
  );

  @override
  Widget build(BuildContext context) {
    final whole = _picture();
    if (widget.entrance == IqIllustrationEntrance.none) return whole;
    // The whole picture stays mounted under the layers, so it is decoded and
    // ready when it takes over at the end.
    return AnimatedBuilder(
      animation: _clock,
      builder: (context, _) {
        final playing = _playing && !_reduced;
        final scale = widget.width / IqIllustration.designWidth;
        final ink = _span(Duration.zero, IqDurations.morph, IqCurves.easeOut);
        final drop = widget.entrance == IqIllustrationEntrance.drop;
        final inkShift = drop
            ? -IqTravel.riseCard * (1 - ink)
            : IqTravel.riseHero * (1 - ink);
        var lift = 0.0;
        if (_rocket && playing) {
          final q = _span(IqMomentTiming.liftAt, _lift, IqCurves.easeInOut);
          lift = -IqTravel.nudge * math.sin(math.pi * q);
        }
        final wholeOpacity = !_playing
            ? 1.0
            : _reduced
            ? IqCurves.easeOut.transform(_clock.value)
            : 0.0;
        return Transform.translate(
          offset: Offset(0, lift),
          child: SizedBox(
            width: widget.width,
            height: _height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Opacity(opacity: wholeOpacity, child: whole),
                if (playing) ...[
                  Transform.translate(
                    offset: Offset(0, inkShift),
                    child: Opacity(
                      opacity: ink,
                      child: _picture(const _Layer(IqColors.brand)),
                    ),
                  ),
                  for (final part in widget.kind._accent)
                    _part(part, scale, _picture(const _Layer(IqColors.accent))),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _part(_AccentPart part, double scale, Widget accent) {
    final from = part.from;
    Widget layer = from == null
        ? accent
        : ClipRect(clipper: _Clip(_scaled(from, scale)), child: accent);
    switch (part.move) {
      case _Move.wipe:
        final p = _span(_accentAt, IqDurations.mark, IqCurves.easeOut);
        if (p <= 0) return const SizedBox.shrink();
        final bounds = _scaled(part.bounds, scale);
        return ClipRect(
          clipper: _Clip(
            Rect.fromLTRB(
              -_height,
              -_height,
              p >= 1 ? widget.width + _height : bounds.left + bounds.width * p,
              _height * 2,
            ),
          ),
          child: layer,
        );
      case _Move.pop:
        final p = _span(_accentAt, IqDurations.appear, IqCurves.easeOut);
        if (p <= 0) return const SizedBox.shrink();
        final centre = _scaled(part.bounds, scale).center;
        return Opacity(
          opacity: p,
          child: Transform.scale(
            scale: IqScale.pop + (1 - IqScale.pop) * p,
            origin: centre - Offset(widget.width / 2, _height / 2),
            child: layer,
          ),
        );
      case _Move.flame:
        final light = _span(_accentAt, _flameLight, IqCurves.easeOut);
        if (light <= 0) return const SizedBox.shrink();
        var flicker = 0.0;
        for (var i = 0; i < 2; i++) {
          final q = _span(
            _accentAt + _flameLight + _flicker * i,
            _flicker,
            IqCurves.easeInOut,
          );
          if (q > 0 && q < 1) flicker = math.sin(math.pi * q);
        }
        final top = part.bounds.top * scale;
        return Transform(
          alignment: Alignment.topLeft,
          transform: Matrix4.identity()
            ..translateByDouble(0, top, 0, 1)
            ..scaleByDouble(
              1,
              light * (1 - (1 - IqScale.flicker) * flicker),
              1,
              1,
            )
            ..translateByDouble(0, -top, 0, 1),
          child: layer,
        );
    }
  }

  static Rect _scaled(Rect rect, double scale) => Rect.fromLTRB(
    rect.left * scale,
    rect.top * scale,
    rect.right * scale,
    rect.bottom * scale,
  );
}

enum _Move { wipe, pop, flame }

class _AccentPart {
  const _AccentPart.wipe(this.bounds, {this.from}) : move = _Move.wipe;

  const _AccentPart.pop(this.bounds, {this.from}) : move = _Move.pop;

  /// The flame lights from the top edge of [bounds].
  const _AccentPart.flame(this.bounds) : from = null, move = _Move.flame;

  final Rect bounds;

  /// The part of the accent layer this beat moves; all of it when null.
  final Rect? from;
  final _Move move;
}

class _Clip extends CustomClipper<Rect> {
  const _Clip(this.rect);

  final Rect rect;

  @override
  Rect getClip(Size size) => rect;

  @override
  bool shouldReclip(_Clip old) => old.rect != rect;
}

/// Keeps only the paths drawn in [keep] (the ink or the accent).
class _Layer extends ColorMapper {
  const _Layer(this.keep);

  final Color keep;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) => color.toARGB32() == keep.toARGB32() ? color : color.withValues(alpha: 0);

  @override
  bool operator ==(Object other) => other is _Layer && other.keep == keep;

  @override
  int get hashCode => keep.hashCode;
}

/// Figma Exp/Figure, 320 x 340: hand-drawn people and objects.
enum IqFigures {
  thinker,
  caller,
  reach,
  saver,
  cheer,
  point,
  shrug,
  writer,
  sender,
  gift;

  String get asset => 'assets/illustrations/figure-$name.svg';
}

/// [arrive] fades it in as it rises 16, 320 ms ease-out, once, after
/// [delay] (MOTION-SPEC 5.29); it fades only, 150, under reduced motion.
class IqFigure extends StatelessWidget {
  const IqFigure(
    this.figure, {
    super.key,
    this.width = designWidth,
    this.arrive = false,
    this.delay = Duration.zero,
  });

  final IqFigures figure;
  final double width;
  final bool arrive;
  final Duration delay;

  static const double designWidth = 320;
  static const double designHeight = 340;

  @override
  Widget build(BuildContext context) {
    final picture = SvgPicture.asset(
      figure.asset,
      width: width,
      height: width * designHeight / designWidth,
      excludeFromSemantics: true,
    );
    if (!arrive) return picture;
    return Sequence(
      length: delay + BeatMove.rise.length,
      child: Beat(at: delay, move: BeatMove.rise, child: picture),
    );
  }
}

/// Figma Exp/LineArt, 280 x 280 monoline, three keyframes of the landing loop.
enum IqLineArtFrames {
  frame1,
  frame2,
  frame3;

  String get asset => 'assets/illustrations/lineart-${index + 1}.svg';
}

class IqLineArt extends StatelessWidget {
  const IqLineArt(this.frame, {super.key, this.size = designSize});

  final IqLineArtFrames frame;
  final double size;

  static const double designSize = 280;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      frame.asset,
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }
}
