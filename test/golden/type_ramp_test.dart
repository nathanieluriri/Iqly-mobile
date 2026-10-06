import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/theme/theme.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('type ramp renders with the bundled fonts', (tester) async {
    await expectGolden(
      tester,
      'type_ramp',
      Scaffold(
        backgroundColor: IqColors.bg,
        body: Padding(
          padding: const EdgeInsets.all(IqSpace.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Three quick steps, Adaeze', style: IqText.display),
              const Text(
                'The arena for bold African thinkers.',
                style: IqText.headline,
              ),
              const Text('What do you do?', style: IqText.title),
              const Text(
                'A tagline for a solar kiosk network',
                style: IqText.cardTitle,
              ),
              const Text('₦12,500', style: IqText.figure),
              const Text('₦150,000', style: IqText.figureSmall),
              const Text(
                'Kiosks charge phones and sell airtime off-grid.',
                style: IqText.body,
              ),
              const Text('Verified: ADAEZE OKAFOR', style: IqText.bodyStrong),
              const Text('At least 8 characters', style: IqText.small),
              const Text('Closes in 6h', style: IqText.smallStrong),
              const Text('Discover', style: IqText.label),
              Text('Reward pool'.toUpperCase(), style: IqText.mono),
              const Text('Continue with email', style: IqText.button),
            ],
          ),
        ),
      ),
    );
  });
}
