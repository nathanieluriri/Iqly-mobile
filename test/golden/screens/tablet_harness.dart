import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/repository.dart';

import '../golden.dart';
import 'app_harness.dart';

/// The tablet frames (Mobile App · tablet, 21 Oct): iPad 11 inch portrait
/// and landscape with the iPadOS status bar (24) and home indicator (20).
enum TabletFrameSize {
  portrait(Size(834, 1194)),
  landscape(Size(1194, 834)),
  androidPortrait(Size(800, 1280)),
  androidLandscape(Size(1280, 800)),
  mini(Size(744, 1133));

  const TabletFrameSize(this.size);

  final Size size;
}

/// Pumps the real router inside the tablet frame at [frame].
Future<ProviderContainer> pumpTablet(
  WidgetTester tester,
  String location, {
  TabletFrameSize frame = TabletFrameSize.portrait,
  IqlyRepository? repository,
  Map<String, Object>? prefs,
  List<Override> overrides = const [],
  bool settle = true,
}) => pumpApp(
  tester,
  location,
  repository: repository,
  prefs: prefs,
  overrides: overrides,
  settle: settle,
  size: frame.size,
  insets: const FakeViewPadding(top: 24, bottom: 20),
  tabletFrame: true,
);

/// Compares the whole window with `goldens/tablet_<name>.png`.
Future<void> expectTabletGolden(WidgetTester tester, String name) async {
  await precacheImages(tester);
  await expectMatchesGolden(
    find.byType(MaterialApp),
    'goldens/tablet_$name.png',
  );
}
