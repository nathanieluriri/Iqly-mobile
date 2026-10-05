import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/flags.dart';
import '../../core/transitions.dart';
import '../../data/activations_data.dart';
import '../../router.dart';
import 'activation_screen.dart';
import 'activations_screen.dart';
import 'activations_state.dart';
import 'my_activations_screen.dart';
import 'proof_player_screen.dart';
import 'proof_screen.dart';

String activationPath(String id) => '/activations/$id';

String proofPath(String id) => '/activations/$id/proof';

String proofPlayerPath(String id) => '/activations/$id/play';

/// B8 · My activations (485:38281).
const myActivationsPath = '/activations/mine';

/// Where "My activations" goes (#16): the list with its Active and Done
/// tabs, or the activation itself when you have exactly one.
String myActivationsTarget(List<Activation> all) {
  final mine = [
    for (final a in all)
      if (a.started) a,
  ];
  return mine.length == 1 ? activationPath(mine.single.id) : myActivationsPath;
}

/// [myActivationsTarget] for the activations as loaded; the list until
/// they are.
final myActivationsLinkProvider = Provider<String>((ref) {
  final all = ref.watch(activationsProvider).value;
  return all == null ? myActivationsPath : myActivationsTarget(all);
});

/// Rows B8 and B9 behind Flags.activations. Every page is a sub page pushed
/// over the shell (Page top bar, Back, no dock), reached from Discover or
/// More: the list, My activations, one activation in all its states, its
/// proof and the recording's player. Nested, so a direct `go` builds the
/// list beneath; Back always pops what opened the page.
final activationsRoutes = <RouteBase>[
  if (Flags.activations)
    GoRoute(
      path: Routes.activations,
      pageBuilder: (context, state) =>
          pushPage(state, const ActivationsScreen()),
      routes: [
        GoRoute(
          path: 'mine',
          pageBuilder: (context, state) =>
              pushPage(state, const MyActivationsScreen()),
        ),
        GoRoute(
          path: ':id',
          pageBuilder: (context, state) => pushPage(
            state,
            ActivationScreen(id: state.pathParameters['id']!),
          ),
          routes: [
            GoRoute(
              path: 'proof',
              pageBuilder: (context, state) =>
                  pushPage(state, ProofScreen(id: state.pathParameters['id']!)),
            ),
            GoRoute(
              path: 'play',
              pageBuilder: (context, state) => pushPage(
                state,
                ProofPlayerScreen(id: state.pathParameters['id']!),
              ),
            ),
          ],
        ),
      ],
    ),
];
