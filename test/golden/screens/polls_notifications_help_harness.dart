import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:iqly_mobile/data/help_data.dart';
import 'package:iqly_mobile/data/help_service.dart';
import 'package:iqly_mobile/data/notifications_data.dart';
import 'package:iqly_mobile/data/notifications_service.dart';
import 'package:iqly_mobile/data/polls_data.dart';
import 'package:iqly_mobile/data/polls_service.dart';
import 'package:iqly_mobile/data/repository.dart';

import 'app_harness.dart';

/// The polls at the Figma 9:41, votes counted at once.
DemoPollsService instantPolls() =>
    DemoPollsService(delay: Duration.zero, clock: () => figmaNow);

/// Votes never count.
class FailingPollsService extends DemoPollsService {
  FailingPollsService() : super(delay: Duration.zero, clock: () => figmaNow);

  @override
  Future<Poll> answer(String pollId, List<PollAnswer> answers) async =>
      throw Exception('offline');
}

/// Votes wait until [release] lets them through.
class HeldPollsService extends DemoPollsService {
  HeldPollsService() : super(delay: Duration.zero, clock: () => figmaNow);

  final _gate = Completer<void>();

  void release() => _gate.complete();

  @override
  Future<Poll> answer(String pollId, List<PollAnswer> answers) async {
    await _gate.future;
    return super.answer(pollId, answers);
  }
}

/// The feed with its two reminders sent at the Figma 9:41.
Override instantNotifications() => notificationsServiceProvider.overrideWith(
  (ref) => DemoNotificationsService(
    ref.watch(repositoryProvider),
    clock: figmaClock,
  ),
);

DateTime figmaClock() => figmaNow;

/// No notifications yet.
class EmptyNotificationsService implements NotificationsService {
  @override
  Future<List<AppNotification>> notifications() async => const [];

  @override
  Future<int> unseen() async => 0;

  @override
  Future<void> markSeen() async {}

  @override
  Future<void> markRead(String id) async {}
}

/// The feed never loads.
class FailingNotificationsService extends EmptyNotificationsService {
  int calls = 0;
  bool fail = true;

  @override
  Future<List<AppNotification>> notifications() async {
    calls++;
    if (fail) throw Exception('offline');
    return const [];
  }
}

/// Support at once, the message sent Sat 2:20 pm and answered 3:06 pm as on
/// the frame. [replyAfter] null leaves the ticket waiting.
DemoHelpService instantHelp({Duration? replyAfter = Duration.zero}) {
  final times = [DateTime(2026, 10, 3, 14, 20), DateTime(2026, 10, 3, 15, 6)];
  var call = 0;
  return DemoHelpService(
    delay: Duration.zero,
    uploadStep: Duration.zero,
    typingAfter: Duration.zero,
    replyAfter: replyAfter,
    seededAt: figmaNow,
    clock: () => times[call < times.length ? call++ : times.length - 1],
  );
}

/// No conversations yet.
class EmptyInboxHelpService extends DemoHelpService {
  EmptyInboxHelpService()
    : super(delay: Duration.zero, uploadStep: Duration.zero);

  @override
  Future<List<HelpTicket>> conversations() async => const [];
}

/// Sending never goes through.
class FailingHelpService extends DemoHelpService {
  FailingHelpService() : super(delay: Duration.zero, uploadStep: Duration.zero);

  @override
  Future<HelpTicket> send(HelpRequest request) async =>
      throw Exception('offline');
}

List<Override> laneOverrides({
  PollsService? polls,
  NotificationsService? notifications,
  HelpService? help,
}) => [
  pollsServiceProvider.overrideWithValue(polls ?? instantPolls()),
  if (notifications != null)
    notificationsServiceProvider.overrideWithValue(notifications)
  else
    instantNotifications(),
  helpServiceProvider.overrideWithValue(help ?? instantHelp()),
];

/// The frame's typed message.
const figmaMessage =
    'Did all three steps on Thursday. Sent proof of step 2 yesterday, still '
    'says Checking.';

/// Support starts typing and never sends its reply.
class TypingHelpService extends DemoHelpService {
  TypingHelpService()
    : super(
        delay: Duration.zero,
        uploadStep: Duration.zero,
        replyAfter: null,
        clock: () => DateTime(2026, 10, 3, 14, 20),
      );

  final _never = Completer<void>();

  @override
  Stream<HelpTicket> watch(String ticketId) async* {
    await for (final ticket in super.watch(ticketId)) {
      yield ticket;
      yield ticket.copyWith(supportTyping: true);
      await _never.future;
    }
  }
}
