import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/updates.dart';
import 'package:iqly_mobile/data/app_version.dart';
import 'package:iqly_mobile/features/splash/update_screen.dart';

import '../golden.dart';
import 'screen_golden.dart';

final _required = DemoAppVersionService(
  AppRelease(
    installed: '0.1.0+1',
    status: UpdateStatus.required,
    minimum: '0.2.0',
    latest: '0.2.0+4',
    updateUrl: Uri.parse(
      'https://staging.api.iqly.net/mobile/download/android',
    ),
  ),
);

void main() {
  setUpAll(loadAppFonts);

  testWidgets('time to update (1310:26448)', (tester) async {
    await expectScreenGolden(
      tester,
      'update_required',
      const UpdateScreen(),
      prefs: {'session.signedIn': true},
      overrides: [appVersionServiceProvider.overrideWithValue(_required)],
      prepare: (c) => c.read(updatesProvider.notifier).check(),
    );
  });

  testWidgets('time to update, signed out', (tester) async {
    await expectScreenGolden(
      tester,
      'update_required_signed_out',
      const UpdateScreen(),
      overrides: [appVersionServiceProvider.overrideWithValue(_required)],
      prepare: (c) => c.read(updatesProvider.notifier).check(),
    );
  });
}
