import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/backend.dart';
import '../core/session.dart';
import 'live/live_account.dart';
import 'live/live_notifications_service.dart';
import 'notifications_data.dart';
import 'repository.dart';

/// The notification feed and the bell. The live API keeps both; the demo
/// builds the B6 feed on the repository's ledger and withdrawals and starts
/// the bell at the repository's unread count.
abstract class NotificationsService {
  /// The feed, newest first.
  Future<List<AppNotification>> notifications();

  /// The bell: what arrived since the person last saw the feed.
  Future<int> unseen();

  /// The person has seen the feed, so the bell clears.
  Future<void> markSeen();

  /// The person opened [id], so its unread dot goes.
  Future<void> markRead(String id);
}

class DemoNotificationsService implements NotificationsService {
  DemoNotificationsService(this.repository, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final IqlyRepository repository;
  final DateTime Function() _clock;

  List<AppNotification>? _feed;
  bool _seen = false;

  Future<List<AppNotification>> _load() async {
    if (_feed case final feed?) return feed;
    final (ledger, withdrawals) = await (
      repository.ledger(),
      repository.withdrawals(),
    ).wait;
    return _feed ??= demoNotifications(
      ledger: ledger,
      withdrawals: withdrawals,
      now: _clock(),
    );
  }

  @override
  Future<List<AppNotification>> notifications() async => [...await _load()];

  @override
  Future<int> unseen() async => _seen ? 0 : repository.unreadNotifications();

  @override
  Future<void> markSeen() async => _seen = true;

  @override
  Future<void> markRead(String id) async {
    final feed = await _load();
    _feed = [for (final n in feed) n.id == id ? n.read() : n];
  }
}

/// The API while notifications run live this launch, else the demo feed.
final notificationsServiceProvider = Provider<NotificationsService>((ref) {
  ref.watch(accountProvider);
  final link = ref.watch(liveLinkProvider(LiveFeature.notifications));
  if (link != null) return LiveNotificationsService(link);
  return DemoNotificationsService(ref.watch(repositoryProvider));
});
