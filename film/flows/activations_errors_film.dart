import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/activations_service.dart';
import 'package:iqly_mobile/data/media_service.dart';
import 'package:iqly_mobile/features/activations/activation_screen.dart';
import 'package:iqly_mobile/features/activations/activations_screen.dart';
import 'package:iqly_mobile/features/activations/proof_screen.dart';
import 'package:iqly_mobile/ui/proof_tile.dart';

import '../harness.dart';
import '../steps.dart';

/// The proof upload when things go wrong: photos refused, then allowed; a
/// recording over a minute refused and another picked with Retry; an upload
/// that fails and goes in on Retry; and proof Kudi Box does not accept,
/// recorded again and accepted.
void main() {
  final media = DemoMediaService(video: DemoMediaService.tooLong);
  film(
    'activations_errors',
    prefs: returning,
    media: media,
    activations: (now) =>
        DemoActivationsService(clock: now, uploadFailures: 1, refusals: 1),
    (d) async {
      await onDiscover(d, hold: 1.5);
      await d.tap(
        find.text('Rate 3 recipes in the Orchid Foods app').first,
        label: 'activations-card',
      );
      await d.arrive(find.byType(ActivationsScreen), hold: 0);
      final mine = find.text('My activations');
      await d.waitFor(mine);
      await d.hold(1);
      await revealAndTap(
        d,
        mine,
        find.byType(ActivationsScreen),
        label: 'my-activations',
      );
      await d.arrive(find.byType(ActivationScreen), hold: 1);
      await d.tap(button('Upload proof of step 2'), label: 'upload-proof');

      await d.arrive(find.byType(ProofScreen), hold: 1);
      await d.tap(find.byType(IqProofTile), label: 'proof-tile');
      await d.waitFor(find.text('Don’t Allow'));
      await d.settle(on: find.text('Don’t Allow'));
      await d.hold(1.2);
      await d.tap(find.text('Don’t Allow'), label: 'dont-allow');
      await d.hold(1.5);
      await d.tap(find.byType(IqProofTile), label: 'proof-tile');
      await d.waitFor(find.text('Allow Full Access'));
      await d.settle(on: find.text('Allow Full Access'));
      await d.hold(0.8);
      await d.tap(find.text('Allow Full Access'));
      await d.waitFor(find.textContaining('1:42'));
      await d.hold(2.5);

      media.video = DemoMediaService.sample;
      await d.tap(find.text('Retry'), label: 'retry-too-long');
      await d.waitFor(find.textContaining('Upload failed'));
      await d.hold(2.5);
      await d.tap(find.text('Retry'), label: 'retry-upload');
      await d.waitFor(find.textContaining('uploaded, ready to send'));
      await d.hold(1.2);
      await d.tap(button('Send proof'), label: 'send-proof');

      await d.waitFor(find.textContaining('Proof not accepted'));
      await d.settle(on: find.byType(ActivationScreen));
      await d.hold(3);
      await d.tap(find.text('Record again'), label: 'record-again');
      await d.arrive(find.byType(ProofScreen), hold: 0.8);
      await d.tap(find.byType(IqProofTile), label: 'proof-tile');
      await d.waitFor(find.textContaining('uploaded, ready to send'));
      await d.hold(1);
      await d.tap(button('Send proof'), label: 'send-proof');
      await d.waitFor(find.text('Your proof'));
      await d.settle(on: find.byType(ActivationScreen));
      await d.hold(2);
    },
  );
}
