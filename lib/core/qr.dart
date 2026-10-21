import 'package:flutter/widgets.dart';

/// A QR code for a short link: byte mode, error correction M, versions 1
/// to 6 (up to 106 bytes), the mask with the lowest penalty. The tablet
/// draws one for "Continue on your phone"; it is encoded here so the
/// layouts ship without a new package.
class QrMatrix {
  QrMatrix._(this.size, this._dark);

  final int size;
  final List<bool> _dark;

  bool dark(int x, int y) => _dark[y * size + x];

  // Error correction codewords per block and blocks, for M (ISO 18004).
  static const _ecPerBlock = [10, 16, 26, 18, 24, 16];
  static const _blocks = [1, 1, 1, 2, 2, 4];
  static const _align = [
    <int>[],
    [6, 18],
    [6, 22],
    [6, 26],
    [6, 30],
    [6, 34],
  ];

  static int _rawModules(int v) {
    var n = (16 * v + 128) * v + 64;
    if (v >= 2) {
      final a = v ~/ 7 + 2;
      n -= (25 * a - 10) * a - 55;
    }
    return n;
  }

  static int _dataCodewords(int v) =>
      _rawModules(v) ~/ 8 - _ecPerBlock[v - 1] * _blocks[v - 1];

  /// Null when [text] is too long for version 6.
  static QrMatrix? encode(String text, {int? mask}) {
    final bytes = text.codeUnits.any((c) => c > 0x7f)
        ? Uri.encodeFull(text).codeUnits
        : text.codeUnits;
    var version = 0;
    for (var v = 1; v <= 6; v++) {
      if (bytes.length + 2 <= _dataCodewords(v)) {
        version = v;
        break;
      }
    }
    if (version == 0) return null;
    final capacity = _dataCodewords(version);
    final bits = <bool>[];
    void put(int value, int length) {
      for (var i = length - 1; i >= 0; i--) {
        bits.add((value >> i) & 1 == 1);
      }
    }

    put(4, 4);
    put(bytes.length, 8);
    for (final b in bytes) {
      put(b, 8);
    }
    final room = capacity * 8;
    put(0, (room - bits.length).clamp(0, 4));
    put(0, (8 - bits.length % 8) % 8);
    final data = <int>[
      for (var i = 0; i < bits.length; i += 8)
        bits
            .sublist(i, i + 8)
            .fold<int>(0, (acc, bit) => (acc << 1) | (bit ? 1 : 0)),
    ];
    for (var pad = 0xEC; data.length < capacity; pad ^= 0xEC ^ 0x11) {
      data.add(pad);
    }

    final blocks = _blocks[version - 1];
    final per = capacity ~/ blocks;
    final ec = _ecPerBlock[version - 1];
    final divisor = _divisor(ec);
    final dataBlocks = [
      for (var b = 0; b < blocks; b++) data.sublist(b * per, (b + 1) * per),
    ];
    final ecBlocks = [for (final d in dataBlocks) _remainder(d, divisor)];
    final codewords = <int>[
      for (var i = 0; i < per; i++)
        for (final d in dataBlocks) d[i],
      for (var i = 0; i < ec; i++)
        for (final e in ecBlocks) e[i],
    ];

    final qr = _Builder(version);
    qr.functionPatterns(_align[version - 1]);
    qr.place(codewords);
    var best = mask ?? 0;
    if (mask == null) {
      var lowest = -1;
      for (var m = 0; m < 8; m++) {
        qr.applyMask(m);
        qr.format(m);
        final score = qr.penalty();
        if (lowest < 0 || score < lowest) {
          lowest = score;
          best = m;
        }
        qr.applyMask(m);
      }
    }
    qr.applyMask(best);
    qr.format(best);
    return QrMatrix._(qr.size, qr.modules);
  }

  static int _mul(int x, int y) {
    var z = 0;
    for (var i = 7; i >= 0; i--) {
      z = (z << 1) ^ ((z >> 7) * 0x11D);
      z ^= ((y >> i) & 1) * x;
    }
    return z & 0xFF;
  }

  static List<int> _divisor(int degree) {
    final result = List<int>.filled(degree, 0)..[degree - 1] = 1;
    var root = 1;
    for (var i = 0; i < degree; i++) {
      for (var j = 0; j < degree; j++) {
        result[j] = _mul(result[j], root);
        if (j + 1 < degree) result[j] ^= result[j + 1];
      }
      root = _mul(root, 0x02);
    }
    return result;
  }

  static List<int> _remainder(List<int> data, List<int> divisor) {
    final result = List<int>.filled(divisor.length, 0, growable: true);
    for (final b in data) {
      final factor = b ^ result.removeAt(0);
      result.add(0);
      for (var i = 0; i < result.length; i++) {
        result[i] ^= _mul(divisor[i], factor);
      }
    }
    return result;
  }
}

class _Builder {
  _Builder(int version)
    : size = version * 4 + 17,
      modules = List<bool>.filled(
        (version * 4 + 17) * (version * 4 + 17),
        false,
      ),
      reserved = List<bool>.filled(
        (version * 4 + 17) * (version * 4 + 17),
        false,
      );

  final int size;
  final List<bool> modules;
  final List<bool> reserved;

  void _set(int x, int y, bool dark) {
    modules[y * size + x] = dark;
    reserved[y * size + x] = true;
  }

  void functionPatterns(List<int> align) {
    for (var i = 0; i < size; i++) {
      _set(6, i, i.isEven);
      _set(i, 6, i.isEven);
    }
    for (final (cx, cy) in [(3, 3), (size - 4, 3), (3, size - 4)]) {
      for (var dy = -4; dy <= 4; dy++) {
        for (var dx = -4; dx <= 4; dx++) {
          final x = cx + dx, y = cy + dy;
          if (x < 0 || y < 0 || x >= size || y >= size) continue;
          final d = dx.abs() > dy.abs() ? dx.abs() : dy.abs();
          _set(x, y, d != 2 && d != 4);
        }
      }
    }
    final n = align.length;
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < n; j++) {
        if ((i == 0 && j == 0) ||
            (i == 0 && j == n - 1) ||
            (i == n - 1 && j == 0)) {
          continue;
        }
        for (var dy = -2; dy <= 2; dy++) {
          for (var dx = -2; dx <= 2; dx++) {
            final d = dx.abs() > dy.abs() ? dx.abs() : dy.abs();
            _set(align[i] + dx, align[j] + dy, d != 1);
          }
        }
      }
    }
    format(0);
  }

  void format(int mask) {
    final data = mask;
    var rem = data;
    for (var i = 0; i < 10; i++) {
      rem = (rem << 1) ^ ((rem >> 9) * 0x537);
    }
    final bits = (data << 10 | rem) ^ 0x5412;
    bool bit(int i) => (bits >> i) & 1 == 1;
    for (var i = 0; i <= 5; i++) {
      _set(8, i, bit(i));
    }
    _set(8, 7, bit(6));
    _set(8, 8, bit(7));
    _set(7, 8, bit(8));
    for (var i = 9; i < 15; i++) {
      _set(14 - i, 8, bit(i));
    }
    for (var i = 0; i < 8; i++) {
      _set(size - 1 - i, 8, bit(i));
    }
    for (var i = 8; i < 15; i++) {
      _set(8, size - 15 + i, bit(i));
    }
    _set(8, size - 8, true);
  }

  void place(List<int> codewords) {
    var i = 0;
    final total = codewords.length * 8;
    for (var right = size - 1; right >= 1; right -= 2) {
      if (right == 6) right = 5;
      for (var vert = 0; vert < size; vert++) {
        for (var j = 0; j < 2; j++) {
          final x = right - j;
          final upward = ((right + 1) & 2) == 0;
          final y = upward ? size - 1 - vert : vert;
          if (!reserved[y * size + x] && i < total) {
            modules[y * size + x] =
                (codewords[i >> 3] >> (7 - (i & 7))) & 1 == 1;
            i++;
          }
        }
      }
    }
  }

  void applyMask(int mask) {
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        if (reserved[y * size + x]) continue;
        final flip = switch (mask) {
          0 => (x + y) % 2 == 0,
          1 => y % 2 == 0,
          2 => x % 3 == 0,
          3 => (x + y) % 3 == 0,
          4 => (x ~/ 3 + y ~/ 2) % 2 == 0,
          5 => x * y % 2 + x * y % 3 == 0,
          6 => (x * y % 2 + x * y % 3) % 2 == 0,
          _ => ((x + y) % 2 + x * y % 3) % 2 == 0,
        };
        if (flip) modules[y * size + x] = !modules[y * size + x];
      }
    }
  }

  int penalty() {
    bool at(int x, int y) => modules[y * size + x];
    var score = 0;
    for (final row in [true, false]) {
      for (var a = 0; a < size; a++) {
        var run = 1;
        for (var b = 1; b <= size; b++) {
          final same =
              b < size &&
              (row ? at(b, a) == at(b - 1, a) : at(a, b) == at(a, b - 1));
          if (same) {
            run++;
          } else {
            if (run >= 5) score += run - 2;
            run = 1;
          }
        }
        for (var b = 0; b + 11 <= size; b++) {
          final line = [
            for (var k = 0; k < 11; k++) row ? at(b + k, a) : at(a, b + k),
          ];
          const p1 = [1, 0, 1, 1, 1, 0, 1, 0, 0, 0, 0];
          const p2 = [0, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1];
          bool matches(List<int> p) =>
              [for (var k = 0; k < 11; k++) line[k] == (p[k] == 1)]
                  .every((m) => m);
          if (matches(p1)) score += 40;
          if (matches(p2)) score += 40;
        }
      }
    }
    var dark = 0;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        if (at(x, y)) dark++;
        if (x + 1 < size &&
            y + 1 < size &&
            at(x, y) == at(x + 1, y) &&
            at(x, y) == at(x, y + 1) &&
            at(x, y) == at(x + 1, y + 1)) {
          score += 3;
        }
      }
    }
    final total = size * size;
    final k = ((dark * 20 - total * 10).abs() + total - 1) ~/ total - 1;
    return score + k * 10;
  }
}

/// [data] drawn as a QR code [size] across in [color], or nothing when it
/// is too long to encode.
class QrCode extends StatelessWidget {
  const QrCode({
    super.key,
    required this.data,
    required this.color,
    this.size = 96,
    this.semanticLabel,
  });

  final String data;
  final Color color;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final matrix = QrMatrix.encode(data);
    if (matrix == null) return SizedBox.square(dimension: size);
    return Semantics(
      image: true,
      label: semanticLabel,
      child: CustomPaint(
        size: Size.square(size),
        painter: _QrPainter(matrix, color),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.matrix, this.color);

  final QrMatrix matrix;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / matrix.size;
    final paint = Paint()
      ..color = color
      ..isAntiAlias = false;
    final path = Path();
    for (var y = 0; y < matrix.size; y++) {
      for (var x = 0; x < matrix.size; x++) {
        if (matrix.dark(x, y)) {
          path.addRect(Rect.fromLTWH(x * cell, y * cell, cell, cell));
        }
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_QrPainter old) =>
      old.matrix != matrix || old.color != color;
}
