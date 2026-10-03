import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every font family the tokens name ships with the app', () async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    final shipped = {for (final f in manifest) f['family'] as String};
    final tokens = File('lib/theme/tokens.g.dart').readAsStringSync();
    final named = RegExp(
      r"static const \w+ = '([^']+)';",
    ).allMatches(tokens.split('abstract final class IqFonts')[1].split('}')[0]);
    expect(named, isNotEmpty);
    for (final match in named) {
      expect(shipped, contains(match[1]));
    }
  });
}
