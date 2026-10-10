import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/theme.dart';
import 'avatar_step.dart';

/// B22 · Avatar · Crop photo (590:29839): Move and scale. The photo fills
/// the 320 square at its smallest under the 260 circle; pinch zooms (up to
/// 4x) and drag moves it, never leaving the circle uncovered. Use photo
/// returns the circle's square as a 360 PNG; Choose another and Back go
/// back to the picker.
class AvatarPhotoScreen extends StatefulWidget {
  const AvatarPhotoScreen({super.key, required this.image});

  final Uint8List image;

  static const double frame = 320;
  static const double circle = 260;
  static const int output = 360;
  static const double maxZoom = 4;

  @override
  State<AvatarPhotoScreen> createState() => _AvatarPhotoScreenState();
}

class _AvatarPhotoScreenState extends State<AvatarPhotoScreen> {
  ui.Image? _image;
  double _zoom = 1;
  Offset _offset = Offset.zero;
  double _startZoom = 1;
  Offset _startOffset = Offset.zero;
  Offset _startFocal = Offset.zero;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _decode() async {
    final codec = await ui.instantiateImageCodec(widget.image);
    final frame = await codec.getNextFrame();
    codec.dispose();
    if (!mounted) {
      frame.image.dispose();
      return;
    }
    setState(() => _image = frame.image);
  }

  /// Logical pixels per image pixel at zoom 1: the short side spans the
  /// circle.
  double _base(ui.Image image) =>
      AvatarPhotoScreen.circle / math.min(image.width, image.height);

  Size _shown(ui.Image image) =>
      Size(image.width.toDouble(), image.height.toDouble()) *
      (_base(image) * _zoom);

  Offset _clamp(ui.Image image, Offset offset) {
    final shown = _shown(image);
    final dx = (shown.width - AvatarPhotoScreen.circle) / 2;
    final dy = (shown.height - AvatarPhotoScreen.circle) / 2;
    return Offset(offset.dx.clamp(-dx, dx), offset.dy.clamp(-dy, dy));
  }

  void _start(ScaleStartDetails details) {
    _startZoom = _zoom;
    _startOffset = _offset;
    _startFocal = details.localFocalPoint;
  }

  void _update(ScaleUpdateDetails details) {
    final image = _image;
    if (image == null) return;
    const centre = Offset(
      AvatarPhotoScreen.frame / 2,
      AvatarPhotoScreen.frame / 2,
    );
    final zoom = (_startZoom * details.scale).clamp(
      1.0,
      AvatarPhotoScreen.maxZoom,
    );
    final ratio = zoom / _startZoom;
    final pinned = _startFocal - (centre + _startOffset);
    final offset = details.localFocalPoint - pinned * ratio - centre;
    setState(() {
      _zoom = zoom;
      _offset = _clamp(image, offset);
    });
  }

  Future<void> _use() async {
    final image = _image;
    if (image == null || _busy) return;
    setState(() => _busy = true);
    final scale = _base(image) * _zoom;
    final shown = _shown(image);
    const inset = (AvatarPhotoScreen.frame - AvatarPhotoScreen.circle) / 2;
    final left = AvatarPhotoScreen.frame / 2 + _offset.dx - shown.width / 2;
    final top = AvatarPhotoScreen.frame / 2 + _offset.dy - shown.height / 2;
    final source = Rect.fromLTWH(
      (inset - left) / scale,
      (inset - top) / scale,
      AvatarPhotoScreen.circle / scale,
      AvatarPhotoScreen.circle / scale,
    );
    const size = AvatarPhotoScreen.output;
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(
      image,
      source,
      const Rect.fromLTWH(0, 0, size + 0.0, size + 0.0),
      Paint()..filterQuality = FilterQuality.high,
    );
    final picture = recorder.endRecording();
    final cropped = await picture.toImage(size, size);
    picture.dispose();
    final png = await cropped.toByteData(format: ui.ImageByteFormat.png);
    cropped.dispose();
    if (!mounted) return;
    context.pop(png?.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return AvatarStepScaffold(
      title: 'Your photo',
      heading: 'Move and scale',
      caption: 'Pinch to zoom and drag to put your face in the circle.',
      onBack: () => context.pop(),
      primary: 'Use photo',
      onPrimary: image == null ? null : _use,
      ghost: 'Choose another',
      onGhost: () => context.pop(),
      centre: Semantics(
        label: 'Your photo. Pinch to zoom and drag to move it.',
        child: GestureDetector(
          onScaleStart: _start,
          onScaleUpdate: _update,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: SizedBox.square(
              dimension: AvatarPhotoScreen.frame,
              child: Stack(
                children: [
                  if (image != null)
                    Positioned.fromRect(
                      rect: Rect.fromCenter(
                        center:
                            const Offset(
                              AvatarPhotoScreen.frame / 2,
                              AvatarPhotoScreen.frame / 2,
                            ) +
                            _offset,
                        width: _shown(image).width,
                        height: _shown(image).height,
                      ),
                      child: RawImage(
                        image: image,
                        fit: BoxFit.fill,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  const Positioned.fill(
                    child: CustomPaint(painter: _CircleShade()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The ink "shade" around the 260 circle and the paper ring inside its
/// edge.
class _CircleShade extends CustomPainter {
  const _CircleShade();

  @override
  void paint(Canvas canvas, Size size) {
    final circle = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: AvatarPhotoScreen.circle / 2,
    );
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addOval(circle),
      Paint()..color = IqColors.fg,
    );
    canvas.drawOval(
      circle.deflate(1.25),
      Paint()
        ..color = IqColors.bg
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_CircleShade old) => false;
}
