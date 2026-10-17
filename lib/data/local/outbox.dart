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

  /// Still not sent a day after it was queued.
  static const expired = 'OUTBOX_EXPIRED';

  /// The handler threw instead of answering.
  static const crashed = 'HANDLER_ERROR';
}

/// How an API answer lands in the outbox. No answer, a timeout, 5xx and 429
/// are sent again ([retryAfter] first when the API gives one); 401 holds the
/// queue for sign-in and 403 ACCOUNT_CLOSING until the account is restored;
/// 409 SUBMISSION_DUPLICATE means an earlier send already landed; any other
/// 4xx fails with its [code], and anything else is sent again. [serverRef]
/// is the id the API answered, kept when the write is done.
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
    408 || 429 || >= 500 => OutboxResult.retry(
      after: retryAfter,
      code: reason,
      message: message,
    ),
    >= 400 => OutboxResult.fail(reason, message),
    _ => OutboxResult.retry(after: retryAfter, code: reason, message: message),
  };
}

/// The wait after the [attempts]th send of an item failed: full jitter, a
/// random duration up to 2 s after the first failure, doubling with each
/// one after it, never more than 15 minutes.
Duration outboxRetryDelay(int attempts, Random random) {
  const first = Duration(seconds: 2);
  const most = Duration(minutes: 15);
  final doublings = min(max(attempts - 1, 0), 20);
  final ceiling = min(first.inMicroseconds << doublings, most.inMicroseconds);
  return Duration(microseconds: (random.nextDouble() * ceiling).floor());
}

enum OutboxPause { signIn, closing }

/// What screens show of the outbox.
class OutboxState {
  const OutboxState({this.pending = 0, this.failed = const [], this.pause});

  /// Writes still to send, the one on its way included.
  final int pending;

  /// Writes refused or given up on, oldest first.
  final List<OutboxItem> failed;

  /// Why nothing goes out, while the queue waits for sign-in or for the
  /// account to be restored.
  final OutboxPause? pause;
}

/// Sends the signed-in person's outbox while the app is open: from [start],
/// on [kick] (after each [enqueue], and when the app comes back) and when
/// the earliest retry is due. One item at a time, the oldest due first. An
/// item waits while the item it depends on is not done, and while an older
/// unsent item has its coalesce key; when an item fails, the items that
/// depend on it fail the same way. Signing out is [stop], then
/// [LocalStore.wipeUser].
class Outbox {
  Outbox(this._store, {DateTime Function()? clock, Random? random})
    : _clock = clock ?? DateTime.now,
      _random = random ?? Random();

  /// Items still failing this long after they were queued give up.
  static const giveUpAfter = Duration(hours: 24);

  /// Done items stay this long, then go at the next launch.
  static const keepDone = Duration(days: 1);

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
  DateTime? _wake;
  Timer? _timer;
  var _generation = 0;

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

  /// Runs [userId]'s queue, lifting any pause. The first start puts back in
  /// line what a killed app left sending and drops old done items.
  /// Completes once nothing more can go for now.
  Future<void> start(String userId) async {
    final generation = ++_generation;
    await (_recovery ??= _recover());
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

  /// Lifts a pause, after sign-in or once the account is restored.
  Future<void> resume() async {
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

  /// Stops sending and keeps every item. Completes once an item on its way
  /// has landed.
  Future<void> stop() async {
    _generation++;
    _userId = null;
    _pause = null;
    _timer?.cancel();
    _publish(const OutboxState());
    await _run;
  }

  Future<void> dispose() async {
    await stop();
    await _changes.close();
  }

  Future<void> _drain() async {
    _wake = null;
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

  /// Sends one item, or fails one whose dependency failed. False when
  /// nothing can go now.
  Future<bool> _step() async {
    final userId = _userId;
    if (userId == null || _pause != null) return false;
    final open = await _store.outbox(userId);
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
    for (final item in await _store.dueOutbox(userId, now)) {
      if (_handlers.containsKey(item.kind) && !_waits(item, open, byId)) {
        await _send(item);
        return true;
      }
    }
    _wake = _earliest(open, now);
    return false;
  }

  static bool _waits(
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
    }
    final parent = byId[item.dependsOn];
    return parent != null && _unsent(parent);
  }

  static bool _unsent(OutboxItem item) =>
      item.status == OutboxStatus.pending ||
      item.status == OutboxStatus.sending;

  DateTime? _earliest(List<OutboxItem> open, DateTime now) {
    DateTime? earliest;
    for (final item in open) {
      final at = item.nextAttemptAt;
      if (item.status == OutboxStatus.pending &&
          _handlers.containsKey(item.kind) &&
          at.isAfter(now) &&
          (earliest == null || at.isBefore(earliest))) {
        earliest = at;
      }
    }
    return earliest;
  }

  Future<void> _send(OutboxItem due) async {
    final item = await _store.markSending(due.id);
    if (item == null) return;
    OutboxResult result;
    try {
      result = await _handlers[item.kind]!(item);
    } catch (error) {
      result = OutboxResult.retry(code: OutboxCodes.crashed, message: '$error');
    }
    await _land(item, result);
    await _refresh();
  }

  Future<void> _land(OutboxItem item, OutboxResult result) async {
    final now = _clock();
    switch (result) {
      case OutboxDone(:final serverRef):
        await _store.markDone(item.id, serverRef: serverRef);
      case OutboxFail(:final code, :final message):
        await _store.markFailed(item.id, code: code, message: message);
      case OutboxRetry(:final code, :final message)
          when now.difference(item.createdAt) > giveUpAfter:
        await _store.markFailed(
          item.id,
          code: OutboxCodes.expired,
          message: message ?? code,
        );
      case OutboxRetry(:final after, :final code, :final message):
        final wait = after != null && after > Duration.zero
            ? after
            : outboxRetryDelay(item.attempts, _random);
        await _store.markRetry(
          item.id,
          at: now.add(wait),
          code: code,
          message: message,
        );
      case OutboxPaused(:final pause):
        await _store.markRetry(
          item.id,
          at: now,
          code: switch (pause) {
            OutboxPause.signIn => 'UNAUTHORIZED',
            OutboxPause.closing => 'ACCOUNT_CLOSING',
          },
        );
        if (item.userId == _userId) _pause = pause;
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
    final wake = _wake;
    if (wake == null || _userId == null || _pause != null) return;
    final wait = wake.difference(_clock());
    _timer = Timer(wait.isNegative ? Duration.zero : wait, () {
      unawaited(kick());
    });
  }
}
