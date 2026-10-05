import 'dart:ui';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/theme.dart';
import '../ui/sample_logo.dart';

/// The brief thumbnail of the Medium widget and the Android large icon: the
/// cover, rounded, with the business logo in a ringed badge at its corner.
/// RemoteViews and WidgetKit cannot draw the SVG logos, so the app paints
/// the thumbnail once and hands over a PNG.
abstract final class SurfaceThumb {
  static const cover = 44.0;
  static const badge = 16.0;
  static const ring = 2.0;
  static const overhang = 5.0;
  static const size = cover + overhang;
  static const scale = 3.0;

  /// Exp/Widget rows round the cover at 12, Exp/AndroidNotification at 10.
  static const widgetRadius = 12.0;
  static const notificationRadius = 10.0;
}

Future<Uint8List> renderThumb(
  IqSampleLogoBrand brand, {
  double radius = SurfaceThumb.widgetRadius,
  AssetBundle? bundle,
  double scale = SurfaceThumb.scale,
}) async {
  final assets = bundle ?? rootBundle;
  final coverBytes = await assets.load(brand.cover());
  final codec = await ui.instantiateImageCodec(coverBytes.buffer.asUint8List());
  final coverImage = (await codec.getNextFrame()).image;
  final logo = await vg.loadPicture(
    SvgAssetLoader(brand.logo, assetBundle: assets),
    null,
  );

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)..scale(scale);
  const c = SurfaceThumb.cover;
  canvas
    ..save()
    ..clipRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, c, c),
        Radius.circular(radius),
      ),
    )
    ..drawImageRect(
      coverImage,
      _centerSquare(coverImage.width, coverImage.height),
      const Rect.fromLTWH(0, 0, c, c),
      Paint()..filterQuality = FilterQuality.high,
    )
    ..restore();

  const b = SurfaceThumb.badge;
  const center = Offset(
    SurfaceThumb.size - SurfaceThumb.ring - b / 2,
    SurfaceThumb.size - SurfaceThumb.ring - b / 2,
  );
  canvas
    ..drawCircle(
      center,
      b / 2 + SurfaceThumb.ring,
      Paint()..color = IqColors.card,
    )
    ..save()
    ..clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: b / 2)))
    ..translate(center.dx - b / 2, center.dy - b / 2)
    ..scale(b / logo.size.width, b / logo.size.height)
    ..drawPicture(logo.picture)
    ..restore();

  final picture = recorder.endRecording();
  final px = (SurfaceThumb.size * scale).round();
  final image = await picture.toImage(px, px);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  image.dispose();
  coverImage.dispose();
  logo.picture.dispose();
  return data!.buffer.asUint8List();
}

Rect _centerSquare(int w, int h) {
  final side = w < h ? w : h;
  return Rect.fromLTWH(
    (w - side) / 2,
    (h - side) / 2,
    side.toDouble(),
    side.toDouble(),
  );
}
