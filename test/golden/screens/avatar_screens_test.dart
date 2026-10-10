import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iqly_mobile/data/photo_service.dart';
import 'package:iqly_mobile/router.dart';

import '../golden.dart';
import 'app_harness.dart';
import 'more_harness.dart';

/// B22 · Avatar (row 22 of the app file), at 390 x 844 as the frames are.
Future<void> _golden(WidgetTester tester, String name) async {
  await precacheImages(tester);
  await tester.pumpAndSettle();
  await expectMatchesGolden(
    find.byType(MaterialApp),
    'goldens/avatar_$name.png',
  );
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _editor(WidgetTester tester) async {
  await pumpMore(tester, Routes.more);
  GoRouter.of(tester.element(find.byType(Navigator).first))
      .push(Routes.avatarEditor);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  group('B22 editor', () {
    for (final (node, tab) in [
      ('578:25922', 'Skin'),
      ('579:26022', 'Face'),
      ('579:26475', 'Hair'),
      ('581:26666', 'Facial hair'),
      ('581:26985', 'Glasses'),
      ('581:27263', 'Headwear'),
      ('581:27588', 'Clothes'),
      ('581:27889', 'Background'),
    ]) {
      testWidgets('$node $tab', (tester) async {
        await _editor(tester);
        await _tap(tester, find.bySemanticsLabel(tab));
        await _golden(
          tester,
          'editor_${tab.toLowerCase().replaceAll(' ', '_')}',
        );
      });
    }

    testWidgets('582:27615 Discard changes?', (tester) async {
      await _editor(tester);
      await _tap(tester, find.bySemanticsLabel('Hair'));
      await _tap(tester, find.bySemanticsLabel('High top'));
      await _tap(tester, find.bySemanticsLabel('Back'));
      await _golden(tester, 'discard');
    });
  });

  group('B22 picker', () {
    testWidgets('590:28885 Your profile · Choose avatar', (tester) async {
      await pumpMore(tester, Routes.profile);
      await _tap(tester, find.bySemanticsLabel('Change your avatar'));
      await _golden(tester, 'choose_profile');
    });

    testWidgets('590:29515 More · Choose avatar', (tester) async {
      await pumpMore(tester, Routes.more);
      await _tap(tester, find.bySemanticsLabel('Change your avatar'));
      await _golden(tester, 'choose_more');
    }, variant: ios);

    testWidgets('590:28810 Your profile · buddy', (tester) async {
      await pumpMore(
        tester,
        Routes.profile,
        prefs: {
          ...signedInPrefs(),
          'avatar.spec': '{"kind":"buddy","buddy":"Blob"}',
        },
      );
      await _golden(tester, 'profile_buddy');
    });

    testWidgets('590:29839 Crop photo', (tester) async {
      await pumpMore(
        tester,
        Routes.profile,
        overrides: [
          photoServiceProvider.overrideWithValue(
            DemoPhotoService(delay: Duration.zero),
          ),
        ],
      );
      await _tap(tester, find.bySemanticsLabel('Change your avatar'));
      await _tap(tester, find.text('Use a photo'));
      await tester.runAsync(() async {
        await tester.tap(find.text('Choose from your photos'));
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)),
      );
      await tester.pumpAndSettle();
      await _golden(tester, 'crop');
    });
  });

  testWidgets('582:28894 Onboarding · Your avatar', (tester) async {
    await pumpMore(
      tester,
      Routes.onboardingYourAvatar,
      prefs: signedInPrefs(onboardingDone: false, firstTipSeen: false),
    );
    await _golden(tester, 'onboarding');
  });
}
