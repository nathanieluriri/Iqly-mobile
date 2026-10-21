import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/router.dart';

import '../golden.dart';
import 'app_harness.dart';
import 'discover_harness.dart';
import 'tablet_harness.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final frame in [
    TabletFrameSize.portrait,
    TabletFrameSize.landscape,
    TabletFrameSize.mini,
  ]) {
    testWidgets('T4 Discover For you, ${frame.name}', (tester) async {
      await pumpTablet(
        tester,
        Routes.home,
        frame: frame,
        overrides: discoverOverrides(),
      );
      await expectTabletGolden(tester, 'discover_for_you_${frame.name}');
    });
  }

  for (final frame in [TabletFrameSize.portrait, TabletFrameSize.landscape]) {
    testWidgets('T4 Discover filters open, ${frame.name}', (tester) async {
      await pumpTablet(
        tester,
        Routes.home,
        frame: frame,
        overrides: discoverOverrides(),
      );
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      await expectTabletGolden(tester, 'discover_filters_${frame.name}');
    });

    testWidgets('T4 Discover loading, ${frame.name}', (tester) async {
      await pumpTablet(
        tester,
        Routes.home,
        frame: frame,
        repository: ScriptedRepository(const [BriefsCall.hang]),
        overrides: discoverOverrides(),
        settle: false,
      );
      await tester.pump(const Duration(seconds: 1));
      await expectTabletGolden(tester, 'discover_loading_${frame.name}');
    });
  }

  for (final frame in [TabletFrameSize.portrait, TabletFrameSize.landscape]) {
    testWidgets('T5 Brief, ${frame.name}', (tester) async {
      await pumpTablet(
        tester,
        Routes.brief('c5'),
        frame: frame,
        overrides: discoverOverrides(),
      );
      await expectTabletGolden(tester, 'brief_${frame.name}');
    });
  }
}
