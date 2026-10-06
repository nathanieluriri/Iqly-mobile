import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/media_service.dart';
import 'package:iqly_mobile/features/activations/activation_screen.dart';
import 'package:iqly_mobile/features/activations/activations_screen.dart';
import 'package:iqly_mobile/features/activations/proof_player_screen.dart';
import 'package:iqly_mobile/features/activations/proof_screen.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/ui/proof_tile.dart';

import '../harness.dart';
import '../steps.dart';

/// A returning contributor finishes Kudi Box: Discover's Activations See
/// all, My activations (the one under way opens straight), Upload
/// proof of step 2 with the photos prompt allowed, the recording played
/// back, Send proof, the check, and the reward.
void main() {
  film('activations_proof', prefs: returning, media: DemoMediaService(), (
    d,
  ) async {
    await onDiscover(d, hold: 1.2);
    await d.tap(
      find.text('Rate 3 recipes in the Orchid Foods app'),
      label: 'activations-card',
    );
    await d.arrive(find.byType(ActivationsScreen), hold: 0);
    final mine = find.text('My activations');
    await d.waitFor(mine);
    await d.hold(1.5);
    await revealAndTap(
      d,
      mine,
      find.byType(ActivationsScreen),
      label: 'my-activations',
    );

    await d.arrive(find.byType(ActivationScreen), hold: 1.5);
    await d.tap(button('Upload proof of step 2'), label: 'upload-proof');

    await d.arrive(find.byType(ProofScreen), hold: 1);
    await d.tap(find.byType(IqProofTile), label: 'proof-tile');
    await d.waitFor(find.text('Allow Full Access'));
    await d.settle(on: find.text('Allow Full Access'));
    await d.hold(1.2);
    await d.tap(find.text('Allow Full Access'));
    await d.waitFor(find.textContaining('uploaded, ready to send'));
    await d.hold(1.2);
    await d.tap(find.bySemanticsLabel('Play'), label: 'play');

    await d.arrive(find.byType(ProofPlayerScreen), hold: 1.5);
    await d.back();

    await d.arrive(find.byType(ProofScreen), hold: 0.6);
    await d.tap(button('Send proof'), label: 'send-proof');

    await d.waitFor(find.text('Your proof'));
    await d.settle(on: find.byType(ActivationScreen));
    await d.hold(1.5);
    await d.tap(find.text('Checking with Kudi Box').last, label: 'checking');
    await d.waitFor(find.text('₦1,500.00 is yours'));
    await d.settle(on: find.byType(ActivationScreen));
    await d.hold(2);
    await d.back();
    await d.arrive(find.byType(ActivationsScreen), hold: 1);
    await d.back();
    await d.arrive(find.byType(HomeScreen), hold: 1.5);
  });
}
