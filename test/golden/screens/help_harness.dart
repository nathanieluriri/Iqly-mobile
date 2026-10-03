import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:iqly_mobile/data/activations_data.dart';
import 'package:iqly_mobile/data/activations_service.dart';
import 'package:iqly_mobile/features/help/help_routes.dart';

import 'activations_harness.dart';
import 'app_harness.dart';

/// Ask for help about Kudi Box, as in the B10 frames.
final kudiBoxHelp = helpPath(about: 'a2');

/// The B10 story at the Figma 9:41: Kudi Box started with its proof in
/// and being checked ([kudiBox] to set another run), the activations
/// answering at once.
List<Override> helpActivations({ActivationProgress? kudiBox}) => [
  activationsServiceProvider.overrideWithValue(
    instantActivations(
      now: figmaNow,
      seed: Figma.world(figmaNow, kudiBox: kudiBox ?? Figma.proofSent),
    ),
  ),
];
