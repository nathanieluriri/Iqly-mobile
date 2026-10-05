import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:iqly_mobile/data/polls_service.dart';

import 'polls_notifications_help_harness.dart';

/// Quick polls at the Figma 9:41, with no wait (the activations come from
/// pumpApp).
List<Override> discoverOverrides({PollsService? polls}) => [
  pollsServiceProvider.overrideWithValue(polls ?? instantPolls()),
];

/// The polls, notifications and help lane as Discover shows it.
List<Override> pollsLane({PollsService? polls}) => laneOverrides(polls: polls);
