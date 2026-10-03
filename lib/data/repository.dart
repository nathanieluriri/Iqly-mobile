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
  Future<int> unreadNotifications();
}

class DemoRepository implements IqlyRepository {
  DemoRepository(this.data);

  final DemoData data;

  @override
  Future<User> user() async => DemoData.user;

  @override
  Future<List<Brief>> briefs() async => data.briefs;

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
  Future<int> unreadNotifications() async => DemoData.unreadNotifications;
}

final repositoryProvider = Provider<IqlyRepository>(
  (ref) => DemoRepository(DemoData()),
);
