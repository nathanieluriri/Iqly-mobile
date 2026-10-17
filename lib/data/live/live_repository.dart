import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/backend.dart';
import '../../core/deadline.dart';
import '../../core/session.dart';
import '../api_client.dart';
import '../drafts_data.dart';
import '../local/local_providers.dart';
import '../local/local_store.dart';
import '../models.dart';
import '../points_data.dart';
import '../repository.dart';
import 'mappers.dart';

/// What this launch runs on the API: health's decision, in a build that has
/// an API client at all.
final liveModeProvider = Provider<Backend>(
  (ref) => ref.watch(apiClientProvider) == null
      ? Backend.preview
      : ref.watch(backendProvider),
);

/// The live repository whenever the launch runs anything live. It is made
/// again for each signed-in person, so nothing one account read is ever
/// shown to another.
final liveRepositoryProvider = Provider<LiveRepository?>((ref) {
  final api = ref.watch(apiClientProvider);
  final mode = ref.watch(liveModeProvider);
  if (api == null || mode.isPreview) return null;
  return LiveRepository(
    api: api,
    store: ref.watch(localStoreProvider),
    mode: mode,
    demo: ref.watch(demoRepositoryProvider),
    userId: ref.watch(sessionProvider.select((s) => s.userId)),
    clock: ref.watch(clockProvider),
  );
});

/// Where each answer is kept in the local store.
abstract final class LiveCacheKeys {
  static const briefs = '/challenges/browse';
  static const submissions = '/submissions/mine';
  static const ledger = '/wallet/transactions';
  static const withdrawals = '/wallet/withdrawals';
  static const bankAccount = '/wallet/bank-account';
  static const wallet = '/wallet';
  static const banks = '/banks';
}

/// Reads the iQLY API for each feature this launch runs live and answers
/// the rest exactly as [demo] does. Every answer is kept in the local store
/// under the signed-in person's id and served from there when the API
/// cannot be reached, so the screens open offline on their last copy.
class LiveRepository implements IqlyRepository {
  LiveRepository({
    required this.api,
    required this.store,
    required this.mode,
    required this.demo,
    this.userId,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final ApiClient api;
  final LocalStore store;
  final Backend mode;
  final IqlyRepository demo;

  /// Keys this person's rows in [store]; without one nothing is kept, and
  /// drafts last only as long as the screens hold them.
  final String? userId;
  final DateTime Function() _clock;

  static const briefsPerPage = 60;
  static const rowsPerPage = 100;

  /// Stops paging an answer that never ends.
  static const maxPages = 50;
  static const banksKeptFor = Duration(days: 1);

  List<Brief>? _briefs;
  Future<List<Brief>>? _loadingBriefs;
  final _reading = <String, Future<Object?>>{};

  /// Every live brief, all pages. The feed and a refresh ask the API; a
  /// join or the next page answers from what this session loaded last.
  /// Only a refresh fails when the API cannot be reached: the rest fall
  /// back to the phone's last copy.
  @override
  Future<List<Brief>> briefs({BriefsLoad load = BriefsLoad.any}) {
    if (!mode.isLive(LiveFeature.briefs)) return demo.briefs(load: load);
    final held = _briefs;
    if (held != null &&
        (load == BriefsLoad.any || load == BriefsLoad.nextPage)) {
      return Future.value(held);
    }
    final joining = _loadingBriefs;
    if (joining != null && load != BriefsLoad.refresh) return joining;
    final loading = _loadBriefs(allowCache: load != BriefsLoad.refresh);
    _loadingBriefs = loading;
    loading.whenComplete(() {
      if (identical(_loadingBriefs, loading)) _loadingBriefs = null;
    }).ignore();
    return loading;
  }

  Future<List<Brief>> _loadBriefs({required bool allowCache}) async {
    final items = await _read(
      LiveCacheKeys.briefs,
      _browse,
      allowCache: allowCache,
    );
    return _briefs = rowsOf(items, briefFromJson);
  }

  Future<List<Object?>> _browse() async {
    final items = <Object?>[];
    for (var page = 1; page <= maxPages; page++) {
      final data = _data(
        await api.get(
          '/challenges/browse?status=live&perPage=$briefsPerPage&page=$page',
        ),
      );
      final rows = data['items'];
      if (rows is List) items.addAll(rows);
      final pages = data['pageCount'];
      if (pages is! int || page >= pages) break;
    }
    return items;
  }

  /// From the API; offline, from the briefs this phone last loaded. Null
  /// when neither has it, so brief detail can fall back to a saved copy.
  @override
  Future<Brief?> brief(String id) async {
    if (!mode.isLive(LiveFeature.briefs)) return demo.brief(id);
    final ApiResponse res;
    try {
      res = await api.get('/challenges/${Uri.encodeComponent(id)}');
    } on ApiUnreachable {
      final known =
          _briefs ??
          rowsOf((await _kept(LiveCacheKeys.briefs))?.json, briefFromJson);
      return known.where((b) => b.id == id).firstOrNull;
    }
    if (res.status == 404) return null;
    return briefFromJson(_data(res));
  }

  /// Every page of the person's submissions, each with its brief and award
  /// as the API embeds them.
  @override
  Future<List<Submission>> submissions() async {
    if (!mode.isLive(LiveFeature.submissions)) return demo.submissions();
    final items = await _read(
      LiveCacheKeys.submissions,
      () => _pages('/submissions/mine'),
    );
    return rowsOf(items, submissionFromJson);
  }

  /// Without [allowCache] an API that cannot be reached fails the read
  /// instead of answering the phone's last copy.
  @override
  Future<List<LedgerEntry>> ledger({bool allowCache = true}) async {
    if (!mode.isLive(LiveFeature.wallet)) return demo.ledger();
    final items = await _read(
      LiveCacheKeys.ledger,
      () => _pages('/wallet/transactions'),
      allowCache: allowCache,
    );
    return rowsOf(items, ledgerEntryFromJson);
  }

  @override
  Future<List<Withdrawal>> withdrawals({bool allowCache = true}) async {
    if (!mode.isLive(LiveFeature.withdrawals)) return demo.withdrawals();
    final items = await _read(
      LiveCacheKeys.withdrawals,
      () => _pages('/wallet/withdrawals'),
      allowCache: allowCache,
    );
    return rowsOf(items, withdrawalFromJson);
  }

  /// The banks change rarely: a day-old copy is answered without asking.
  @override
  Future<List<Bank>> banks() async {
    if (!mode.isLive(LiveFeature.wallet)) return demo.banks();
    final kept = await _kept(LiveCacheKeys.banks);
    if (kept != null &&
        _clock().difference(kept.fetchedAt).abs() < banksKeptFor) {
      return rowsOf(kept.json, bankFromJson);
    }
    final List<Object?> list;
    try {
      final res = await api.get('/banks?currency=NGN');
      if (!res.ok) throw ApiRefused(res.status, res.code);
      list = res.list;
    } on ApiUnreachable {
      if (kept == null) rethrow;
      return rowsOf(kept.json, bankFromJson);
    }
    await _keep(LiveCacheKeys.banks, list);
    return rowsOf(list, bankFromJson);
  }

  @override
  Future<SavedBank?> savedBank() async {
    if (!mode.isLive(LiveFeature.wallet)) return demo.savedBank();
    return (await savedBanks()).firstOrNull;
  }

  /// The API keeps one payout account, so this is it or nothing.
  @override
  Future<List<SavedBank>> savedBanks({bool allowCache = true}) async {
    if (!mode.isLive(LiveFeature.wallet)) return demo.savedBanks();
    final account = await _read(
      LiveCacheKeys.bankAccount,
      () async => _payload(await api.get('/wallet/bank-account')),
      allowCache: allowCache,
    );
    return [?savedBankFromJson(account)];
  }

  /// The wallet's figures as the API reports them (`GET /wallet`). Null
  /// while the wallet is not live: the demo adds them up from its rows.
  Future<WalletTotals?> walletTotals({bool allowCache = true}) async {
    if (!mode.isLive(LiveFeature.wallet)) return null;
    final wallet = await _read(
      LiveCacheKeys.wallet,
      () async => _payload(await api.get('/wallet')),
      allowCache: allowCache,
    );
    return walletTotalsFromJson(wallet);
  }

  /// Live drafts stay on this phone, in the store under the person's id, so
  /// they outlast a restart.
  @override
  Future<List<Draft>> drafts() async {
    if (!mode.isLive(LiveFeature.submit)) return demo.drafts();
    final id = userId;
    return id == null ? const [] : store.drafts(id);
  }

  @override
  Future<void> saveDraft(Draft draft) async {
    if (!mode.isLive(LiveFeature.submit)) return demo.saveDraft(draft);
    final id = userId;
    if (id == null) return;
    try {
      await store.saveDraft(id, draft);
    } catch (error) {
      debugPrint('Draft not kept: $error');
    }
  }

  @override
  Future<void> discardDrafts(Iterable<String> briefIds) async {
    if (!mode.isLive(LiveFeature.submit)) return demo.discardDrafts(briefIds);
    final id = userId;
    if (id != null) await store.deleteDrafts(id, briefIds);
  }

  // The device lists seed from these: the demo's seeds would bring preview
  // briefs back after the first live launch cleared them. Saving and
  // reminders stay on the device.
  @override
  Future<List<String>> savedBriefIds() async => const [];

  @override
  Future<void> setBriefSaved(String id, bool saved) async {}

  @override
  Future<List<String>> closeReminderIds() async => const [];

  @override
  Future<void> setCloseReminder(String id, bool on) async {}

  @override
  Future<User> user() => demo.user();

  @override
  Future<int> unreadNotifications() => demo.unreadNotifications();

  @override
  Future<int> points() => demo.points();

  @override
  Future<PointsBoard> pointsLeaderboard() => demo.pointsLeaderboard();

  @override
  Future<ActivationsSummary> activationsSummary() => demo.activationsSummary();

  /// Every page of a cursor list, newest first.
  Future<List<Object?>> _pages(String path) async {
    final items = <Object?>[];
    String? cursor;
    for (var page = 0; page < maxPages; page++) {
      final query = Uri(
        queryParameters: {'limit': '$rowsPerPage', 'cursor': ?cursor},
      ).query;
      final data = _data(await api.get('$path?$query'));
      final rows = data['items'];
      if (rows is List) items.addAll(rows);
      final next = data['nextCursor'];
      if (next is! String || next.isEmpty || next == cursor) break;
      cursor = next;
    }
    return items;
  }

  /// [fetch] from the API, kept for next time; when the API cannot be
  /// reached, the copy kept last time. Reads of the same answer at the same
  /// time share one fetch.
  Future<Object?> _read(
    String key,
    Future<Object?> Function() fetch, {
    bool allowCache = true,
  }) {
    final read = '$key $allowCache';
    return _reading[read] ??= _readOnce(key, fetch, allowCache: allowCache)
        .whenComplete(() {
          _reading.remove(read);
        });
  }

  Future<Object?> _readOnce(
    String key,
    Future<Object?> Function() fetch, {
    required bool allowCache,
  }) async {
    final Object? json;
    try {
      json = await fetch();
    } on ApiUnreachable {
      if (!allowCache) rethrow;
      final kept = await _kept(key);
      if (kept == null) rethrow;
      return kept.json;
    }
    await _keep(key, json);
    return json;
  }

  Future<CacheEntry?> _kept(String key) async {
    final id = userId;
    if (id == null) return null;
    try {
      return await store.readCache(id, key);
    } catch (error) {
      debugPrint('Cached $key not read: $error');
      return null;
    }
  }

  Future<void> _keep(String key, Object? json) async {
    final id = userId;
    if (id == null) return;
    try {
      await store.writeCache(id, key, json);
    } catch (error) {
      debugPrint('$key not cached: $error');
    }
  }

  static Map<String, dynamic> _data(ApiResponse res) {
    if (!res.ok) throw ApiRefused(res.status, res.code);
    return res.data;
  }

  /// The answer's `data` whatever its shape: an object, a list or null.
  static Object? _payload(ApiResponse res) {
    if (!res.ok) throw ApiRefused(res.status, res.code);
    return res.body['data'];
  }
}
