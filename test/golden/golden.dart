import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/theme/theme.dart';

/// The test engine only ships a placeholder font; load the bundled ones so
/// goldens show real type. Call from setUpAll.
Future<void> loadAppFonts() async {
  final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json'));
  for (final family in (manifest as List).cast<Map<String, dynamic>>()) {
    final loader = FontLoader(family['family'] as String);
    for (final font in (family['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

/// Compares [finder] with a golden painted with BoxShadow blur, as a device
/// paints it: flutter_test draws shadows without blur, which leaves a hard
/// band under the dock and cards. The flag is restored before the test ends,
/// as the test binding requires.
Future<void> expectMatchesGolden(Finder finder, String path) async {
  final binding = TestWidgetsFlutterBinding.instance;
  debugDisableShadows = false;
  try {
    void repaint(RenderObject object) {
      object.markNeedsPaint();
      object.visitChildren(repaint);
    }

    binding.renderViews.forEach(repaint);
    await binding.pump();
    await expectLater(finder, matchesGoldenFile(path));
  } finally {
    debugDisableShadows = true;
  }
}

/// Renders [child] on the app theme at [size] (the Figma frame by default)
/// and compares it with `test/golden/goldens/<name>.png`. Update with
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
  await precacheImages(tester);
  await expectMatchesGolden(find.byType(MaterialApp), 'goldens/$name.png');
}

/// Raster images decode off the fake clock, so a golden would catch them
/// blank; this decodes every [Image] on screen for real, then repaints.
Future<void> precacheImages(WidgetTester tester) async {
  final images = tester.widgetList<Image>(find.byType(Image)).toList();
  if (images.isEmpty) return;
  await tester.runAsync(() async {
    for (final image in images) {
      await precacheImage(image.image, tester.element(find.byWidget(image)));
    }
  });
  await tester.pumpAndSettle();
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
