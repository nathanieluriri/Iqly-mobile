import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'demo_data.dart';
import 'models.dart';

/// Why briefs are being loaded. The Discover feed loads cold, pull to
/// refresh skips any cache and [nextPage] is the page the feed asks for as
/// it scrolls; [any] (joins such as My submissions) may come from cache.
enum BriefsLoad { any, feed, refresh, nextPage }

/// Everything a screen reads goes through this interface so the sample
/// dataset and the live API are interchangeable.
abstract class IqlyRepository {
  Future<User> user();
  Future<List<Brief>> briefs({BriefsLoad load = BriefsLoad.any});
  Future<Brief?> brief(String id);
  Future<List<Submission>> submissions();
  Future<List<LedgerEntry>> ledger();
  Future<List<Withdrawal>> withdrawals();
  Future<List<Bank>> banks();
  Future<SavedBank?> savedBank();
  Future<int> unreadNotifications();

  /// Behind Flags.polls.
  Future<List<PollBrand>> pollBrands();

  /// Behind Flags.activations.
  Future<ActivationsSummary> activationsSummary();

  /// Behind Flags.savedBriefs. The device keeps its own copy for offline use.
  Future<List<String>> savedBriefIds();
  Future<void> setBriefSaved(String id, bool saved);

  /// Behind Flags.closeReminders: a reminder an hour before close.
  Future<List<String>> closeReminderIds();
  Future<void> setCloseReminder(String id, bool on);
}

/// How long the demo takes to answer. The app uses the Figma prototype
/// timings so its loading states show; tests use [none].
class DemoLatency {
  const DemoLatency({
    this.feed = Duration.zero,
    this.refresh = Duration.zero,
    this.nextPage = Duration.zero,
    this.submissions = Duration.zero,
  });

  static const none = DemoLatency();

  /// Discover loading 1.2 s, refreshing 1 s, loading more 2 s; My
  /// submissions loading 1.2 s.
  static const prototype = DemoLatency(
    feed: Duration(milliseconds: 1200),
    refresh: Duration(seconds: 1),
    nextPage: Duration(seconds: 2),
    submissions: Duration(milliseconds: 1200),
  );

  final Duration feed;
  final Duration refresh;
  final Duration nextPage;
  final Duration submissions;

  Duration forBriefs(BriefsLoad load) => switch (load) {
    BriefsLoad.any => Duration.zero,
    BriefsLoad.feed => feed,
    BriefsLoad.refresh => refresh,
    BriefsLoad.nextPage => nextPage,
  };
}

class DemoRepository implements IqlyRepository {
  DemoRepository(this.data, {this.latency = DemoLatency.none});

  final DemoData data;
  final DemoLatency latency;

  final _saved = {...DemoData.savedBriefIds};
  final _reminders = {...DemoData.closeReminderIds};

  Future<void> _wait(Duration duration) => duration == Duration.zero
      ? Future.value()
      : Future<void>.delayed(duration);

  @override
  Future<User> user() async => DemoData.user;

  @override
  Future<List<Brief>> briefs({BriefsLoad load = BriefsLoad.any}) async {
    await _wait(latency.forBriefs(load));
    return data.briefs;
  }

  @override
  Future<Brief?> brief(String id) async =>
      data.briefs.where((b) => b.id == id).firstOrNull;

  @override
  Future<List<Submission>> submissions() async {
    await _wait(latency.submissions);
    return data.submissions;
  }

  @override
  Future<List<LedgerEntry>> ledger() async => data.ledger;

  @override
  Future<List<Withdrawal>> withdrawals() async => data.withdrawals;

  @override
  Future<List<Bank>> banks() async => DemoData.banks;

  @override
  Future<SavedBank?> savedBank() async => DemoData.savedBank;

  @override
  Future<int> unreadNotifications() async => DemoData.unreadNotifications;

  @override
  Future<List<PollBrand>> pollBrands() async => DemoData.pollBrands;

  @override
  Future<ActivationsSummary> activationsSummary() async => DemoData.activations;

  @override
  Future<List<String>> savedBriefIds() async => [..._saved];

  @override
  Future<void> setBriefSaved(String id, bool saved) async =>
      saved ? _saved.add(id) : _saved.remove(id);

  @override
  Future<List<String>> closeReminderIds() async => [..._reminders];

  @override
  Future<void> setCloseReminder(String id, bool on) async =>
      on ? _reminders.add(id) : _reminders.remove(id);
}

/// The app runs on the sample dataset at prototype pace; tests override it
/// with a [DemoLatency.none] repository.
final repositoryProvider = Provider<IqlyRepository>(
  (ref) => DemoRepository(DemoData(), latency: DemoLatency.prototype),
);

/// The bell's unread count, shared by every tab's top bar.
final unreadNotificationsProvider = FutureProvider<int>(
  (ref) => ref.watch(repositoryProvider).unreadNotifications(),
);
