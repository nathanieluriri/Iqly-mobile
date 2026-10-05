import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/sample_avatar.dart';
import 'package:iqly_mobile/ui/sample_cover.dart';
import 'package:iqly_mobile/ui/sample_logo.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('sample_logo', (tester) async {
    await expectComponentGolden(
      tester,
      'sample_logo',
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final brand in IqSampleLogoBrand.values)
            IqSampleLogo(brand, size: 60),
        ],
      ),
      size: const Size(406, 128),
    );
  });

  testWidgets('sample_cover', (tester) async {
    await expectComponentGolden(
      tester,
      'sample_cover',
      const SizedBox(
        width: 320,
        height: 200,
        child: IqSampleCover(IqSampleLogoBrand.sunline),
      ),
      size: const Size(320, 200),
    );
  });

  testWidgets('sample_avatar', (tester) async {
    await expectComponentGolden(
      tester,
      'sample_avatar',
      Row(
        children: [
          for (final person in IqSampleAvatarPerson.values)
            IqSampleAvatar(person: person, size: 60),
        ],
      ),
      size: const Size(360, 60),
    );
  });

  test('every sample asset exists', () {
    for (final brand in IqSampleLogoBrand.values) {
      expect(File(brand.logo).existsSync(), isTrue, reason: brand.logo);
      for (var shot = 1; shot <= brand.shots; shot++) {
        expect(File(brand.cover(shot)).existsSync(), isTrue);
      }
    }
    for (final person in IqSampleAvatarPerson.values) {
      expect(File(person.asset).existsSync(), isTrue, reason: person.asset);
    }
  });
}
