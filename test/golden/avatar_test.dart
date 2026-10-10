import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/avatar.dart';
import 'package:iqly_mobile/ui/avatar_art.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('avatar_presets', (tester) async {
    await expectComponentGolden(
      tester,
      'avatar_presets',
      Wrap(
        spacing: 8,
        children: [
          for (final look in IqAvatarPresets.people)
            IqAvatar(IqPersonAvatar(look)),
        ],
      ),
      size: const Size(760, 120),
    );
  });

  testWidgets('avatar_buddies', (tester) async {
    await expectComponentGolden(
      tester,
      'avatar_buddies',
      Wrap(
        spacing: 8,
        children: [
          for (final kind in IqAvatarBuddyKind.values)
            IqAvatar(IqBuddyAvatar(kind)),
        ],
      ),
      size: const Size(1016, 120),
    );
  });

  testWidgets('avatar_character', (tester) async {
    await expectComponentGolden(
      tester,
      'avatar_character',
      const Row(
        children: [
          IqAvatarCharacter(look: IqAvatarLook()),
          SizedBox(width: 8),
          IqAvatarCharacter(
            look: IqAvatarLook(
              hairStyle: IqAvatarHairStyle.afro,
              headwear: IqAvatarHeadwearStyle.cap,
              glasses: IqAvatarGlassesStyle.shades,
              facialHair: IqAvatarFacialHairStyle.moustache,
              facialHairColour: 4,
              expression: IqAvatarExpression.wow,
              eye: 4,
              skin: 9,
              hair: 4,
              cloth: 6,
              bg: 12,
            ),
          ),
        ],
      ),
      size: const Size(488, 240),
    );
  });

  testWidgets('avatar_photo_placeholder', (tester) async {
    await expectComponentGolden(
      tester,
      'avatar_photo_placeholder',
      const IqAvatarPhoto(),
      size: const Size(120, 120),
    );
  });

  test('headwear hides the hair Figma says it hides', () {
    const afro = IqAvatarLook(hairStyle: IqAvatarHairStyle.afro);
    List<AvatarNode> part(IqAvatarLook look, IqAvatarPart part) =>
        look.layers[part.index];
    expect(part(afro, IqAvatarPart.hairBack), isNotEmpty);
    for (final (headwear, back, front) in [
      (IqAvatarHeadwearStyle.cap, false, true),
      (IqAvatarHeadwearStyle.kufi, false, true),
      (IqAvatarHeadwearStyle.beanie, false, false),
      (IqAvatarHeadwearStyle.gele, false, false),
    ]) {
      final look = afro.copyWith(headwear: headwear);
      expect(part(look, IqAvatarPart.hairBack).isNotEmpty, back);
      expect(part(look, IqAvatarPart.hairFront).isNotEmpty, front);
    }
  });

  test('the stored record round-trips in the designer doc shape', () {
    expect(IqAvatarPresets.person1.toJson(), {
      'skin': 4,
      'hair': 1,
      'eye': 1,
      'hairStyle': 'Puffs',
      'face': 'Smile',
      'facialHair': 'None',
      'facialHairColour': 1,
      'glasses': 'None',
      'headwear': 'None',
      'headwearColour': 1,
      'body': 'Kaftan',
      'cloth': 1,
      'bg': 1,
    });
    for (final spec in [
      const IqPersonAvatar(IqAvatarPresets.person4),
      const IqBuddyAvatar(IqAvatarBuddyKind.blob),
      const IqEmojiAvatar('😎'),
    ]) {
      expect(IqAvatarSpec.fromJson(spec.toJson()), spec);
    }
    expect(IqAvatarLook.fromJson({'skin': 11}), isNull);
  });

  test('every part variant has its Figma export', () {
    final bindings = File('design/avatar/bindings.json').readAsStringSync();
    for (final stem in [
      for (final s in IqAvatarHairStyle.values) 'hair-front-${_stem(s.figma)}',
      for (final e in IqAvatarExpression.values) 'face-${_stem(e.figma)}',
      for (final b in IqAvatarBodyStyle.values) 'body-${_stem(b.figma)}',
      for (final k in IqAvatarBuddyKind.values) 'buddy-${_stem(k.figma)}',
    ]) {
      expect(bindings, contains('"$stem"'), reason: stem);
    }
  });
}

String _stem(String figma) => figma.toLowerCase().replaceAll(' ', '-');
