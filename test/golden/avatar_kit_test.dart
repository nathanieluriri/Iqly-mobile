import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/avatar.dart';
import 'package:iqly_mobile/ui/avatar_choice.dart';
import 'package:iqly_mobile/ui/avatar_option_tile.dart';
import 'package:iqly_mobile/ui/avatar_part_tab.dart';
import 'package:iqly_mobile/ui/avatar_sheet.dart';
import 'package:iqly_mobile/ui/avatar_swatch.dart';
import 'package:iqly_mobile/ui/icon.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('avatar_part_tab', (tester) async {
    await expectComponentGolden(
      tester,
      'avatar_part_tab',
      const Row(
        children: [
          IqAvatarPartTab(),
          SizedBox(width: 24),
          IqAvatarPartTab(state: IqAvatarPartTabState.selected),
        ],
      ),
      size: const Size(136, 48),
    );
  });

  testWidgets('avatar_swatch', (tester) async {
    await expectComponentGolden(
      tester,
      'avatar_swatch',
      Row(
        children: [
          IqAvatarSwatch(colour: IqAvatarColors.skin[2]),
          const SizedBox(width: 24),
          IqAvatarSwatch(
            colour: IqAvatarColors.skin[2],
            state: IqAvatarSwatchState.selected,
          ),
        ],
      ),
      size: const Size(120, 48),
    );
  });

  testWidgets('avatar_option_tile', (tester) async {
    await expectComponentGolden(
      tester,
      'avatar_option_tile',
      const Row(
        children: [
          IqAvatarOptionTile(),
          SizedBox(width: 24),
          IqAvatarOptionTile(state: IqAvatarOptionTileState.selected),
          SizedBox(width: 24),
          IqAvatarOptionTile(none: true),
        ],
      ),
      size: const Size(348, 100),
    );
  });

  testWidgets('avatar_choice', (tester) async {
    await expectComponentGolden(
      tester,
      'avatar_choice',
      const Row(
        children: [
          IqAvatarChoice(avatar: IqPersonAvatar(IqAvatarPresets.person1)),
          SizedBox(width: 24),
          IqAvatarChoice(
            avatar: IqPersonAvatar(IqAvatarPresets.person1),
            state: IqAvatarChoiceState.selected,
          ),
          SizedBox(width: 24),
          IqAvatarChoice(kind: IqAvatarChoiceKind.create),
          SizedBox(width: 24),
          IqAvatarChoice(
            kind: IqAvatarChoiceKind.emoji,
            state: IqAvatarChoiceState.selected,
          ),
        ],
      ),
      size: const Size(375, 82),
    );
  });

  testWidgets('avatar_sheet', (tester) async {
    await expectComponentGolden(
      tester,
      'avatar_sheet',
      const SizedBox(
        width: 390,
        height: 735,
        child: IqAvatarSheet(current: IqPersonAvatar(IqAvatarPresets.person1)),
      ),
      size: const Size(390, 735),
      padding: 0,
      background: IqColors.panel,
    );
  });

  test('the editor tabs have their icons', () {
    expect(IqIcons.values, containsAll([IqIcons.skin, IqIcons.background]));
  });
}
