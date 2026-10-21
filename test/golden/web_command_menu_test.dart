import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/sample_logo.dart';
import 'package:iqly_mobile/ui/web_command_menu.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('results for a query', (tester) async {
    await expectComponentGolden(
      tester,
      'web_command_menu',
      IqWebCommandMenu(
        controller: TextEditingController(text: 'kiosk'),
        groups: const [
          IqWebCommandGroup(
            label: 'Briefs',
            results: [
              IqWebCommandResult(
                title: 'A tagline for a solar kiosk network',
                meta: 'Sunline · ₦150,000 · Closes in 6h',
                logo: IqSampleLogo(IqSampleLogoBrand.sunline),
              ),
            ],
          ),
          IqWebCommandGroup(
            label: 'Polls',
            results: [
              IqWebCommandResult(
                title: 'When should a kiosk open in the morning?',
                meta: 'Sunline · 1 question · Answered',
                logo: IqSampleLogo(IqSampleLogoBrand.sunline),
              ),
            ],
          ),
        ],
      ),
      size: const Size(640, 260),
    );
  });
}
