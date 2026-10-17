import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/backend.dart';
import '../../core/session.dart';
import '../api_client.dart';
import '../local/local_providers.dart';
import '../local/local_store.dart';
import '../local/outbox.dart';
import '../local/scoped_local_store.dart';
import '../models.dart';
import '../reference_data.dart';
import 'kept_reads.dart';
import 'live_profile_service.dart';

/// A UTC time from the API in the phone's time zone, or null.
DateTime? apiTime(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;

final _day = RegExp(r'^(\d{4})-(\d{2})-(\d{2})');

/// The calendar day a `YYYY-MM-DD` date names, or null for anything else.
DateTime? apiDate(Object? value) {
  final match = value is String ? _day.firstMatch(value) : null;
  if (match == null) return null;
  final [year, month, day] = [
    for (var i = 1; i <= 3; i++) int.parse(match[i]!),
  ];
  final date = DateTime(year, month, day);
  return date.month == month && date.day == day ? date : null;
}

/// [date] as the API writes a date of birth: `2001-04-09`.
String apiDay(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Trimmed text, null when blank or not text.
String? apiText(Object? value) {
  if (value is! String) return null;
  final text = value.trim();
  return text.isEmpty ? null : text;
}

int? apiInt(Object? value) => value is num ? value.toInt() : null;

/// The values of [options] that [value] lists, in its order.
List<String> knownValues(Object? value, List<RefOption> options) => [
  if (value is List)
    for (final item in value)
      if (item is String && options.any((o) => o.value == item)) item,
];

/// [value] when [options] has it; an unknown value reads as unanswered.
String? knownValue(Object? value, List<RefOption> options) =>
    options.any((o) => o.value == value) ? value as String : null;

/// The account writes the outbox sends (contract 3 and 7), each with the
/// feature it belongs to (contract 8), the key its pending writes fold
/// under and, when the answer is the record itself, the cache key it
/// refreshes.
enum AccountWrite {
  onboarding(
    LiveFeature.profile,
    'profile.onboarding',
    'POST',
    '/me/onboarding',
    'profile:onboarding',
    AccountKeys.profile,
  ),
  profile(
    LiveFeature.profile,
    'profile.patch',
    'PATCH',
    '/profiles/contributors/me',
    'profile:patch',
    AccountKeys.profile,
  ),
  preferences(
    LiveFeature.profile,
    'profile.preferences',
    'PUT',
    '/me/notification-preferences',
    'prefs',
    AccountKeys.preferences,
  ),
  seen(
    LiveFeature.notifications,
    'notifications.seen',
    'POST',
    '/notifications/seen',
    'notif:seen',
  ),
  read(
    LiveFeature.notifications,
    'notifications.read',
    'POST',
    '/notifications/read',
    'notif:read',
  );

  const AccountWrite(
    this.feature,
    this.kind,
    this.method,
    this.path,
    this.coalesceKey, [
    this.keepAs,
  ]);

  final LiveFeature feature;
  final String kind;
  final String method;
  final String path;
  final String coalesceKey;
  final String? keepAs;
}

/// Where the account's answers are kept in the local store.
abstract final class AccountKeys {
  static const me = 'me';
  static const profile = 'profile';
  static const preferences = 'preferences';
  static const notifications = 'notifications';

  static String outcome(String submissionId) => 'outcomes/$submissionId';
}

/// Sends a queued write: its payload as the JSON body, its id as the
/// Idempotency-Key, the answer mapped onto the outbox. A write whose answer
/// is the record keeps it for the next read without a connection, while
/// its account is still the one [signedIn].
Future<OutboxResult> sendQueued(
  ApiClient api,
  LocalStore store,
  OutboxItem item,
  AccountWrite write, {
  bool Function(String userId)? signedIn,
}) async {
  final ApiResponse res;
  try {
    res = await api.send(
      write.method,
      write.path,
      body: item.payload,
      idempotencyKey: item.id,
    );
  } on ApiUnreachable {
    return outboxResultFor(status: 0, networkError: true);
  }
  final keepAs = write.keepAs;
  if (res.ok &&
      keepAs != null &&
      res.data.isNotEmpty &&
      (signedIn?.call(item.userId) ?? true)) {
    await store.writeCache(item.userId, keepAs, res.data);
  }
  return outboxResultFor(
    status: res.status,
    code: res.code,
    message: res.message,
    retryAfter: res.retryAfter,
  );
}

/// Lets [outbox] send the account's writes of the features [live] says the
/// launch runs (all of them without it); the rest wait, kept, for a launch
/// that runs theirs. [onFailed] hears each write the API refuses for good,
/// with its code.
void registerAccountWrites(
  Outbox outbox,
  ApiClient api,
  LocalStore store, {
  bool Function(LiveFeature feature)? live,
  bool Function(String userId)? signedIn,
  void Function(OutboxItem item, AccountWrite write, String code)? onFailed,
}) {
  for (final write in AccountWrite.values) {
    if (!(live?.call(write.feature) ?? true)) {
      outbox.unregister(write.kind);
      continue;
    }
    outbox.register(write.kind, (item) async {
      final result = await sendQueued(
        api,
        store,
        item,
        write,
        signedIn: signedIn,
      );
      if (result case OutboxFail(:final code)) {
        onFailed?.call(item, write, code);
      }
      return result;
    });
  }
}

/// What the live account services share: the API, the person's rows in the
/// local store and the outbox their writes queue in. [userId] is the
/// session's account id; without one, reads skip the store and writes go
/// straight to the API.
class AccountLink {
  AccountLink({
    required this.api,
    required this.store,
    required this.outbox,
    required this.userId,
    AccountScope? scope,
  }) : scope = scope ?? AccountScope.always();

  final ApiClient api;
  final LocalStore store;
  final Outbox outbox;
  final String? Function() userId;

  /// The account's stretch this link serves: once it has closed, a read
  /// that lands fails with [AccountChanged] and no write queues.
  final AccountScope scope;

  /// GET [path]'s payload, kept under [key]. When the API does not answer
  /// ([orKept]) it answers what was kept last, and fails as the API did
  /// when nothing was. A refusal throws [ApiRefused].
  Future<Map<String, dynamic>> fetch(String path, String key) {
    final fetching = api.get(path).then((res) async {
      if (!res.ok) throw ApiRefused.of(res);
      await keep(key, res.data);
      return res.data;
    });
    return scope.guard(
      orKept(
        fetching,
        kept(key).then((json) => json == null ? null : (copy: json)),
      ),
    );
  }

  Future<Map<String, dynamic>?> kept(String key) async {
    final user = userId();
    if (user == null) return null;
    final json = (await store.readCache(user, key))?.json;
    return json is Map ? json.cast<String, dynamic>() : null;
  }

  Future<void> keep(String key, Map<String, dynamic> json) async {
    final user = userId();
    if (user != null) await store.writeCache(user, key, json);
  }

  /// Queues [write]; with no account id it is sent now, throwing
  /// [ApiRefused] or [ApiUnreachable] when it does not land. Once [scope]
  /// has closed nothing goes, and it throws [AccountChanged].
  Future<void> queue(
    AccountWrite write,
    Map<String, Object?> payload, {
    OutboxMerge? merge,
  }) async {
    if (!scope.open) throw const AccountChanged();
    final user = userId();
    if (user == null) {
      final res = await api.send(write.method, write.path, body: payload);
      if (!res.ok) throw ApiRefused.of(res);
      return;
    }
    final dependsOn = await _after(user, write);
    if (!scope.open) throw const AccountChanged();
    await outbox.enqueue(
      user,
      kind: write.kind,
      payload: payload,
      coalesceKey: write.coalesceKey,
      merge: merge,
      dependsOn: dependsOn,
    );
  }

  /// A profile edit or a switch needs the contributor profile, which a new
  /// account only has once its first-run answers land: while they wait to
  /// go, the write waits for them.
  Future<String?> _after(String user, AccountWrite write) async {
    if (write != AccountWrite.profile && write != AccountWrite.preferences) {
      return null;
    }
    return (await store.outbox(user))
        .where(
          (item) =>
              item.kind == AccountWrite.onboarding.kind &&
              (item.status == OutboxStatus.pending ||
                  item.status == OutboxStatus.sending),
        )
        .lastOrNull
        ?.id;
  }

  /// The payloads of [write] still to go, oldest first.
  Future<List<Map<String, dynamic>>> waiting(AccountWrite write) async {
    final user = userId();
    if (user == null) return const [];
    return [
      for (final item in await store.outbox(user))
        if (item.kind == write.kind &&
            (item.status == OutboxStatus.pending ||
                item.status == OutboxStatus.sending))
          item.payload,
    ];
  }
}

/// The signed-in account, as `GET /me` answers it (contract 3).
class Me {
  const Me({
    required this.id,
    required this.name,
    required this.email,
    this.memberSince,
    this.closing = false,
    this.closesAt,
    this.profile,
  });

  /// Any status but `closing` reads as active.
  factory Me.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'];
    return Me(
      id: apiText(json['id']) ?? '',
      name: (apiText(json['name']) ?? '').replaceAll(RegExp(r'\s+'), ' '),
      email: apiText(json['email']) ?? '',
      memberSince: apiTime(json['memberSince']),
      closing: json['status'] == 'closing',
      closesAt: apiTime(json['closesAt']),
      profile: profile is Map
          ? ContributorProfile.fromJson(profile.cast<String, dynamic>())
          : null,
    );
  }

  final String id;
  final String name;
  final String email;
  final DateTime? memberSince;
  final bool closing;

  /// 30 days after the close was asked for.
  final DateTime? closesAt;
  final ContributorProfile? profile;

  /// The account as the screens read it: [name] split at its first space,
  /// the state of residence, and the interests by their labels.
  User toUser() {
    final space = name.indexOf(' ');
    final p = profile;
    return User(
      firstName: space < 0 ? name : name.substring(0, space),
      lastName: space < 0 ? '' : name.substring(space + 1),
      email: email,
      state: p?.stateOfResidence ?? '',
      city: p?.city ?? '',
      university: p?.university ?? '',
      interests: [
        for (final value in p?.interests ?? const <String>[])
          ?Reference.interests
              .where((o) => o.value == value)
              .firstOrNull
              ?.label,
      ],
      occupation: p?.occupations.firstOrNull,
      education: p?.education,
    );
  }
}

/// `/me` and the close and restore of the account (contract 3, 3.4).
class LiveAccount {
  LiveAccount(this.link);

  final AccountLink link;

  /// Kept under the account's own id, which the session may not know yet.
  Future<Me> me() async {
    final ApiResponse res;
    try {
      res = await link.api.get('/me');
    } on ApiUnreachable {
      final kept = await link.kept(AccountKeys.me);
      if (kept != null) return Me.fromJson(kept);
      rethrow;
    }
    if (!res.ok) throw ApiRefused.of(res);
    final me = Me.fromJson(res.data);
    if (me.id.isNotEmpty) {
      await link.store.writeCache(me.id, AccountKeys.me, res.data);
    }
    return me;
  }

  /// Online only. ACCOUNT_HAS_BALANCE, WITHDRAWAL_IN_FLIGHT and any other
  /// refusal throw [ApiRefused]. The API ends every session of the account.
  Future<void> close() async {
    final res = await link.api.post('/me/account/close', {'confirm': 'DELETE'});
    if (!res.ok) throw ApiRefused.of(res);
  }

  /// An account that is not closing is already what restore asks for.
  Future<void> restore() async {
    final res = await link.api.post('/me/account/restore');
    if (!res.ok && res.code != 'ACCOUNT_NOT_CLOSING') {
      throw ApiRefused.of(res);
    }
    unawaited(link.outbox.resume());
  }
}

/// The link to the API in a live build, null in the preview. Made for each
/// account, so an answer that lands after a sign-out is kept for the
/// account that asked for it and never for whoever signs in next.
final accountLinkProvider = Provider<AccountLink?>((ref) {
  final api = ref.watch(apiClientProvider);
  if (api == null) return null;
  final scope = ref.watch(accountScopeProvider);
  return AccountLink(
    api: api,
    store: ScopedLocalStore(ref.watch(localStoreProvider), scope),
    outbox: ref.watch(outboxProvider),
    userId: () => scope.userId,
    scope: scope,
  );
});

/// The link when [LiveFeature] runs on the API this launch, else null.
final liveLinkProvider = Provider.family<AccountLink?, LiveFeature>((
  ref,
  feature,
) {
  final link = ref.watch(accountLinkProvider);
  return link != null && ref.watch(backendProvider).isLive(feature)
      ? link
      : null;
});

/// Who is signed in, from `GET /me` while the profile runs live; null in
/// the preview and signed out. Each answer keeps the session's account id
/// and name in step with the account. No automatic retry: the next launch
/// or sign-in asks again.
final meProvider = FutureProvider<Me?>(retry: (_, _) => null, (ref) async {
  final link = ref.watch(liveLinkProvider(LiveFeature.profile));
  final signedIn = ref.watch(sessionProvider.select((s) => s.signedIn));
  if (link == null || !signedIn) return null;
  final me = await link.scope.guard(LiveAccount(link).me());
  final session = ref.read(sessionProvider);
  final notifier = ref.read(sessionProvider.notifier);
  if (me.id.isNotEmpty && me.id != session.userId) {
    await notifier.setUserId(me.id);
  }
  if (me.name.isNotEmpty && me.name != session.name) {
    await notifier.setName(me.name);
  }
  return me;
});
