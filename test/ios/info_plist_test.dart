import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Runner Info.plist names why location APIs are linked', () {
    final text = File('ios/Runner/Info.plist').readAsStringSync();
    expect(text, contains('<key>NSLocationWhenInUseUsageDescription</key>'));
  });
}
