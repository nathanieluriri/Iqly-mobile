import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'demo_data.dart';
import 'models.dart';

/// Everything a screen reads goes through this interface so the sample
/// dataset and the live API are interchangeable.
abstract class IqlyRepository {
  Future<User> user();
  Future<List<Brief>> briefs();
  Future<Brief?> brief(String id);
  Future<List<Submission>> submissions();
  Future<List<LedgerEntry>> ledger();
  Future<List<Withdrawal>> withdrawals();
  Future<List<Bank>> banks();
  Future<SavedBank?> savedBank();

  Future<int> unreadNotificationCount();

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

class DemoRepository implements IqlyRepository {
  DemoRepository(this.data, {this.latency = Duration.zero});

  final DemoData data;

  /// Stands in for network time on the calls that page or refresh a list.
  final Duration latency;

  final _saved = {...DemoData.savedBriefIds};
  final _reminders = {...DemoData.closeReminderIds};

  Future<void> _wait() =>
      latency == Duration.zero ? Future.value() : Future.delayed(latency);

  @override
  Future<User> user() async => DemoData.user;

  @override
  Future<List<Brief>> briefs() async {
    await _wait();
    return data.briefs;
  }

  @override
  Future<Brief?> brief(String id) async =>
      data.briefs.where((b) => b.id == id).firstOrNull;

  @override
  Future<List<Submission>> submissions() async => data.submissions;

  @override
  Future<List<LedgerEntry>> ledger() async => data.ledger;

  @override
  Future<List<Withdrawal>> withdrawals() async => data.withdrawals;

  @override
  Future<List<Bank>> banks() async => DemoData.banks;

  @override
  Future<SavedBank?> savedBank() async => DemoData.savedBank;

  @override
  Future<int> unreadNotificationCount() async => DemoData.unreadNotifications;

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

final repositoryProvider = Provider<IqlyRepository>(
  (ref) => DemoRepository(DemoData()),
);
