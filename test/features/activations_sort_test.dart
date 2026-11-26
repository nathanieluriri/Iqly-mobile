import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/activations_data.dart';
import 'package:iqly_mobile/features/activations/activations_state.dart';

import '../golden/screens/app_harness.dart';

Activation _activation(
  String id, {
  required DateTime? closesAt,
  required int rewardKobo,
}) {
  return Activation(
    id: id,
    business: id,
    title: id,
    minutes: 5,
    rewardKobo: rewardKobo,
    closesAt: closesAt,
    spotsLeft: 10,
    spotsTotal: 20,
    steps: const [DemoActivations.signUp],
    link: Uri.parse('https://example.com'),
  );
}

void main() {
  test(
    'sorts open activations by soonest close, latest close, then reward',
    () {
      final soon = _activation(
        'soon',
        closesAt: figmaNow.add(const Duration(hours: 2)),
        rewardKobo: 50000,
      );
      final mid = _activation(
        'mid',
        closesAt: figmaNow.add(const Duration(days: 1)),
        rewardKobo: 80000,
      );
      final far = _activation(
        'far',
        closesAt: figmaNow.add(const Duration(days: 4)),
        rewardKobo: 150000,
      );
      final openEnded = _activation(
        'open-ended',
        closesAt: null,
        rewardKobo: 200000,
      );
      final mixed = [far, soon, mid, openEnded];
      expect(
        sortActivationTiles(mixed, ActivationListSort.closing).map((a) => a.id),
        ['soon', 'mid', 'far', 'open-ended'],
      );
      expect(
        sortActivationTiles(mixed, ActivationListSort.latest).map((a) => a.id),
        ['far', 'mid', 'soon', 'open-ended'],
      );
      expect(
        sortActivationTiles(mixed, ActivationListSort.reward).map((a) => a.id),
        ['open-ended', 'far', 'mid', 'soon'],
      );
    },
  );
}
