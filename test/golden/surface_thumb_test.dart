import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/surfaces/surface_thumbs.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/sample_logo.dart';

import 'golden.dart';

/// The PNGs the Medium widget rows (347:16187) and the Android large icon
/// (350:17527) show, drawn at the logical size they are painted for.
void main() {
  setUpAll(loadAppFonts);

  testWidgets('surface_thumb', (tester) async {
    const brands = [
      IqSampleLogoBrand.sunline,
      IqSampleLogoBrand.kudiBox,
      IqSampleLogoBrand.orchidFoods,
      IqSampleLogoBrand.private,
    ];
    final pngs = await tester.runAsync(
      () => Future.wait([for (final b in brands) renderThumb(b)]),
    );
    expect(pngs, isNotNull);
    for (final png in pngs!) {
      expect(png.sublist(1, 4), Uint8List.fromList('PNG'.codeUnits));
    }
    await expectComponentGolden(
      tester,
      'surface_thumb',
      Container(
        color: IqColors.card,
        padding: const EdgeInsets.all(IqSpace.s2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: IqSpace.s3,
          children: [
            for (final png in pngs)
              Image.memory(
                png,
                width: SurfaceThumb.size,
                height: SurfaceThumb.size,
              ),
          ],
        ),
      ),
      size: const Size(
        4 * SurfaceThumb.size + 3 * IqSpace.s3 + 2 * IqSpace.s2,
        SurfaceThumb.size + 2 * IqSpace.s2,
      ),
    );
  });
}
