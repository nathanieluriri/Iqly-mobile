import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:iqly_mobile/data/activations_service.dart';
import 'package:iqly_mobile/data/polls_service.dart';

import 'app_harness.dart';
import 'polls_notifications_help_harness.dart';

/// The activations at the Figma 9:41, with no wait.
Override discoverActivations() => activationsServiceProvider.overrideWithValue(
  DemoActivationsService(
    clock: () => figmaNow,
    load: Duration.zero,
    delay: Duration.zero,
  ),
);

/// Quick polls and the activations at the Figma 9:41, with no wait.
List<Override> discoverOverrides({PollsService? polls}) => [
  pollsServiceProvider.overrideWithValue(polls ?? instantPolls()),
  discoverActivations(),
];

/// The polls, notifications and help lane with the activations Discover
/// shows.
List<Override> pollsLane({PollsService? polls}) => [
  ...laneOverrides(polls: polls),
  discoverActivations(),
];
