import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/illustration.dart';

void main() {
  test('every illustration, figure and line art frame has its SVG', () {
    final assets = [
      ...IqIllustrations.values.map((i) => i.asset),
      ...IqFigures.values.map((f) => f.asset),
      ...IqLineArtFrames.values.map((f) => f.asset),
    ];
    final missing = assets.where((a) => !File(a).existsSync()).toList();
    expect(missing, isEmpty, reason: 'Export the missing art from Figma');
  });

  test('illustrations keep their ink and accent layers', () {
    for (final kind in IqIllustrations.values) {
      final svg = File(kind.asset).readAsStringSync();
      expect(svg, contains('id="ink"'), reason: kind.file);
      expect(svg, contains('id="accent"'), reason: kind.file);
    }
  });

  test('official marks are present and untouched in shape', () {
    for (final mark in [
      'apple-mark',
      'google-g',
      'share-whatsapp',
      'share-instagram',
      'share-x',
      'share-telegram',
    ]) {
      final file = File('assets/brand/$mark.svg');
      expect(file.existsSync(), isTrue, reason: mark);
      expect(file.readAsStringSync(), startsWith('<svg'), reason: mark);
    }
  });
}
