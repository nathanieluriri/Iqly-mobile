import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/activations/activation_screen.dart';
import 'package:iqly_mobile/features/activations/activations_screen.dart';
import 'package:iqly_mobile/features/activations/proof_player_screen.dart';
import 'package:iqly_mobile/features/activations/proof_screen.dart';
import 'package:iqly_mobile/ui/proof_tile.dart';
import 'package:iqly_mobile/ui/video_preview.dart';

import '../harness.dart';
import '../steps.dart';

/// A returning contributor signs in and opens Activations from Discover,
/// then My activations, which opens Kudi Box, their one activation. Its step 2 went unconfirmed past a day, so
/// they upload proof: the tile becomes the recording as it uploads, the
/// preview player opens from its play sticker, Send proof hands back to the
/// activation, and a tap on the Checking row brings the reward.
void main() {
  film('activations_proof', (d) async {
    await signIn(d);

    await d.tap(find.text('Activations'));
    await d.arrive(find.byType(ActivationsScreen), hold: 0);
    final mine = find.text('My activations');
    await d.waitFor(mine);
    await d.hold(1.2);
    await d.reveal(mine, listIn(find.byType(ActivationsScreen)));
    await d.hold(0.5);
    await d.tap(mine, label: 'my-activations');

    await d.arrive(find.byType(ActivationScreen), hold: 1.2);
    await d.tap(find.text('Upload proof of step 2'));

    await d.arrive(find.byType(ProofScreen), hold: 1);
    await d.tap(find.byType(IqProofTile), label: 'proof-tile');
    await d.waitFor(find.textContaining('uploaded, ready to send'));
    await d.hold(1);
    await d.tap(find.bySemanticsLabel('Play'), label: 'play');

    await d.arrive(find.byType(ProofPlayerScreen), hold: 1.2);
    await d.back();

    await d.arrive(find.byType(ProofScreen), hold: 0.6);
    await d.tap(find.text('Send proof'));

    await d.waitFor(find.text('Not credited yet?'));
    await d.settle(on: find.byType(ActivationScreen));
    await d.hold(1.2);
    // The Checking row asks for the latest state (the prototype's advance),
    // so the reward lands now rather than after the demo's 4 s.
    await d.tap(find.text('Checking with Kudi Box').last);
    await d.waitFor(find.text('₦1,500.00 is yours'));
    await d.settle(on: find.byType(ActivationScreen));
    await d.hold(1.5);
    expect(find.byType(IqVideoPreview), findsNothing);
  });
}
