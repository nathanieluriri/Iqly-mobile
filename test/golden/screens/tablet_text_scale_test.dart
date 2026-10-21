import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/router.dart';

import '../golden.dart';
import 'discover_harness.dart';
import 'tablet_harness.dart';

/// Every tablet page at text scale 1.3 on the 11 inch in both layouts and
/// on the mini: no RenderFlex may overflow.
void main() {
  setUpAll(loadAppFonts);

  final signedIn = [
    Routes.home,
    Routes.brief('c5'),
    Routes.submitTo('c5'),
    Routes.submissions,
    '/submissions/s2',
    '/submissions/s2/result',
    Routes.polls,
    Routes.activations,
    '/activations/a2',
    '/activations/a2/proof',
    Routes.wallet,
    '/wallet/withdrawals/w1',
    Routes.notifications,
    Routes.yourDetails,
    Routes.referrals,
    Routes.pointsLeaderboard,
    Routes.more,
    Routes.support,
    '/help/t1',
    Routes.helpCentre,
    Routes.avatarEditor,
  ];
  final signedOut = [
    Routes.landing,
    Routes.signIn,
    Routes.yourName,
    Routes.createPassword,
    Routes.onboarding,
    Routes.onboardingAboutYou,
  ];
  const frames = [
    TabletFrameSize.portrait,
    TabletFrameSize.landscape,
    TabletFrameSize.mini,
  ];

  for (final frame in frames) {
    for (final (location, out) in [
      for (final l in signedIn) (l, false),
      for (final l in signedOut) (l, true),
    ]) {
      testWidgets('$location at 1.3, ${frame.name}', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final overflows = <String>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (details) {
          final text = details.exceptionAsString();
          if (text.contains('overflowed')) {
            overflows.add(
              '${text.split('\n').first} at '
              '${details.informationCollector?.call().take(2).join(' ')}',
            );
          } else {
            previous?.call(details);
          }
        };
        try {
          await pumpTablet(
            tester,
            location,
            frame: frame,
            overrides: discoverOverrides(),
            prefs: out ? const {} : null,
            settle: false,
          );
          await tester.pump(const Duration(seconds: 2));
          await tester.pump(const Duration(seconds: 2));
        } finally {
          FlutterError.onError = previous;
        }
        expect(overflows, isEmpty, reason: overflows.join('\n'));
      });
    }
  }
}
