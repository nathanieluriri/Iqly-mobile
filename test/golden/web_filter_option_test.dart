import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/web_filter_option.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final type in IqWebFilterOptionType.values) {
    for (final on in [false, true]) {
      testWidgets('${type.name} ${on ? 'on' : 'off'}', (tester) async {
        await expectComponentGolden(
          tester,
          'web_filter_option_${type.name}_${on ? 'on' : 'off'}',
          SizedBox(
            width: 224,
            child: IqWebFilterOption(
              label: 'Any time',
              type: type,
              on: on,
              count: '11',
            ),
          ),
          size: const Size(224, 44),
        );
      });
    }
  }
}
