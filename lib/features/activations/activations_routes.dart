import 'package:go_router/go_router.dart';

import '../../core/flags.dart';
import '../../core/transitions.dart';
import '../../router.dart';
import 'activation_screen.dart';
import 'activations_screen.dart';
import 'proof_player_screen.dart';
import 'proof_screen.dart';

String activationPath(String id) => '/activations/$id';

String proofPath(String id) => '/activations/$id/proof';

String proofPlayerPath(String id) => '/activations/$id/play';

/// Rows B8 and B9 behind Flags.activations, every page a push over the
/// shell: the list ([Routes.activations]), one activation in all its states
/// ([Routes.activation]), its proof ([Routes.activationProof]) and the
/// recording's player ([Routes.proofPlayer]). Nested, so a direct `go`
/// builds the list and the activation beneath.
final activationsRoutes = <RouteBase>[
  if (Flags.activations)
    GoRoute(
      path: Routes.activations,
      pageBuilder: (context, state) =>
          pushPage(state, const ActivationsScreen()),
      routes: [
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
