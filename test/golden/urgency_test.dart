import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/urgency.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final tone in IqUrgencyTone.values) {
    testWidgets('${tone.name} tone', (tester) async {
      await expectComponentGolden(
        tester,
        'urgency_${tone.name}',
        IqUrgency(tone: tone),
        size: const Size(113, 28),
      );
    });
  }

  test('tone follows the deadline ladder', () {
    expect(IqUrgencyTone.of(const Duration(hours: 6)), IqUrgencyTone.hot);
    expect(IqUrgencyTone.of(const Duration(days: 1)), IqUrgencyTone.warm);
    expect(IqUrgencyTone.of(const Duration(days: 25)), IqUrgencyTone.calm);
    expect(IqUrgencyTone.of(null), IqUrgencyTone.calm);
    expect(IqUrgencyTone.of(Duration.zero), IqUrgencyTone.closed);
    expect(
      IqUrgencyTone.of(const Duration(days: 3), closed: true),
      IqUrgencyTone.closed,
    );
  });
}
