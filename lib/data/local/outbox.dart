import 'dart:async';
import 'dart:math';

import 'local_store.dart';

/// Sends one outbox item and says how it went.
typedef OutboxHandler = Future<OutboxResult> Function(OutboxItem item);

/// How a send went.
sealed class OutboxResult {
  const OutboxResult();

  /// The API took it. [serverRef] is the id it gave what it created.
  const factory OutboxResult.done([String? serverRef]) = OutboxDone;

  /// Not this time: send again [after] this long (the API's Retry-After),
  /// or after the backoff without one.
  const factory OutboxResult.retry({
    Duration? after,
    String? code,
    String? message,
  }) = OutboxRetry;

  /// Refused for good.
  const factory OutboxResult.fail(String code, [String? message]) = OutboxFail;

  /// The session has gone: the whole queue holds until [Outbox.resume].
  const factory OutboxResult.pauseForSignIn() = OutboxPaused.signIn;

  /// The account is closing: the whole queue holds until [Outbox.resume].
  const factory OutboxResult.pauseForClosing() = OutboxPaused.closing;

  /// The API wants a newer app: the whole queue holds until the updated app
  /// starts it again.
  const factory OutboxResult.pauseForUpgrade() = OutboxPaused.upgrade;
}

final class OutboxDone extends OutboxResult {
  const OutboxDone([this.serverRef]);

  final String? serverRef;

  @override
  bool operator ==(Object other) =>
      other is OutboxDone && other.serverRef == serverRef;

  @override
  int get hashCode => serverRef.hashCode;

  @override
  String toString() => 'OutboxResult.done($serverRef)';
}

final class OutboxRetry extends OutboxResult {
  const OutboxRetry({this.after, this.code, this.message});

  final Duration? after;
  final String? code;
  final String? message;

  @override
  bool operator ==(Object other) =>
      other is OutboxRetry &&
      other.after == after &&
      other.code == code &&
      other.message == message;

  @override
  int get hashCode => Object.hash(after, code, message);

  @override
  String toString() => 'OutboxResult.retry($after, $code, $message)';
}

final class OutboxFail extends OutboxResult {
  const OutboxFail(this.code, [this.message]);

  final String code;
  final String? message;

  @override
  bool operator ==(Object other) =>
      other is OutboxFail && other.code == code && other.message == message;

  @override
  int get hashCode => Object.hash(code, message);

  @override
  String toString() => 'OutboxResult.fail($code, $message)';
}

final class OutboxPaused extends OutboxResult {
  const OutboxPaused.signIn() : pause = OutboxPause.signIn;

  const OutboxPaused.closing() : pause = OutboxPause.closing;

  const OutboxPaused.upgrade() : pause = OutboxPause.upgrade;

  final OutboxPause pause;

  @override
  bool operator ==(Object other) =>
      other is OutboxPaused && other.pause == pause;

  @override
  int get hashCode => pause.hashCode;

  @override
  String toString() => 'OutboxResult.paused(${pause.name})';
}

/// Codes the outbox records besides the API's own.
abstract final class OutboxCodes {
  /// No answer from the API: no connection, or it timed out.
  static const network = 'NETWORK_ERROR';

  /// Still failing after [Outbox.maxFailures] sends in a row.
  static const expired = 'OUTBOX_EXPIRED';

  /// The handler threw instead of answering.
  static const crashed = 'HANDLER_ERROR';

  /// The phone could not record the API's answer, so the item goes again.
  static const storeError = 'STORE_ERROR';

  /// The item this one depends on was discarded.
  static const discarded = 'DEPENDENCY_DISCARDED';
}

/// How an API answer lands in the outbox. No answer, a timeout, 5xx and 429
/// are sent again ([retryAfter] first when the API gives one); 401 holds the
/// queue for sign-in, 403 ACCOUNT_CLOSING until the account is restored and
/// 426 until the app is updated; 409 SUBMISSION_DUPLICATE means an earlier
/// send already landed; any other 4xx fails with its [code], and anything
/// else is sent again. [serverRef] is the id the API answered, kept when the
/// write is done.
OutboxResult outboxResultFor({
  required int status,
  String? code,
  String? message,
  Duration? retryAfter,
  String? serverRef,
  bool networkError = false,
}) {
  if (networkError) {
    return OutboxResult.retry(code: OutboxCodes.network, message: message);
  }
  final reason = code ?? 'HTTP_$status';
  return switch (status) {
    >= 200 && < 300 => OutboxResult.done(serverRef),
    401 => const OutboxResult.pauseForSignIn(),
    403 when code == 'ACCOUNT_CLOSING' => const OutboxResult.pauseForClosing(),
    409 when code == 'SUBMISSION_DUPLICATE' => OutboxResult.done(serverRef),
    426 => const OutboxResult.pauseForUpgrade(),
    408 || 429 || >= 500 => OutboxResult.retry(
      after: retryAfter,
      code: reason,
      message: message,
    ),
    >= 400 => OutboxResult.fail(reason, message),
    _ => OutboxResult.retry(after: retryAfter, code: reason, message: message),
  };
}

/// The wait after the [failures]th failure in a row of an item: full
/// jitter, a random duration up to 2 s after the first, doubling with each
/// one after it, never more than [outboxLongestWait].
Duration outboxRetryDelay(int failures, Random random) {
  const first = Duration(seconds: 2);
  final doublings = min(max(failures - 1, 0), 20);
  final ceiling = min(
    first.inMicroseconds << doublings,
    outboxLongestWait.inMicroseconds,
  );
  return Duration(microseconds: (random.nextDouble() * ceiling).floor());
}

enum OutboxPause { signIn, closing, upgrade }

/// What screens show of the outbox.
class OutboxState {
  const OutboxState({this.pending = 0, this.failed = const [], this.pause});

  /// Writes still to send, the ones on their way included.
  final int pending;

  /// Writes refused or given up on, oldest first.
  final List<OutboxItem> failed;

  /// Why nothing goes out, while the queue waits for sign-in, for the
  /// account to be restored or for an app update.
  final OutboxPause? pause;
}

/// Sends the signed-in person's outbox while the app is open: from [start],
/// on [kick] (after each [enqueue], and when the app comes back) and when
/// the earliest retry is due. One item at a time, the oldest due first. An
/// item waits while the item it depends on is not done, and while an older
/// unsent item has its coalesce key; when an item fails, the items that
/// depend on it fail the same way. A send that outlasts [sendTimeout] stays
/// on its way while the rest of the queue goes on. Signing out is [stop],
/// then [LocalStore.wipeUser].
class Outbox {
  Outbox(
    this._store, {
    DateTime Function()? clock,
    Random? random,
    this.sendTimeout = const Duration(minutes: 2),
  }) : _clock = clock ?? DateTime.now,
       _random = random ?? Random();

  /// Items that fail this many sends in a row give up: about a day of
  /// trying while the app is open, once the waits reach
  /// [outboxLongestWait]. A pause starts the count again.
  static const maxFailures = 200;

  /// Done items stay this long, then go at the next launch.
  static const keepDone = Duration(days: 1);

  /// How long the queue waits for a send before it goes on with other
  /// items. The item stays on its way, and its key and its dependants keep
  /// waiting, until its handler answers; when it never does, the next
  /// launch sends it again under the same Idempotency-Key.
  final Duration sendTimeout;

  final LocalStore _store;
  final DateTime Function() _clock;
  final Random _random;
  final _handlers = <String, OutboxHandler>{};
  final _changes = StreamController<OutboxState>.broadcast();
  var _state = const OutboxState();
  String? _userId;
  OutboxPause? _pause;
  Future<void>? _recovery;
  Future<void>? _run;
  var _again = false;
  Duration? _wait;
  Timer? _timer;
  Completer<void>? _waiting;
  final _onTheirWay = <String, OutboxItem>{};

  // _generation tells a start still recovering that a later start or stop
  // overtook it. _epoch also moves on resume: a send picked in an older
  // epoch neither reaches its handler nor pauses the queue.
  var _generation = 0;
  var _epoch = 0;

  OutboxState get state => _state;

  /// The current state, then every change.
  Stream<OutboxState> watch() {
    late final StreamController<OutboxState> controller;
    StreamSubscription<OutboxState>? changes;
    controller = StreamController<OutboxState>(
      onListen: () {
        controller.add(_state);
        changes = _changes.stream.listen(
          controller.add,
          onDone: controller.close,
        );
      },
      onCancel: () => changes?.cancel(),
    );
    return controller.stream;
  }

  /// Sets how items of [kind] are sent. Items of a kind with no handler
  /// wait for one.
  void register(String kind, OutboxHandler handler) {
    _handlers[kind] = handler;
    if (_userId != null) unawaited(kick());
  }

  /// Queues a write (see [LocalStore.enqueue]). For the person whose queue
  /// runs, it goes as soon as it can.
  Future<OutboxItem> enqueue(
    String userId, {
    required String kind,
    required Map<String, Object?> payload,
    String? coalesceKey,
    OutboxMerge? merge,
    String? dependsOn,
    List<OutboxFile> files = const [],
  }) async {
    final item = await _store.enqueue(
      userId,
      kind: kind,
      payload: payload,
      coalesceKey: coalesceKey,
      merge: merge,
      dependsOn: dependsOn,
      files: files,
    );
    if (userId == _userId) {
      await _refresh();
      unawaited(kick());
    }
    return item;
  }

  /// Puts a failed item back in line, due now, with its run of failures
  /// ended, and with it the failed items it depends on, which go first.
  /// Answers whether it went back: an item that is not failed stays as it
  /// is, and so does one whose dependency was discarded.
  Future<bool> retry(String id) async {
    final chain = <OutboxItem>[];
    final seen = <String>{};
    for (String? next = id; next != null && seen.add(next);) {
      final item = await _store.outboxItem(next);
      if (item == null || item.status != OutboxStatus.failed) break;
      if (item.lastErrorCode == OutboxCodes.discarded) return false;
      chain.add(item);
      next = item.dependsOn;
    }
    if (chain.isEmpty) return false;
    for (final item in chain.reversed) {
      await _store.requeue(item.id);
    }
    await _refresh();
    unawaited(kick());
    return true;
  }

  /// Removes a pending or failed item and its files. The items that depend
  /// on it fail with [OutboxCodes.discarded]. Answers whether it went: an
  /// item on its way or done stays.
  Future<bool> discard(String id) async {
    final gone = await _store.discard(
      id,
      dependantsCode: OutboxCodes.discarded,
    );
    if (gone) {
      await _refresh();
      unawaited(kick());
    }
    return gone;
  }

  /// Runs [userId]'s queue, lifting any pause. The first start puts back in
  /// line what a killed app left sending and drops old done items; when that
  /// fails, the next start tries again. A send on its way for whoever ran
  /// before does not hold the queue up. Completes once nothing more can go
  /// for now.
  Future<void> start(String userId) async {
    final generation = ++_generation;
    _epoch++;
    // Cleared first, so the drain let go of below cannot step on for the
    // person before.
    _userId = null;
    _letGo();
    final recovery = _recovery ??= _recover();
    try {
      await recovery;
    } catch (_) {
      if (identical(_recovery, recovery)) _recovery = null;
      rethrow;
    }
    if (generation != _generation) return;
    _userId = userId;
    _pause = null;
    await _refresh();
    return kick();
  }

  Future<void> _recover() async {
    await _store.resetSending();
    await _store.pruneDone(_clock().subtract(keepDone));
  }

  /// Lifts a pause, after sign-in or once the account is restored. A send
  /// that began before this cannot pause the queue again.
  Future<void> resume() async {
    _epoch++;
    if (_pause != null) {
      _pause = null;
      await _refresh();
    }
    return kick();
  }

  /// Sends what is due. Completes once nothing more can go for now; a kick
  /// while sending joins the run under way.
  Future<void> kick() {
    if (_userId == null || _pause != null) return Future.value();
    if (_run case final run?) {
      _again = true;
      return run;
    }
    _timer?.cancel();
    return _run = _drain();
  }

  /// Stops sending and keeps every item. A send already on its way lands by
  /// itself and does not hold this up.
  Future<void> stop() async {
    _generation++;
    _epoch++;
    _letGo();
    _userId = null;
    _pause = null;
    _timer?.cancel();
    _publish(const OutboxState());
  }

  Future<void> dispose() async {
    await stop();
    await _changes.close();
  }

  Future<void> _drain() async {
    _wait = null;
    try {
      do {
        _again = false;
        while (await _step()) {}
      } while (_again);
    } catch (error, stack) {
      Zone.current.handleUncaughtError(error, stack);
    } finally {
      _run = null;
      _schedule();
    }
  }

  bool _current(String userId, int epoch) =>
      _userId == userId && _epoch == epoch;

  /// Sends one item, or fails one whose dependency failed. False when
  /// nothing can go now.
  Future<bool> _step() async {
    final userId = _userId;
    final epoch = _epoch;
    if (userId == null || _pause != null) return false;
    final open = await _store.outbox(userId);
    if (!_current(userId, epoch)) return true;
    final byId = {for (final item in open) item.id: item};
    for (final item in open) {
      final parent = byId[item.dependsOn];
      if (item.status == OutboxStatus.pending &&
          parent?.status == OutboxStatus.failed) {
        await _store.markFailed(
          item.id,
          code: parent!.lastErrorCode!,
          message: parent.lastErrorMessage,
        );
        await _refresh();
        return true;
      }
    }
    final now = _clock();
    final due = await _store.dueOutbox(userId, now);
    if (!_current(userId, epoch)) return true;
    for (final item in due) {
      if (_handlers.containsKey(item.kind) && !_waits(item, open, byId)) {
        await _send(item, epoch);
        return true;
      }
    }
    _wait = _nextWait(open, now);
    return false;
  }

  bool _waits(
    OutboxItem item,
    List<OutboxItem> open,
    Map<String, OutboxItem> byId,
  ) {
    final key = item.coalesceKey;
    if (key != null) {
      for (final other in open) {
        if (other.id == item.id) break;
        if (other.coalesceKey == key && _unsent(other)) return true;
      }
      // A send on its way holds its key even after a wipe took its row, so a
      // person who signs out and back in cannot overtake it.
      for (final other in _onTheirWay.values) {
        if (other.userId == item.userId && other.coalesceKey == key) {
          return true;
        }
      }
    }
    final parent = byId[item.dependsOn];
    return parent != null && _unsent(parent);
  }

  static bool _unsent(OutboxItem item) =>
      item.status == OutboxStatus.pending ||
      item.status == OutboxStatus.sending;

  /// How long until the first pending item may go, never longer than any
  /// wait set for it, so a clock set back does not stall the timer.
  Duration? _nextWait(List<OutboxItem> open, DateTime now) {
    Duration? wait;
    for (final item in open) {
      if (item.status != OutboxStatus.pending ||
          !_handlers.containsKey(item.kind)) {
        continue;
      }
      final until = item.dueAt(now).difference(now);
      if (until > Duration.zero && (wait == null || until < wait)) {
        wait = until;
      }
    }
    return wait;
  }

  /// Claims [due] and hands it to its handler, then waits for the answer
  /// to land: for at most [sendTimeout], and only until the queue stops or
  /// starts again.
  Future<void> _send(OutboxItem due, int epoch) async {
    final item = await _store.markSending(due.id);
    if (item == null) return;
    if (!_current(item.userId, epoch)) {
      await _store.markRetry(
        item.id,
        at: item.nextAttemptAt,
        code: item.lastErrorCode,
        message: item.lastErrorMessage,
        retryAfter: item.retryAfter,
        failures: item.failures,
        failingSince: item.failingSince,
      );
      return;
    }
    _onTheirWay[item.id] = item;
    var landed = false;
    final sent = _answer(item)
        .then((result) => _settle(item, result, epoch))
        .whenComplete(() {
          landed = true;
          _onTheirWay.remove(item.id);
        });
    final waiting = _waiting = Completer<void>();
    final timer = Timer(sendTimeout, () => _release(waiting));
    await Future.any([sent, waiting.future]);
    timer.cancel();
    if (identical(_waiting, waiting)) _waiting = null;
    if (!landed) unawaited(sent.then((_) => kick()));
  }

  /// Stops waiting for the send on its way. It keeps its item and lands by
  /// itself.
  void _letGo() {
    final waiting = _waiting;
    _waiting = null;
    if (waiting != null) _release(waiting);
  }

  static void _release(Completer<void> waiting) {
    if (!waiting.isCompleted) waiting.complete();
  }

  Future<OutboxResult> _answer(OutboxItem item) async {
    try {
      return await _handlers[item.kind]!(item);
    } catch (error) {
      return OutboxResult.retry(code: OutboxCodes.crashed, message: '$error');
    }
  }

  /// Lands a send's answer. When the store fails to take it, the item goes
  /// back in line after a backoff: its Idempotency-Key makes sending it again
  /// safe.
  Future<void> _settle(OutboxItem item, OutboxResult result, int epoch) async {
    try {
      await _land(item, result, epoch);
    } catch (error, stack) {
      final now = _clock();
      final failures = item.failures + 1;
      try {
        await _store.markRetry(
          item.id,
          at: now.add(outboxRetryDelay(failures, _random)),
          code: OutboxCodes.storeError,
          message: '$error',
          failures: failures,
          failingSince: item.failingSince ?? now,
        );
      } catch (_) {
        // The store takes nothing now: the item stays on its way until the
        // next launch puts it back in line.
        Zone.current.handleUncaughtError(error, stack);
      }
    }
    try {
      await _refresh();
    } catch (error, stack) {
      Zone.current.handleUncaughtError(error, stack);
    }
  }

  Future<void> _land(OutboxItem item, OutboxResult result, int epoch) async {
    final now = _clock();
    switch (result) {
      case OutboxDone(:final serverRef):
        await _store.markDone(item.id, serverRef: serverRef);
      case OutboxFail(:final code, :final message):
        await _store.markFailed(item.id, code: code, message: message);
      case OutboxRetry(:final after, :final code, :final message):
        // Read again: a pause while the send was out ended its run.
        final sent = await _store.outboxItem(item.id);
        if (sent == null) return;
        final failures = sent.failures + 1;
        if (failures >= maxFailures) {
          await _store.markFailed(
            item.id,
            code: OutboxCodes.expired,
            message: message ?? code,
          );
          return;
        }
        final asked = after != null && after > Duration.zero ? after : null;
        await _store.markRetry(
          item.id,
          at: now.add(asked ?? outboxRetryDelay(failures, _random)),
          code: code,
          message: message,
          retryAfter: asked,
          failures: failures,
          failingSince: sent.failingSince ?? now,
        );
      case OutboxPaused(:final pause):
        await _store.markRetry(
          item.id,
          at: now,
          code: switch (pause) {
            OutboxPause.signIn => 'UNAUTHORIZED',
            OutboxPause.closing => 'ACCOUNT_CLOSING',
            OutboxPause.upgrade => 'UPGRADE_REQUIRED',
          },
        );
        if (_current(item.userId, epoch)) {
          _pause = pause;
          await _store.resetFailures(item.userId);
        }
    }
  }

  Future<void> _refresh() async {
    final userId = _userId;
    if (userId == null) return;
    final open = await _store.outbox(userId);
    if (userId != _userId) return;
    _publish(
      OutboxState(
        pending: open.where((i) => i.status != OutboxStatus.failed).length,
        failed: [
          for (final item in open)
            if (item.status == OutboxStatus.failed) item,
        ],
        pause: _pause,
      ),
    );
  }

  void _publish(OutboxState state) {
    _state = state;
    if (!_changes.isClosed) _changes.add(state);
  }

  void _schedule() {
    _timer?.cancel();
    _timer = null;
    final wait = _wait;
    if (wait == null || _userId == null || _pause != null) return;
    _timer = Timer(wait, () => unawaited(kick()));
  }
}
