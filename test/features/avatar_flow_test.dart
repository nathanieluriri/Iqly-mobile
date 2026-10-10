import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/photo_service.dart';
import 'package:iqly_mobile/features/avatar/avatar_editor_screen.dart';
import 'package:iqly_mobile/features/avatar/avatar_photo_screen.dart';
import 'package:iqly_mobile/features/avatar/avatar_state.dart';
import 'package:iqly_mobile/features/onboarding/your_avatar_screen.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/achievement_card.dart';
import 'package:iqly_mobile/ui/avatar.dart';
import 'package:iqly_mobile/ui/avatar_choice.dart';
import 'package:iqly_mobile/ui/avatar_sheet.dart';
import 'package:iqly_mobile/ui/top_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../golden/golden.dart' show loadAppFonts;
import '../golden/screens/app_harness.dart' show signedInPrefs;
import '../golden/screens/more_harness.dart';

String _path(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first)).state.uri.path;

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _back(WidgetTester tester) async {
  await _tap(tester, find.bySemanticsLabel('Back').last);
}

IqAvatarSpec _shown(WidgetTester tester) =>
    tester.widget<IqAvatar>(find.byType(IqAvatar).first).spec;

Finder _choice(String label) => find.byWidgetPredicate(
  (w) => w is IqAvatarChoice && w.semanticLabel == label,
);

void main() {
  setUpAll(loadAppFonts);

  testWidgets('the More card shows Person 1 for the sample account; its '
      'avatar opens the picker, and a buddy closes it and shows', (
    tester,
  ) async {
    final container = await pumpMore(tester, Routes.more);
    expect(
      tester.widget<IqAchievementCard>(find.byType(IqAchievementCard)).avatar,
      const IqPersonAvatar(IqAvatarPresets.person1),
    );
    await _tap(tester, find.bySemanticsLabel('Change your avatar'));
    expect(find.text('Choose your avatar'), findsOneWidget);
    expect(
      tester.widget<IqAvatarChoice>(_choice('Person 1')).state,
      IqAvatarChoiceState.selected,
    );

    await _tap(tester, _choice('Blob'));
    expect(find.byType(IqAvatarSheet), findsNothing);
    expect(_path(tester), Routes.more);
    expect(
      tester.widget<IqAchievementCard>(find.byType(IqAchievementCard)).avatar,
      const IqBuddyAvatar(IqAvatarBuddyKind.blob),
    );
    final prefs = container.read(sharedPreferencesProvider);
    expect(jsonDecode(prefs.getString('avatar.spec')!), {
      'kind': 'buddy',
      'buddy': 'Blob',
    });
  });

  testWidgets('tapping outside the picker closes it and keeps the avatar', (
    tester,
  ) async {
    await pumpMore(tester, Routes.profile);
    await _tap(tester, find.bySemanticsLabel('Change your avatar'));
    await tester.tapAt(const Offset(195, 60));
    await tester.pumpAndSettle();
    expect(find.byType(IqAvatarSheet), findsNothing);
    expect(_shown(tester), const IqPersonAvatar(IqAvatarPresets.person1));
  });

  testWidgets('Make your own opens the editor from the person; a new style '
      'saved shows on Your profile', (tester) async {
    await pumpMore(tester, Routes.profile);
    await _tap(tester, find.bySemanticsLabel('Change your avatar'));
    await _tap(tester, find.text('Make your own'));
    expect(find.byType(AvatarEditorScreen), findsOneWidget);
    expect(find.text('Skin tone'), findsOneWidget);

    await _tap(tester, find.bySemanticsLabel('Hair'));
    expect(find.text('Hair colour'), findsOneWidget);
    await _tap(tester, find.bySemanticsLabel('Afro'));
    await _tap(tester, find.text('Save avatar'));
    expect(_path(tester), Routes.profile);
    expect(
      _shown(tester),
      IqPersonAvatar(
        IqAvatarPresets.person1.copyWith(hairStyle: IqAvatarHairStyle.afro),
      ),
    );
  });

  testWidgets('Back with unsaved edits asks first: Keep editing stays, '
      'Discard leaves the avatar as it was', (tester) async {
    await pumpMore(tester, Routes.profile);
    await _tap(tester, find.bySemanticsLabel('Change your avatar'));
    await _tap(tester, find.text('Make your own'));
    await _tap(tester, find.bySemanticsLabel('Skin tone 9'));

    await _back(tester);
    expect(find.text('Discard changes?'), findsOneWidget);
    expect(
      find.text(
        'Your avatar edits won’t be saved. Your current avatar stays as it '
        'is.',
      ),
      findsOneWidget,
    );
    await _tap(tester, find.text('Keep editing'));
    expect(find.byType(AvatarEditorScreen), findsOneWidget);

    await _back(tester);
    await _tap(tester, find.text('Discard'));
    expect(_path(tester), Routes.profile);
    expect(_shown(tester), const IqPersonAvatar(IqAvatarPresets.person1));
  });

  testWidgets('Back with no edits leaves the editor at once', (tester) async {
    await pumpMore(tester, Routes.profile);
    GoRouter.of(tester.element(find.byType(Navigator).first))
        .push(Routes.avatarEditor);
    await tester.pumpAndSettle();
    await _back(tester);
    expect(find.text('Discard changes?'), findsNothing);
    expect(_path(tester), Routes.profile);
  });

  test('a swatch pops the parts it paints and nothing else', () {
    const look = IqAvatarPresets.person1;
    expect(changedParts(look, look.copyWith(skin: 9)), {
      IqAvatarPart.head,
      IqAvatarPart.face,
    });
    expect(changedParts(look, look.copyWith(cloth: 3)), {
      IqAvatarPart.hairBack,
      IqAvatarPart.body,
    });
    expect(changedParts(look, look.copyWith(bg: 4)), isEmpty);
    expect(
      changedParts(look, look.copyWith(glasses: IqAvatarGlassesStyle.round)),
      {IqAvatarPart.glasses},
    );
  });

  testWidgets('Use a photo: the library, Move and scale, Use photo; the photo '
      'shows and comes first in Avatars', (tester) async {
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
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.byType(AvatarPhotoScreen), findsOneWidget);
    expect(find.text('Move and scale'), findsOneWidget);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(find.text('Use photo'));
      await Future<void>.delayed(const Duration(milliseconds: 600));
    });
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(IqAvatarSheet), findsNothing);
    expect(_path(tester), Routes.profile);
    expect(_shown(tester), isA<IqPhotoAvatar>());

    await _tap(tester, find.bySemanticsLabel('Change your avatar'));
    expect(
      tester.widget<IqAvatarChoice>(find.byType(IqAvatarChoice).first).avatar,
      isA<IqPhotoAvatar>(),
    );
    expect(
      tester.widget<IqAvatarChoice>(_choice('Your photo')).state,
      IqAvatarChoiceState.selected,
    );
  });

  testWidgets('Choose another goes back to the picker', (tester) async {
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
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Choose another'));
    expect(find.byType(AvatarPhotoScreen), findsNothing);
    expect(find.text('Choose your avatar'), findsOneWidget);
  });

  testWidgets('onboarding Your avatar: Make it mine edits and comes back '
      'with the new look', (tester) async {
    await pumpMore(
      tester,
      Routes.onboardingYourAvatar,
      prefs: signedInPrefs(onboardingDone: false, firstTipSeen: false),
    );
    expect(find.byType(YourAvatarScreen), findsOneWidget);
    expect(
      find.text(
        'We made one to start. Make it look like you now, or later from More.',
      ),
      findsOneWidget,
    );
    await _tap(tester, find.text('Make it mine'));
    expect(find.byType(AvatarEditorScreen), findsOneWidget);
    await _tap(tester, find.bySemanticsLabel('Glasses'));
    await _tap(tester, find.bySemanticsLabel('Shades'));
    await _tap(tester, find.text('Save avatar'));
    expect(find.byType(YourAvatarScreen), findsOneWidget);
    expect(
      _shown(tester),
      IqPersonAvatar(
        IqAvatarPresets.person1.copyWith(glasses: IqAvatarGlassesStyle.shades),
      ),
    );
    expect(find.byType(IqTopBar), findsOneWidget);
  });

  test('a new account starts as one of the six people; sign out forgets '
      'the avatar', () async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          await _prefs({'avatar.spec': '{"kind":"buddy","buddy":"Moon"}'}),
        ),
      ],
    );
    addTearDown(container.dispose);
    final avatar = container.read(avatarProvider.notifier);
    expect(
      container.read(avatarProvider).spec,
      const IqBuddyAvatar(IqAvatarBuddyKind.moon),
    );
    await avatar.startNewcomer(Random(4));
    final spec = container.read(avatarProvider).spec;
    expect(spec, isA<IqPersonAvatar>());
    expect(IqAvatarPresets.people, contains((spec as IqPersonAvatar).look));
    await avatar.forget();
    expect(
      container.read(avatarProvider).spec,
      const IqPersonAvatar(IqAvatarPresets.person1),
    );
  });
}

Future<SharedPreferences> _prefs(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}
