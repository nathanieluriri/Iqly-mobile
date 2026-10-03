import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/theme/theme.dart';

const _fontFiles = {
  IqFonts.bricolage: [
    'BricolageGrotesque-Medium.ttf',
    'BricolageGrotesque-Bold.ttf',
    'BricolageGrotesque-ExtraBold.ttf',
  ],
  IqFonts.jakarta: [
    'PlusJakartaSans-Regular.ttf',
    'PlusJakartaSans-Medium.ttf',
    'PlusJakartaSans-SemiBold.ttf',
    'PlusJakartaSans-Bold.ttf',
  ],
  IqFonts.geistMono: [
    'GeistMono-Regular.ttf',
    'GeistMono-Medium.ttf',
    'GeistMono-SemiBold.ttf',
  ],
};

/// The test engine only ships a placeholder font; load the bundled ones so
/// goldens show real type. Call from setUpAll.
Future<void> loadAppFonts() async {
  for (final entry in _fontFiles.entries) {
    final loader = FontLoader(entry.key);
    for (final file in entry.value) {
      loader.addFont(rootBundle.load('assets/fonts/$file'));
    }
    await loader.load();
  }
}

/// Renders [child] on the app theme at [size] (the Figma frame by default)
/// and compares it with test/golden/goldens/<name>.png. Update with
/// `flutter test --update-goldens test/golden`.
Future<void> expectGolden(
  WidgetTester tester,
  String name,
  Widget child, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      debugShowCheckedModeBanner: false,
      home: child,
    ),
  );
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );
}

/// Renders a component on the paper background at its own size, padded.
Future<void> expectComponentGolden(
  WidgetTester tester,
  String name,
  Widget child, {
  required Size size,
  Color background = IqColors.bg,
  double padding = IqSpace.s4,
}) {
  return expectGolden(
    tester,
    name,
    Scaffold(
      backgroundColor: background,
      body: Padding(
        padding: EdgeInsets.all(padding),
        child: Align(alignment: Alignment.topLeft, child: child),
      ),
    ),
    size: Size(size.width + padding * 2, size.height + padding * 2),
  );
}
