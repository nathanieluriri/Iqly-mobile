import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/router.dart';

import '../golden.dart';
import 'discover_harness.dart';
import 'tablet_harness.dart';

/// The rows the tablet keeps the app's own pages for, in the panel or full
/// screen before the shell: one golden per layout.
void main() {
  setUpAll(loadAppFonts);

  const signedIn = {
    'settings_details': Routes.yourDetails,
    'settings_points': Routes.pointsLeaderboard,
    'settings_referrals': Routes.referrals,
    'result': '/submissions/s2/result',
    'avatar': Routes.avatarEditor,
    'support': Routes.support,
    'help': Routes.helpCentre,
    'activation': '/activations/a2',
  };
  const signedOut = {
    'landing': Routes.landing,
    'sign_in': Routes.signIn,
    'onboarding': Routes.onboarding,
  };

  for (final frame in [TabletFrameSize.portrait, TabletFrameSize.landscape]) {
    for (final e in signedIn.entries) {
      testWidgets('${e.key}, ${frame.name}', (tester) async {
        await pumpTablet(
          tester,
          e.value,
          frame: frame,
          overrides: discoverOverrides(),
          settle: false,
        );
        await tester.pump(const Duration(seconds: 2));
        await tester.pump(const Duration(seconds: 2));
        await expectTabletGolden(tester, '${e.key}_${frame.name}');
      });
    }
    for (final e in signedOut.entries) {
      testWidgets('${e.key}, ${frame.name}', (tester) async {
        await pumpTablet(
          tester,
          e.value,
          frame: frame,
          prefs: const {},
          settle: false,
        );
        await tester.pump(const Duration(seconds: 2));
        await tester.pump(const Duration(seconds: 2));
        await expectTabletGolden(tester, '${e.key}_${frame.name}');
      });
    }
  }
}
