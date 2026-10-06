import 'package:flutter/widgets.dart';

/// The vertical dashed tear line between a ticket and its stub (plain
/// geometry, not a brush shape). Fills the height it is given.
class IqPerforation extends StatelessWidget {
  const IqPerforation({
    super.key,
    required this.color,
    this.thickness = 1.5,
    this.dash = 4,
    this.gap = 5,
    this.roundCap = true,
  });

  final Color color;
  final double thickness;
  final double dash;
  final double gap;
  final bool roundCap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(thickness, double.infinity),
      painter: _PerforationPainter(this),
    );
  }
}

class _PerforationPainter extends CustomPainter {
  const _PerforationPainter(this.line);

  final IqPerforation line;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = line.color
      ..strokeWidth = line.thickness
      ..strokeCap = line.roundCap ? StrokeCap.round : StrokeCap.butt;
    final x = size.width / 2;
    for (var y = 0.0; y < size.height; y += line.dash + line.gap) {
      final end = (y + line.dash).clamp(0.0, size.height);
      canvas.drawLine(Offset(x, y), Offset(x, end), paint);
    }
  }

  @override
  bool shouldRepaint(_PerforationPainter old) =>
      old.line.color != line.color ||
      old.line.thickness != line.thickness ||
      old.line.dash != line.dash ||
      old.line.gap != line.gap;
}
