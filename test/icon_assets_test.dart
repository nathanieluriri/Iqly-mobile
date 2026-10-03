import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/icon.dart';

void main() {
  test('every icon in the enum has its exported SVG', () {
    final missing = IqIcons.values
        .where((icon) => !File(icon.asset).existsSync())
        .map((icon) => icon.name)
        .toList();
    expect(missing, isEmpty, reason: 'Export the missing icons from Figma');
  });

  test('every exported icon is in the enum', () {
    final names = IqIcons.values.map((i) => i.name).toSet();
    final extra = Directory('assets/icons')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((f) => f.endsWith('.svg'))
        .map((f) => f.substring(0, f.length - 4))
        .where((n) => !names.contains(n))
        .toList();
    expect(extra, isEmpty, reason: 'Add the icon to IqIcons');
  });
}
