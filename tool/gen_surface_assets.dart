import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Converts the official SVGs the OS surfaces need into Android vector
/// drawables, iOS asset catalog images and the launcher icons. Paths and
/// colours are used as they are, only scaled and placed; nothing is
/// redrawn. Run `dart run tool/gen_surface_assets.dart`, or with `--check`
/// to fail when an output is stale. The notification small icon needs
/// boolean path operations, so tool/gen_status_icon.py makes it.
const _res = 'android/app/src/main/res/drawable';
const _catalog = 'ios/Runner/Assets.xcassets';
const _extensionCatalog = 'ios/IqlySurfaces/Assets.xcassets';
const _anydpi = 'android/app/src/main/res/mipmap-anydpi-v26';
const _shortcutAnydpi = 'android/app/src/main/res/drawable-anydpi-v26';
const _appIcon = '$_catalog/AppIcon.appiconset';

const _shortcuts = {
  'ic_shortcut_polls': 'assets/icons/polls.svg',
  'ic_shortcut_forward': 'assets/icons/forward.svg',
  'ic_shortcut_submissions': 'assets/icons/submissions.svg',
};

const _logomark = 'assets/brand/iqly-logomark.svg';

/// The legacy launcher icons, 48dp at each density.
const _legacyDensities = {
  'mdpi': 48,
  'hdpi': 72,
  'xhdpi': 96,
  'xxhdpi': 144,
  'xxxhdpi': 192,
};

/// B19 350:17788 draws each shortcut as an fg glyph on a tint disc. Shipped
/// as adaptive icons, they look the same on every launcher and in both
/// themes; Launcher3 would otherwise wrap a bare glyph on a white disc.
const _shortcutInk = '@color/iq_fg';
const _shortcutDisc = '@color/iq_tint';
const _shortcutGlyph = 20 / 32;

void main(List<String> args) {
  final outputs = <String, Object>{};
  for (final MapEntry(key: name, value: svg) in _shortcuts.entries) {
    final source = File(svg).readAsStringSync();
    outputs['$_res/$name.xml'] = _vector(source, fill: _shortcutInk);
    outputs['$_res/${name}_foreground.xml'] = _shortcutForeground(source);
    outputs['$_shortcutAnydpi/$name.xml'] = _shortcutIcon(name);
    outputs['$_catalog/$name.imageset/${svg.split('/').last}'] = source;
    outputs['$_catalog/$name.imageset/Contents.json'] = _contents(
      svg.split('/').last,
    );
  }
  final mark = File(_logomark).readAsStringSync();
  outputs['$_res/iq_logomark.xml'] = _logomarkVector(mark);
  outputs['$_res/ic_launcher_background.xml'] = _launcherBackground(mark);
  outputs['$_res/ic_launcher_foreground.xml'] = _launcherForeground(mark);
  for (final name in ['ic_launcher', 'ic_launcher_round']) {
    outputs['$_anydpi/$name.xml'] = _adaptiveIcon;
  }
  final icon = _LauncherIcon(mark);
  for (final MapEntry(key: density, value: px) in _legacyDensities.entries) {
    final folder = 'android/app/src/main/res/mipmap-$density';
    outputs['$folder/ic_launcher.png'] = icon.png(px, shape: icon.tile);
    outputs['$folder/ic_launcher_round.png'] = icon.png(px, shape: _circle);
  }
  final appIcon = jsonDecode(
    File('$_appIcon/Contents.json').readAsStringSync(),
  );
  for (final image in (appIcon['images'] as List).cast<Map>()) {
    final points = double.parse((image['size'] as String).split('x').first);
    final scale = int.parse((image['scale'] as String).replaceAll('x', ''));
    outputs['$_appIcon/${image['filename']}'] = icon.png(
      (points * scale).round(),
    );
  }
  outputs['$_extensionCatalog/Contents.json'] = _json({
    'info': {'author': 'xcode', 'version': 1},
  });
  outputs['$_extensionCatalog/WidgetLogomark.imageset/iqly-logomark.svg'] =
      mark;
  outputs['$_extensionCatalog/WidgetLogomark.imageset/Contents.json'] =
      _contents('iqly-logomark.svg', template: false);

  final stale = [
    for (final MapEntry(key: path, value: content) in outputs.entries)
      if (!_current(path, content)) path,
  ];
  if (args.contains('--check')) {
    if (stale.isNotEmpty) {
      stderr.writeln('${stale.join(', ')} out of date');
      exitCode = 1;
    }
    return;
  }
  for (final path in stale) {
    final file = File(path)..createSync(recursive: true);
    switch (outputs[path]) {
      case final String text:
        file.writeAsStringSync(text);
      case final _Png png:
        file.writeAsBytesSync(png.encode());
    }
    stdout.writeln('wrote $path');
  }
}

/// A PNG is current when its pixels are: zlib does not compress the same
/// bytes the same way on every machine.
bool _current(String path, Object content) {
  final file = File(path);
  if (!file.existsSync()) return false;
  return switch (content) {
    final String text => file.readAsStringSync() == text,
    final _Png png => png.matches(_Png.decode(file.readAsBytesSync())),
    _ => false,
  };
}

class _Path {
  _Path(this.d, this.fill, this.evenOdd);

  final String d;
  final String fill;
  final bool evenOdd;
}

final _pathTag = RegExp(r'<path\b([^>]*)/?>');

String? _attr(String attrs, String name) =>
    RegExp('\\b$name="([^"]*)"').firstMatch(attrs)?.group(1);

List<_Path> _paths(String svg) => [
  for (final m in _pathTag.allMatches(svg))
    _Path(
      _attr(m[1]!, 'd')!,
      _attr(m[1]!, 'fill') ?? '#000000',
      _attr(m[1]!, 'fill-rule') == 'evenodd',
    ),
];

String _viewBox(String svg) => _attr(svg, 'viewBox')!;

double _width(String svg) => double.parse(_viewBox(svg).split(' ')[2]);

String _header(String svg, {required int dp}) {
  final box = _viewBox(svg).split(' ');
  return '<?xml version="1.0" encoding="utf-8"?>\n'
      '<!-- Generated by tool/gen_surface_assets.dart. Do not edit by hand. -->\n'
      '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
      '    android:width="${dp}dp"\n'
      '    android:height="${dp}dp"\n'
      '    android:viewportWidth="${box[2]}"\n'
      '    android:viewportHeight="${box[3]}">\n';
}

String _pathXml(_Path p, {String? fill, String indent = '    '}) =>
    '$indent<path\n'
    '$indent    android:fillColor="${fill ?? p.fill}"\n'
    '${p.evenOdd ? '$indent    android:fillType="evenOdd"\n' : ''}'
    '$indent    android:pathData="${p.d}" />\n';

String _vector(String svg, {String? fill}) {
  final b = StringBuffer(_header(svg, dp: 24));
  for (final p in _paths(svg)) {
    b.write(_pathXml(p, fill: fill));
  }
  b.write('</vector>\n');
  return b.toString();
}

/// The whole mark in its own colours, for the widget header.
String _logomarkVector(String svg) {
  final paths = _paths(svg);
  final b = StringBuffer(_header(svg, dp: 24))
    ..write('    <group>\n')
    ..write('        <clip-path android:pathData="${paths.first.d}" />\n');
  for (final p in paths.skip(1)) {
    b.write(_pathXml(p, indent: '        '));
  }
  b
    ..write('    </group>\n')
    ..write('</vector>\n');
  return b.toString();
}

/// The launcher icon is the store icon (1882:69205, 1882:69216), where the
/// B18 and B19 frames still draw the small tile on white (owner, 21 Oct).
/// The mark's purple fills the adaptive background layer; the foreground
/// holds the bulb and the swoosh with the mark's square on the 72dp
/// visible area, so the bulb sits inside the 66dp safe zone and the swoosh
/// runs out to the mask's edge as it runs out to the store icon's.
const _visible = 72.0;
const _canvas = 108.0;

String _launcherBackground(String svg) {
  final [_, background, ...] = _paths(svg);
  return _layer(
    scale: _canvas / _width(svg),
    offset: 0,
    body: _pathXml(background, indent: '        '),
  );
}

String _launcherForeground(String svg) {
  final [mask, _, ...art] = _paths(svg);
  return _layer(
    scale: _visible / _width(svg),
    offset: (_canvas - _visible) / 2,
    body: [
      '        <clip-path android:pathData="${mask.d}" />\n',
      for (final p in art) _pathXml(p, indent: '        '),
    ].join(),
  );
}

String _layer({
  required double scale,
  required double offset,
  required String body,
}) =>
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<!-- Generated by tool/gen_surface_assets.dart. Do not edit by hand. -->\n'
    '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
    '    android:width="108dp"\n'
    '    android:height="108dp"\n'
    '    android:viewportWidth="108"\n'
    '    android:viewportHeight="108">\n'
    '    <group\n'
    '        android:scaleX="${_fixed(scale)}"\n'
    '        android:scaleY="${_fixed(scale)}"\n'
    '        android:translateX="${_fixed(offset)}"\n'
    '        android:translateY="${_fixed(offset)}">\n'
    '$body'
    '    </group>\n'
    '</vector>\n';

String _shortcutForeground(String svg) {
  final size = _visible * _shortcutGlyph;
  final offset = (_canvas - size) / 2;
  final scale = size / double.parse(_viewBox(svg).split(' ')[2]);
  final b = StringBuffer()
    ..write('<?xml version="1.0" encoding="utf-8"?>\n')
    ..write(
      '<!-- Generated by tool/gen_surface_assets.dart. Do not edit by hand. -->\n',
    )
    ..write(
      '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n',
    )
    ..write('    android:width="108dp"\n')
    ..write('    android:height="108dp"\n')
    ..write('    android:viewportWidth="108"\n')
    ..write('    android:viewportHeight="108">\n')
    ..write('    <group\n')
    ..write('        android:scaleX="${_fixed(scale)}"\n')
    ..write('        android:scaleY="${_fixed(scale)}"\n')
    ..write('        android:translateX="${_fixed(offset)}"\n')
    ..write('        android:translateY="${_fixed(offset)}">\n');
  for (final p in _paths(svg)) {
    b.write(_pathXml(p, fill: _shortcutInk, indent: '        '));
  }
  b
    ..write('    </group>\n')
    ..write('</vector>\n');
  return b.toString();
}

String _shortcutIcon(String name) =>
    '''<?xml version="1.0" encoding="utf-8"?>
<!-- Generated by tool/gen_surface_assets.dart. Do not edit by hand. -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="$_shortcutDisc" />
    <foreground android:drawable="@drawable/${name}_foreground" />
</adaptive-icon>
''';

String _fixed(double v) => double.parse(v.toStringAsFixed(5)).toString();

const _adaptiveIcon = '''<?xml version="1.0" encoding="utf-8"?>
<!-- Generated by tool/gen_surface_assets.dart. Do not edit by hand. -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
</adaptive-icon>
''';

String _contents(String file, {bool template = true}) => _json({
  'images': [
    {'filename': file, 'idiom': 'universal'},
  ],
  'info': {'author': 'xcode', 'version': 1},
  'properties': {
    'preserves-vector-representation': true,
    if (template) 'template-rendering-intent': 'template',
  },
});

String _json(Object value) =>
    '${const JsonEncoder.withIndent('  ').convert(value)}\n';

/// The round legacy icon's disc, in the mark's 1000 units.
const _circle =
    'M500 0C776.142 0 1000 223.858 1000 500C1000 776.142 776.142 1000 500 '
    '1000C223.858 1000 0 776.142 0 500C0 223.858 223.858 0 500 0Z';

/// The store icon in pixels: the whole mark full size over its own purple,
/// square and opaque for iOS, which rounds it; cut to [shape] for the
/// legacy Android launchers, which show the image as it is.
class _LauncherIcon {
  _LauncherIcon(String svg) : _all = _paths(svg), _units = _width(svg);

  final List<_Path> _all;
  final double _units;

  String get tile => _all.first.d;

  _Png png(int size, {String? shape}) {
    final [mask, background, ...] = _all;
    final scale = size / _units;
    final icon = _Layer(size)..fill(null, background.fill);
    final mark = _Layer(size);
    for (final p in _all.skip(1)) {
      mark.fill(_coverage(p.d, p.evenOdd, size, scale), p.fill);
    }
    mark.clip(_coverage(mask.d, mask.evenOdd, size, scale));
    icon.over(mark);
    if (shape != null) icon.clip(_coverage(shape, false, size, scale));
    return _Png(size, icon.rgb(alpha: shape != null), alpha: shape != null);
  }
}

class _Point {
  const _Point(this.x, this.y);

  final double x;
  final double y;
}

final _token = RegExp(r'[A-Za-z]|-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?');

/// [d] as closed polygons, each curve cut into enough straight pieces to
/// stay within a twentieth of a pixel of it at [scale].
List<List<_Point>> _polygons(String d, double scale) {
  final tokens = [for (final m in _token.allMatches(d)) m[0]!];
  final polygons = <List<_Point>>[];
  var polygon = <_Point>[];
  var i = 0;
  var command = '';
  var x = 0.0, y = 0.0, startX = 0.0, startY = 0.0;
  double next() => double.parse(tokens[i++]);
  void close() {
    if (polygon.length > 2) polygons.add(polygon);
  }

  while (i < tokens.length) {
    if (RegExp('[A-Za-z]').hasMatch(tokens[i])) command = tokens[i++];
    final relative = command == command.toLowerCase();
    final ox = relative ? x : 0.0, oy = relative ? y : 0.0;
    switch (command.toUpperCase()) {
      case 'M':
        close();
        x = startX = ox + next();
        y = startY = oy + next();
        polygon = [_Point(x, y)];
        command = relative ? 'l' : 'L';
      case 'L':
        x = ox + next();
        y = oy + next();
        polygon.add(_Point(x, y));
      case 'H':
        x = ox + next();
        polygon.add(_Point(x, y));
      case 'V':
        y = oy + next();
        polygon.add(_Point(x, y));
      case 'C':
        final (x1, y1) = (ox + next(), oy + next());
        final (x2, y2) = (ox + next(), oy + next());
        final (x3, y3) = (ox + next(), oy + next());
        final bendX = math.max(
          (x - 2 * x1 + x2).abs(),
          (x1 - 2 * x2 + x3).abs(),
        );
        final bendY = math.max(
          (y - 2 * y1 + y2).abs(),
          (y1 - 2 * y2 + y3).abs(),
        );
        final bend = math.sqrt(bendX * bendX + bendY * bendY) * scale;
        final pieces = math.max(1, math.sqrt(bend * 15).ceil());
        for (var k = 1; k <= pieces; k++) {
          final t = k / pieces, u = 1 - t;
          final a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t;
          final e = t * t * t;
          polygon.add(
            _Point(
              a * x + b * x1 + c * x2 + e * x3,
              a * y + b * y1 + c * y2 + e * y3,
            ),
          );
        }
        x = x3;
        y = y3;
      case 'Z':
        close();
        x = startX;
        y = startY;
        polygon = [_Point(x, y)];
        command = '';
      default:
        throw FormatException('Path data "$command" is not supported');
    }
  }
  close();
  return polygons;
}

/// Each pixel's share inside [d], from 16 samples down the pixel and the
/// exact span across it.
Float64List _coverage(String d, bool evenOdd, int size, double scale) {
  const samples = 16;
  final edges = <(double, double, double, double, int)>[];
  for (final polygon in _polygons(d, scale)) {
    for (var k = 0; k < polygon.length; k++) {
      final a = polygon[k], b = polygon[(k + 1) % polygon.length];
      final (ax, ay, bx, by) = (
        a.x * scale,
        a.y * scale,
        b.x * scale,
        b.y * scale,
      );
      if (ay < by) edges.add((ax, ay, bx, by, 1));
      if (ay > by) edges.add((bx, by, ax, ay, -1));
    }
  }
  edges.sort((a, b) => a.$2.compareTo(b.$2));
  final cover = Float64List(size * size);
  final active = <(double, double, double, double, int)>[];
  final crossings = <(double, int)>[];
  var waiting = 0;
  for (var row = 0; row < size; row++) {
    for (var s = 0; s < samples; s++) {
      final y = row + (s + 0.5) / samples;
      while (waiting < edges.length && edges[waiting].$2 <= y) {
        active.add(edges[waiting++]);
      }
      active.removeWhere((e) => e.$4 <= y);
      crossings
        ..clear()
        ..addAll([
          for (final (x0, y0, x1, y1, dir) in active)
            (x0 + (y - y0) * (x1 - x0) / (y1 - y0), dir),
        ])
        ..sort((a, b) => a.$1.compareTo(b.$1));
      var winding = 0;
      var from = 0.0;
      for (final (x, dir) in crossings) {
        final wasIn = evenOdd ? winding.isOdd : winding != 0;
        winding += dir;
        final isIn = evenOdd ? winding.isOdd : winding != 0;
        if (!wasIn && isIn) from = x;
        if (wasIn && !isIn) {
          _span(cover, row * size, size, from, x, 1 / samples);
        }
      }
    }
  }
  return cover;
}

void _span(
  Float64List cover,
  int row,
  int size,
  double from,
  double to,
  double weight,
) {
  final a = from.clamp(0.0, size.toDouble()),
      b = to.clamp(0.0, size.toDouble());
  if (b <= a) return;
  final first = a.floor(), last = b.floor();
  if (first == last) {
    cover[row + first] += (b - a) * weight;
    return;
  }
  cover[row + first] += (first + 1 - a) * weight;
  for (var x = first + 1; x < last; x++) {
    cover[row + x] += weight;
  }
  if (last < size) cover[row + last] += (b - last) * weight;
}

/// Premultiplied colour, 0 to 1 a channel.
class _Layer {
  _Layer(this.size) : _rgba = Float64List(size * size * 4);

  final int size;
  final Float64List _rgba;

  /// [colour] over what is here through [cover], or everywhere when null.
  void fill(Float64List? cover, String colour) {
    final value = int.parse(colour.substring(1), radix: 16);
    final rgb = [
      for (final shift in [16, 8, 0]) (value >> shift & 255) / 255,
    ];
    for (var i = 0; i < size * size; i++) {
      final a = cover == null ? 1.0 : cover[i].clamp(0.0, 1.0);
      if (a == 0) continue;
      for (var c = 0; c < 3; c++) {
        _rgba[i * 4 + c] = rgb[c] * a + _rgba[i * 4 + c] * (1 - a);
      }
      _rgba[i * 4 + 3] = a + _rgba[i * 4 + 3] * (1 - a);
    }
  }

  void clip(Float64List cover) {
    for (var i = 0; i < size * size; i++) {
      final a = cover[i].clamp(0.0, 1.0);
      for (var c = 0; c < 4; c++) {
        _rgba[i * 4 + c] *= a;
      }
    }
  }

  void over(_Layer top) {
    for (var i = 0; i < size * size; i++) {
      final k = 1 - top._rgba[i * 4 + 3];
      for (var c = 0; c < 4; c++) {
        _rgba[i * 4 + c] = top._rgba[i * 4 + c] + _rgba[i * 4 + c] * k;
      }
    }
  }

  Uint8List rgb({required bool alpha}) {
    final channels = alpha ? 4 : 3;
    final out = Uint8List(size * size * channels);
    int byte(double v) => (v.clamp(0.0, 1.0) * 255 + 0.5).floor();
    for (var i = 0; i < size * size; i++) {
      final a = _rgba[i * 4 + 3];
      for (var c = 0; c < 3; c++) {
        final v = _rgba[i * 4 + c];
        out[i * channels + c] = byte(alpha ? (a == 0 ? 0 : v / a) : v);
      }
      if (alpha) out[i * channels + 3] = byte(a);
    }
    return out;
  }
}

/// An 8-bit square PNG, RGB or RGBA.
class _Png {
  _Png(this.size, this.pixels, {required this.alpha});

  final int size;
  final Uint8List pixels;
  final bool alpha;

  int get _channels => alpha ? 4 : 3;

  /// Within two levels a channel, so float rounding on another machine
  /// does not read as stale.
  bool matches(_Png? other) {
    if (other == null ||
        other.size != size ||
        other.alpha != alpha ||
        other.pixels.length != pixels.length) {
      return false;
    }
    for (var i = 0; i < pixels.length; i++) {
      if ((pixels[i] - other.pixels[i]).abs() > 2) return false;
    }
    return true;
  }

  Uint8List encode() {
    final stride = size * _channels;
    final rows = BytesBuilder();
    for (var y = 0; y < size; y++) {
      // Each row takes the filter that leaves the smallest bytes.
      var best = (0, Uint8List(0), 1 << 62);
      for (var type = 0; type < 5; type++) {
        final filtered = Uint8List(stride);
        var cost = 0;
        for (var x = 0; x < stride; x++) {
          final v =
              (pixels[y * stride + x] - _predict(type, y, x, stride)) & 255;
          filtered[x] = v;
          cost += v < 128 ? v : 256 - v;
        }
        if (cost < best.$3) best = (type, filtered, cost);
      }
      rows
        ..addByte(best.$1)
        ..add(best.$2);
    }
    final out = BytesBuilder()..add(const [137, 80, 78, 71, 13, 10, 26, 10]);
    void chunk(String type, List<int> data) {
      final body = [...type.codeUnits, ...data];
      out
        ..add(_u32(data.length))
        ..add(body)
        ..add(_u32(_crc(body)));
    }

    chunk('IHDR', [..._u32(size), ..._u32(size), 8, alpha ? 6 : 2, 0, 0, 0]);
    chunk('IDAT', ZLibCodec(level: 9).encode(rows.takeBytes()));
    chunk('IEND', const []);
    return out.takeBytes();
  }

  int _predict(int type, int y, int x, int stride) {
    final left = x >= _channels ? pixels[y * stride + x - _channels] : 0;
    final up = y > 0 ? pixels[(y - 1) * stride + x] : 0;
    final corner = x >= _channels && y > 0
        ? pixels[(y - 1) * stride + x - _channels]
        : 0;
    return _predictor(type, left, up, corner);
  }

  /// A square 8-bit RGB or RGBA PNG; null for anything else.
  static _Png? decode(Uint8List bytes) {
    try {
      return _decode(bytes);
    } on FormatException {
      return null;
    } on RangeError {
      return null;
    }
  }

  static _Png? _decode(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    var at = 8;
    int? size, colourType;
    final idat = BytesBuilder();
    while (at + 8 <= bytes.length) {
      final length = data.getUint32(at);
      final type = String.fromCharCodes(bytes, at + 4, at + 8);
      final body = at + 8;
      if (type == 'IHDR') {
        final width = data.getUint32(body), height = data.getUint32(body + 4);
        if (width != height || bytes[body + 8] != 8 || bytes[body + 12] != 0) {
          return null;
        }
        size = width;
        colourType = bytes[body + 9];
      }
      if (type == 'IDAT') idat.add(bytes.sublist(body, body + length));
      at = body + length + 4;
    }
    if (size == null || (colourType != 2 && colourType != 6)) return null;
    final channels = colourType == 6 ? 4 : 3;
    final stride = size * channels;
    final rows = zlib.decode(idat.takeBytes());
    if (rows.length != size * (stride + 1)) return null;
    final pixels = Uint8List(size * stride);
    for (var y = 0; y < size; y++) {
      final type = rows[y * (stride + 1)];
      for (var x = 0; x < stride; x++) {
        final left = x >= channels ? pixels[y * stride + x - channels] : 0;
        final up = y > 0 ? pixels[(y - 1) * stride + x] : 0;
        final corner = x >= channels && y > 0
            ? pixels[(y - 1) * stride + x - channels]
            : 0;
        pixels[y * stride + x] =
            (rows[y * (stride + 1) + 1 + x] +
                _predictor(type, left, up, corner)) &
            255;
      }
    }
    return _Png(size, pixels, alpha: channels == 4);
  }
}

int _predictor(int type, int left, int up, int corner) => switch (type) {
  1 => left,
  2 => up,
  3 => (left + up) >> 1,
  4 => _paeth(left, up, corner),
  _ => 0,
};

int _paeth(int left, int up, int corner) {
  final p = left + up - corner;
  final (a, b, c) = ((p - left).abs(), (p - up).abs(), (p - corner).abs());
  return a <= b && a <= c ? left : (b <= c ? up : corner);
}

List<int> _u32(int v) => [v >> 24 & 255, v >> 16 & 255, v >> 8 & 255, v & 255];

final _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = c & 1 == 1 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc(List<int> bytes) =>
    bytes.fold(0xFFFFFFFF, (c, b) => _crcTable[(c ^ b) & 255] ^ (c >> 8)) ^
    0xFFFFFFFF;
