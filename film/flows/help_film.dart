import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/activations/activation_screen.dart';
import 'package:iqly_mobile/features/activations/activations_screen.dart';
import 'package:iqly_mobile/features/activations/proof_screen.dart';
import 'package:iqly_mobile/features/help/help_request_screen.dart';
import 'package:iqly_mobile/features/help/help_thread_screen.dart';
import 'package:iqly_mobile/ui/activation_ticket.dart';
import 'package:iqly_mobile/ui/field.dart';
import 'package:iqly_mobile/ui/proof_tile.dart';

import '../harness.dart';
import '../steps.dart';

/// A returning contributor signs in and sends proof for Unibooks' step 2
/// (activations_proof at a brisk pace), then takes the app's way to Help:
/// Ask for help under Your proof, a message to support, and the thread as
/// support types, replies and the updated balance arrives.
void main() {
  film('help', (d) async {
    await signIn(d);

    await d.tap(find.text('Activations'));
    final unibooks = find.byWidgetPredicate(
      (w) => w is IqActivationTicket && w.brand == 'Unibooks',
      description: 'the Unibooks ticket',
    );
    await d.waitFor(unibooks);
    await d.settle(on: find.byType(ActivationsScreen));
    await d.hold(0.6);
    final resume = find.descendant(
      of: unibooks,
      matching: find.text('Continue'),
    );
    await d.reveal(resume, listIn(find.byType(ActivationsScreen)));
    await d.hold(0.5);
    await d.tap(resume, label: 'unibooks-continue');
    await d.arrive(find.byType(ActivationScreen), hold: 0.6);
    await d.tap(find.text('Upload proof of step 2'));
    await d.arrive(find.byType(ProofScreen), hold: 0.6);
    await d.tap(find.byType(IqProofTile), label: 'proof-tile');
    await d.waitFor(find.textContaining('uploaded, ready to send'));
    await d.hold(0.6);
    await d.tap(find.text('Send proof'));

    // Unibooks checks the proof 4 s after it lands and pays, which takes
    // Ask for help away, so this part does not linger.
    await d.waitFor(find.text('Your proof'));
    await d.settle(on: find.byType(ActivationScreen));
    await d.reveal(
      find.text('Ask for help'),
      listIn(find.byType(ActivationScreen)),
    );
    await d.hold(0.4);
    await d.tap(find.text('Ask for help'));

    await d.arrive(find.byType(HelpRequestScreen), hold: 0.8);
    await d.tap(
      find.byWidgetPredicate(
        (w) => w is IqField && w.label == 'What happened?',
      ),
      label: 'what-happened',
    );
    await d.type(
      'My order went in yesterday but step 2 is still not confirmed.',
      cps: 18,
    );
    await d.hold(0.8);
    await d.tap(find.text('Send to support'));

    await d.arrive(find.byType(HelpThreadScreen), hold: 0.6);
    await d.waitFor(find.textContaining('confirmed.'), timeout: 8);
    await d.hold(1.5);
  });
}
