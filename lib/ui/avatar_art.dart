import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_parsing/path_parsing.dart';

import '../theme/theme.dart';

part 'avatar_art.g.dart';

/// A piece of Exp/Avatar part art, generated from the Figma exports in
/// design/avatar.
///
/// The art is painted here rather than through flutter_svg: the cheeks carry
/// a Figma layer blur that flutter_svg drops, and its pictures load a frame
/// late, which would blank a part as it pops in the editor.
sealed class AvatarNode {
  const AvatarNode();
}

/// One path from the export, filled from [slot]: a slot the avatar record
/// sets (skin, hair, cloth) or a fixed Avatar variable (brow, bg/2).
final class AvatarShape extends AvatarNode {
  const AvatarShape(
    this.d,
    this.slot, {
    this.evenOdd = false,
    this.opacity = 1,
  });

  final String d;
  final String slot;
  final bool evenOdd;
  final double opacity;
}

/// A Figma layer whose shapes paint as one: at an [opacity], inside a
/// [clip], or under a layer [blur] (an SVG standard deviation).
final class AvatarGroup extends AvatarNode {
  const AvatarGroup(
    this.children, {
    this.opacity = 1,
    this.clip,
    this.blur = 0,
  });

  final List<AvatarNode> children;
  final double opacity;
  final String? clip;
  final double blur;
}

/// Paints [layers] back to front on a [canvas] square scaled to the size,
/// each [scales] entry scaling its layer about [pivots] (the canvas centre
/// by default). [colours] fills the record's slots; the fixed variables come
/// from [IqAvatarColors.byName].
class AvatarArtPainter extends CustomPainter {
  AvatarArtPainter({
    required this.layers,
    this.colours = const {},
    this.canvas = 240,
    this.scales = const [],
    this.pivots = const [],
  });

  final List<List<AvatarNode>> layers;
  final Map<String, Color> colours;
  final double canvas;
  final List<double> scales;
  final List<Offset> pivots;

  static final _paths = <String, Path>{};

  static Path _path(String d, {bool evenOdd = false}) {
    return _paths.putIfAbsent(evenOdd ? 'e$d' : d, () {
      final path = Path()
        ..fillType = evenOdd ? PathFillType.evenOdd : PathFillType.nonZero;
      writeSvgPathDataToPath(d, _PathWriter(path));
      return path;
    });
  }

  /// The bounds of a path in the art, on its canvas.
  static Rect boundsOf(String d) => _path(d).getBounds();

  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.scale(size.width / canvas, size.height / canvas);
    for (final (i, layer) in layers.indexed) {
      final scale = i < scales.length ? scales[i] : 1.0;
      if (scale == 1) {
        _paint(c, layer, 0);
        continue;
      }
      final pivot = i < pivots.length
          ? pivots[i]
          : Offset(canvas / 2, canvas / 2);
      c.save();
      c.translate(pivot.dx, pivot.dy);
      c.scale(scale);
      c.translate(-pivot.dx, -pivot.dy);
      _paint(c, layer, 0);
      c.restore();
    }
    c.restore();
  }

  void _paint(Canvas c, List<AvatarNode> nodes, double blur) {
    for (final node in nodes) {
      switch (node) {
        case AvatarShape():
          final colour =
              colours[node.slot] ?? IqAvatarColors.byName[node.slot]!;
          final paint = Paint()
            ..color = colour.withValues(alpha: colour.a * node.opacity);
          if (blur > 0) {
            paint.maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
          }
          c.drawPath(_path(node.d, evenOdd: node.evenOdd), paint);
        case AvatarGroup():
          c.save();
          if (node.clip case final clip?) c.clipPath(_path(clip));
          if (node.opacity < 1) {
            c.saveLayer(
              null,
              Paint()..color = Color.fromRGBO(0, 0, 0, node.opacity),
            );
          }
          _paint(c, node.children, node.blur > 0 ? node.blur : blur);
          if (node.opacity < 1) c.restore();
          c.restore();
      }
    }
  }

  @override
  bool shouldRepaint(AvatarArtPainter old) =>
      !listEquals(old.layers, layers) ||
      !mapEquals(old.colours, colours) ||
      old.canvas != canvas ||
      !listEquals(old.scales, scales) ||
      !listEquals(old.pivots, pivots);
}

class _PathWriter extends PathProxy {
  _PathWriter(this.path);

  final Path path;

  @override
  void moveTo(double x, double y) => path.moveTo(x, y);

  @override
  void lineTo(double x, double y) => path.lineTo(x, y);

  @override
  void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) => path.cubicTo(x1, y1, x2, y2, x3, y3);

  @override
  void close() => path.close();
}
