import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/backend.dart';
import '../../core/session.dart';
import '../api_client.dart';
import '../local/local_store.dart';
import '../local/outbox.dart';
import 'live_account.dart';

/// The two lists of briefs the person marks that the API keeps for them
/// (contract 13.3): the Saved lens and Remind me.
enum BriefMark {
  saved(
    LiveFeature.savedBriefsSync,
    '/me/saved-briefs',
    'savedBriefs.put',
    'savedBriefs.delete',
  ),
  reminder(
    LiveFeature.closeRemindersSync,
    '/me/close-reminders',
    'closeReminders.put',
    'closeReminders.delete',
  );

  const BriefMark(this.feature, this.path, this.put, this.delete);

  final LiveFeature feature;
  final String path;

  /// The outbox kinds that mark and unmark a brief.
  final String put;
  final String delete;

  String coalesceKey(String briefId) => '$name:$briefId';

  String pathOf(String briefId) => '$path/${Uri.encodeComponent(briefId)}';
}

/// One mark's list on the API. A change queues in the outbox, so it is
/// kept on the phone until the API takes it and is safe to send again;
/// marking and unmarking the same brief before either goes folds into the
/// newest. A pull lays the changes still to go over the API's list, so a
/// change made on this phone wins until it is sent, and one made elsewhere
/// wins once it is the API's.
class BriefMarksSync {
  BriefMarksSync(this.link, this.mark);

  final AccountLink link;
  final BriefMark mark;

  /// [offsets] are a reminder's minutes before close.
  Future<void> set(String briefId, bool on, {List<int>? offsets}) async {
    if (!link.scope.open) throw const AccountChanged();
    final user = link.userId();
    if (user == null) return;
    await link.outbox.enqueue(
      user,
      kind: on ? mark.put : mark.delete,
      payload: {'challengeId': briefId, 'offsetsMinutes': ?offsets},
      coalesceKey: mark.coalesceKey(briefId),
    );
  }

  /// The briefs marked, newest first: the API's list with this phone's
  /// unsent changes laid over it. Throws when the API does not answer or
  /// refuses, so the phone keeps what it has.
  Future<List<String>> pull() async {
    final res = await link.scope.guard(link.api.get(mark.path));
    if (!res.ok) throw ApiRefused.of(res);
    final ids = <String>[
      for (final item in switch (res.data['items']) {
        final List<Object?> items => items,
        _ => const <Object?>[],
      })
        if (item is Map && item['challengeId'] is String)
          item['challengeId'] as String,
    ];
    final user = link.userId();
    if (user == null) return ids;
    for (final item in await link.store.outbox(user)) {
      if (item.status != OutboxStatus.pending &&
          item.status != OutboxStatus.sending) {
        continue;
      }
      final id = item.payload['challengeId'];
      if (id is! String) continue;
      if (item.kind == mark.put) {
        ids
          ..remove(id)
          ..insert(0, id);
      } else if (item.kind == mark.delete) {
        ids.remove(id);
      }
    }
    return ids;
  }
}

/// Sends the marks for the features [live] runs; the rest wait, kept.
/// [onRefused] hears a mark the API turned down for good (a brief gone or
/// closed, a list full), so the list can be pulled back into step.
void registerBriefMarkWrites(
  Outbox outbox,
  ApiClient api, {
  required bool Function(LiveFeature feature) live,
  void Function(BriefMark mark)? onRefused,
}) {
  for (final mark in BriefMark.values) {
    if (!live(mark.feature)) {
      outbox
        ..unregister(mark.put)
        ..unregister(mark.delete);
      continue;
    }
    for (final kind in [mark.put, mark.delete]) {
      outbox.register(kind, (item) async {
        final id = item.payload['challengeId'];
        if (id is! String) return const OutboxResult.fail('VALIDATION_ERROR');
        final ApiResponse res;
        try {
          res = await api.send(
            kind == mark.put ? 'PUT' : 'DELETE',
            mark.pathOf(id),
            body: kind == mark.put
                ? {'offsetsMinutes': ?item.payload['offsetsMinutes']}
                : null,
            idempotencyKey: item.id,
          );
        } on ApiUnreachable {
          return outboxResultFor(status: 0, networkError: true);
        }
        final result = outboxResultFor(
          status: res.status,
          code: res.code,
          message: res.message,
          retryAfter: res.retryAfter,
        );
        if (result is OutboxFail) onRefused?.call(mark);
        return result;
      });
    }
  }
}

/// [mark]'s list on the API while its feature runs live, else null: the
/// list then stays on the phone as before.
final briefMarksSyncProvider = Provider.family<BriefMarksSync?, BriefMark>((
  ref,
  mark,
) {
  final link = ref.watch(liveLinkProvider(mark.feature));
  return link == null ? null : BriefMarksSync(link, mark);
});
