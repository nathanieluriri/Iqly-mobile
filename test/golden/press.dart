import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/pressable.dart';

/// Same frame as expectComponentGolden, captured while a finger is held on
/// [target] (the first IqPressable by default), so the Pressed variant shows.
Future<void> expectPressedComponentGolden(
  WidgetTester tester,
  String name,
  Widget child, {
  required Size size,
  Finder? target,
  Color background = IqColors.bg,
  double padding = IqSpace.s4,
}) async {
  tester.view.physicalSize = Size(
    size.width + padding * 2,
    size.height + padding * 2,
  );
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: background,
        body: Padding(
          padding: EdgeInsets.all(padding),
          child: Align(alignment: Alignment.topLeft, child: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final gesture = await tester.startGesture(
    tester.getCenter(target ?? find.byType(IqPressable).first),
  );
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );
  await gesture.up();
  await tester.pumpAndSettle();
}

/// Wraps [child] so its looping animations hold still for a golden.
Widget stillMotion(Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child,
  ),
);
