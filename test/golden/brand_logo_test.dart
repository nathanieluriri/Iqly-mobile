import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/brand_logo.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  test('only the fill inside alpha masks turns white', () {
    const svg =
        '<svg><mask id="m" style="mask-type:alpha"><path d="M0 0" fill="#2C0062"/></mask>'
        '<g mask="url(#m)"><path d="M1 1" fill="#2D0048"/></g></svg>';
    expect(
      alphaMasksAsLuminance(svg),
      '<svg><mask id="m" style="mask-type:alpha"><path d="M0 0" fill="#FFFFFF"/></mask>'
      '<g mask="url(#m)"><path d="M1 1" fill="#2D0048"/></g></svg>',
    );
  });

  test('the official logo files are untouched', () {
    for (final name in [
      'iqly-logo',
      'iqly-logo-cream',
      'iqly-logomark',
      'iqly-logomark-cream',
    ]) {
      final svg = File('assets/brand/$name.svg').readAsStringSync();
      expect(svg, contains('mask-type:alpha'), reason: name);
      expect(svg, isNot(contains('fill="#FFFFFF"')), reason: name);
    }
  });

  testWidgets('logo and logomark in both tones', (tester) async {
    await expectComponentGolden(
      tester,
      'brand_logo',
      const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IqBrandLogo(width: 120),
          SizedBox(height: IqSpace.s4),
          IqBrandLogo(mark: IqBrandMark.logomark, width: 48),
          SizedBox(height: IqSpace.s4),
          ColoredBox(
            color: IqColors.brandDark,
            child: Padding(
              padding: EdgeInsets.all(IqSpace.s3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IqBrandLogo(tone: IqBrandTone.onDark, width: 120),
                  SizedBox(width: IqSpace.s4),
                  IqBrandLogo(
                    mark: IqBrandMark.logomark,
                    tone: IqBrandTone.onDark,
                    width: 48,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      size: const Size(240, 200),
    );
  });
}
