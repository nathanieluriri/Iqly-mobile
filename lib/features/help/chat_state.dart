import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/deadline.dart';
import '../../core/session.dart';
import '../../data/help_data.dart';
import '../../data/help_service.dart';
import '../../data/local/local_rows.dart';
import '../../data/signed_in_files.dart';
import '../../data/support_files.dart' show SupportSource;
import 'help_state.dart';

/// The chat inbox as it shows: the threads ([tickets], null until the phone
/// or the API has any), how reading them again goes ([sync]), and whether
/// the first read failed with nothing to show ([failed]).
class HelpInbox {
  const HelpInbox({
    this.tickets,
    this.sync = HelpSync.idle,
    this.failed = false,
  });

  final List<HelpTicket>? tickets;
  final HelpSync sync;
  final bool failed;
}

/// The support inbox for the chat (B21 · Support): what the phone kept
/// shows at once, then the API's answer replaces it in place. A read that
/// fails over kept threads says so ([HelpSync.failed]) and keeps them.
class HelpInboxNotifier extends Notifier<HelpInbox> {
  int _reads = 0;

  @override
  HelpInbox build() {
    ref.watch(accountProvider);
    ref.watch(helpServiceProvider);
    return const HelpInbox();
  }

  /// Reads the inbox again; a [quiet] read says nothing until it fails.
  Future<void> refresh({bool quiet = false}) async {
    final scope = ref.read(accountScopeProvider);
    final service = ref.read(helpServiceProvider);
    final read = ++_reads;
    bool current() => ref.mounted && scope.open && read == _reads;
    if (state.tickets == null) {
      state = const HelpInbox();
      final kept = await service.keptConversations().catchError(
        (Object _) => null,
      );
      if (!current()) return;
      if (kept != null && state.tickets == null) {
        state = HelpInbox(tickets: kept, sync: HelpSync.updating);
      }
    } else if (!quiet) {
      state = HelpInbox(tickets: state.tickets, sync: HelpSync.updating);
    }
    try {
      final tickets = await service.conversations();
      if (current()) state = HelpInbox(tickets: tickets);
    } catch (_) {
      if (!current()) return;
      final shown = state.tickets;
      state = shown == null
          ? const HelpInbox(failed: true)
          : HelpInbox(tickets: shown, sync: HelpSync.failed);
    }
  }
}

final helpInboxProvider = NotifierProvider<HelpInboxNotifier, HelpInbox>(
  HelpInboxNotifier.new,
);

/// The inbox's rows with what this session knows newer of each thread (a
/// reply sent, a thread read or resolved), latest message first.
final helpInboxTicketsProvider = Provider<List<HelpTicket>?>((ref) {
  final rows = ref.watch(helpInboxProvider.select((inbox) => inbox.tickets));
  if (rows == null) return null;
  final known = ref.watch(helpTicketsProvider);
  final ids = {for (final row in rows) row.id};
  return [
    for (final row in rows) _newer(row, known[row.id]),
    for (final ticket in known.values)
      if (!ids.contains(ticket.id) && ticket.messages.isNotEmpty) ticket,
  ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
});

HelpTicket _newer(HelpTicket row, HelpTicket? known) =>
    known == null || known.updatedAt.isBefore(row.updatedAt) ? row : known;

/// A file going up to support for a message ([HelpService.upload]): the
/// [file] as picked, how far it is, the file as the API took it once
/// [done], or why it did not go.
class HelpUploadState {
  const HelpUploadState({
    required this.file,
    this.progress = 0,
    this.done,
    this.failed = false,
    this.failure,
  });

  final HelpAttachment file;
  final double progress;
  final HelpAttachment? done;
  final bool failed;

  /// Why the API refused it, or [HelpFailure.offline] without an answer.
  final HelpFailure? failure;

  /// Over the API's limits or not a kind it takes: sending again won't do.
  bool get refused =>
      failure == HelpFailure.tooLarge ||
      failure == HelpFailure.tooLong ||
      failure == HelpFailure.fileType;
}

/// The files going up for messages, by a key of their own. An upload lives
/// past the screen that picked it, so a message sent before its file is up
/// still goes once it is.
class HelpUploadsNotifier extends Notifier<Map<String, HelpUploadState>> {
  final _runs = <String, StreamSubscription<HelpUpload>>{};
  final _waiting = <String, List<Completer<HelpAttachment>>>{};

  @override
  Map<String, HelpUploadState> build() {
    ref.watch(accountProvider);
    ref.onDispose(() {
      for (final run in _runs.values) {
        run.cancel();
      }
      _runs.clear();
      _settleAll(const HelpRefused(HelpFailure.offline));
    });
    return const {};
  }

  /// Picks a file from [source] ([HelpService.addRecording], which names
  /// the preview's sample after [about]) and starts it up: the key it goes
  /// by, or null when the person backs out.
  Future<String?> pick(SupportSource source, {String? about}) {
    final key = LocalRows.newId();
    final picked = Completer<String?>();
    _follow(
      key,
      ref.read(helpServiceProvider).addRecording(about: about, source: source),
      picked: picked,
    );
    return picked.future;
  }

  /// Sends a failed upload up again.
  void retry(String key) {
    final upload = state[key];
    if (upload == null || !upload.failed) return;
    _follow(key, ref.read(helpServiceProvider).upload(upload.file));
  }

  void _follow(
    String key,
    Stream<HelpUpload> steps, {
    Completer<String?>? picked,
  }) {
    _runs.remove(key)?.cancel();
    HelpAttachment? file = state[key]?.file;
    void fail(HelpFailure failure) {
      final going = file;
      if (going == null) return;
      state = {
        ...state,
        key: HelpUploadState(file: going, failed: true, failure: failure),
      };
      _settle(key, error: HelpRefused(failure));
    }

    if (file != null) state = {...state, key: HelpUploadState(file: file)};
    _runs[key] = steps.listen(
      (step) {
        file ??= step.file;
        if (picked != null && !picked.isCompleted) picked.complete(key);
        state = {
          ...state,
          key: step.done
              ? HelpUploadState(file: file!, progress: 1, done: step.file)
              : HelpUploadState(file: file!, progress: step.progress),
        };
        if (step.done) _settle(key, done: step.file);
      },
      onError: (Object error) {
        _runs.remove(key);
        if (picked != null && !picked.isCompleted) picked.complete(null);
        fail(error is HelpRefused ? error.failure : HelpFailure.offline);
      },
      onDone: () {
        _runs.remove(key);
        if (picked != null && !picked.isCompleted) picked.complete(null);
        final upload = state[key];
        if (upload == null || upload.done != null || upload.failed) return;
        fail(HelpFailure.unknown);
      },
    );
  }

  /// The file as the API took it, once up; throws [HelpRefused] when it
  /// does not go.
  Future<HelpAttachment> uploaded(String key) {
    final upload = state[key];
    if (upload == null) {
      return Future.error(const HelpRefused(HelpFailure.gone));
    }
    if (upload.done case final done?) return Future.value(done);
    if (upload.failed) {
      return Future.error(HelpRefused(upload.failure ?? HelpFailure.unknown));
    }
    final waiting = Completer<HelpAttachment>();
    (_waiting[key] ??= []).add(waiting);
    return waiting.future;
  }

  void _settle(String key, {HelpAttachment? done, Object? error}) {
    for (final waiting in _waiting.remove(key) ?? const []) {
      if (done != null) {
        waiting.complete(done);
      } else {
        waiting.completeError(error ?? const HelpRefused(HelpFailure.unknown));
      }
    }
  }

  void _settleAll(Object error) {
    for (final key in [..._waiting.keys]) {
      _settle(key, error: error);
    }
  }

  /// Drops the upload: it stops, and the API forgets one already up.
  void cancel(String key) {
    _runs.remove(key)?.cancel();
    final upload = state[key];
    if (upload == null) return;
    state = {...state}..remove(key);
    _settle(key, error: const HelpRefused(HelpFailure.gone));
    if (upload.done case final done?) {
      ref.read(helpServiceProvider).discard(done).ignore();
    }
  }

  /// The upload went with its message.
  void sent(String key) {
    _runs.remove(key)?.cancel();
    if (state.containsKey(key)) state = {...state}..remove(key);
  }
}

final helpUploadsProvider =
    NotifierProvider<HelpUploadsNotifier, Map<String, HelpUploadState>>(
      HelpUploadsNotifier.new,
    );

/// A message the person sent that the API has not taken yet. It shows at
/// once at the end of its thread, its file from the phone, while the file
/// goes up ([upload]) and the message follows it.
class HelpOutgoing {
  const HelpOutgoing({
    required this.id,
    required this.key,
    required this.body,
    required this.at,
    this.file,
    this.upload,
    this.failed = false,
    this.failure,
  });

  final String id;

  /// The send's Idempotency-Key, kept until the API answers it for sure.
  final String key;
  final String body;
  final DateTime at;

  /// The file as picked, drawn from the phone.
  final HelpAttachment? file;

  /// The [HelpUploadsNotifier] key the file goes up by.
  final String? upload;
  final bool failed;
  final HelpFailure? failure;

  HelpOutgoing copyWith({
    String? key,
    bool? failed,
    HelpFailure? Function()? failure,
  }) => HelpOutgoing(
    id: id,
    key: key ?? this.key,
    body: body,
    at: at,
    file: file,
    upload: upload,
    failed: failed ?? this.failed,
    failure: failure == null ? this.failure : failure(),
  );
}

/// The messages on their way, by thread. Each goes once its file is up; one
/// that does not go stays, failed, to send again or remove.
class HelpOutgoingNotifier extends Notifier<Map<String, List<HelpOutgoing>>> {
  @override
  Map<String, List<HelpOutgoing>> build() {
    ref.watch(accountProvider);
    return const {};
  }

  /// Puts [body] at the end of [ticketId] now, with [file] going up as
  /// [upload], and sends it with [key] once the file is up.
  void send(
    String ticketId, {
    required String body,
    required String key,
    HelpAttachment? file,
    String? upload,
  }) {
    final out = HelpOutgoing(
      id: LocalRows.newId(),
      key: key,
      body: body,
      at: ref.read(clockProvider)(),
      file: file,
      upload: upload,
    );
    state = {
      ...state,
      ticketId: [...?state[ticketId], out],
    };
    unawaited(_deliver(ticketId, out.id));
  }

  /// Sends a failed message again, its file too when that did not go up.
  void retry(String ticketId, String id) {
    final out = _find(ticketId, id);
    if (out == null || !out.failed) return;
    final upload = out.upload;
    if (upload != null) ref.read(helpUploadsProvider.notifier).retry(upload);
    _update(
      ticketId,
      id,
      (o) => o.copyWith(failed: false, failure: () => null),
    );
    unawaited(_deliver(ticketId, id));
  }

  /// Drops a failed message and its file.
  void remove(String ticketId, String id) {
    final out = _find(ticketId, id);
    if (out == null) return;
    final upload = out.upload;
    if (upload != null) ref.read(helpUploadsProvider.notifier).cancel(upload);
    _drop(ticketId, id);
  }

  Future<void> _deliver(String ticketId, String id) async {
    final scope = ref.read(accountScopeProvider);
    final out = _find(ticketId, id);
    if (out == null) return;
    final uploads = ref.read(helpUploadsProvider.notifier);
    final upload = out.upload;
    try {
      final file = upload == null ? out.file : await uploads.uploaded(upload);
      if (!ref.mounted || !scope.open) return;
      final picked = out.file;
      if (upload != null && file != null && picked != null) {
        await _keepSent(picked, file);
      }
      await ref
          .read(helpTicketsProvider.notifier)
          .reply(
            ticketId,
            out.body,
            idempotencyKey: out.key,
            attachments: [?file],
          );
      if (!ref.mounted || !scope.open) return;
      if (upload != null) uploads.sent(upload);
      _drop(ticketId, id);
    } catch (error) {
      if (!ref.mounted || !scope.open) return;
      final failure = error is HelpRefused ? error.failure : null;
      _update(
        ticketId,
        id,
        (o) => o.copyWith(
          failed: true,
          failure: () => failure,
          key: failure == null || failure == HelpFailure.offline
              ? null
              : LocalRows.newId(),
        ),
      );
    }
  }

  /// A picture or voice note sent from this phone is kept under the id the
  /// API serves it by (its upload's) before the message lands, so the
  /// thread never downloads it again.
  Future<void> _keepSent(HelpAttachment picked, HelpAttachment sent) async {
    final files = ref.read(signedInFilesProvider);
    final id = sent.id;
    final read = picked.read;
    if (files == null || id == null || read == null) return;
    if (sent.kind == HelpAttachmentKind.video) return;
    try {
      await files.keep(
        userId: ref.read(sessionProvider).userId ?? '',
        id: id,
        name: sent.name,
        bytes: await read(),
      );
    } on Object {
      return;
    }
  }

  HelpOutgoing? _find(String ticketId, String id) =>
      state[ticketId]?.where((o) => o.id == id).firstOrNull;

  void _update(
    String ticketId,
    String id,
    HelpOutgoing Function(HelpOutgoing out) change,
  ) {
    final list = state[ticketId];
    if (list == null) return;
    state = {
      ...state,
      ticketId: [for (final o in list) o.id == id ? change(o) : o],
    };
  }

  void _drop(String ticketId, String id) {
    final list = [...?state[ticketId]]..removeWhere((o) => o.id == id);
    state = list.isEmpty
        ? ({...state}..remove(ticketId))
        : {...state, ticketId: list};
  }
}

final helpOutgoingProvider =
    NotifierProvider<HelpOutgoingNotifier, Map<String, List<HelpOutgoing>>>(
      HelpOutgoingNotifier.new,
    );

/// A file of a thread on the API, named by what the bubble and the viewer
/// both read it as. A picture comes down as soon as it shows ([auto]); a
/// recording or a voice note when it is played.
class HelpFileRef {
  const HelpFileRef({
    required this.id,
    required this.url,
    this.name = '',
    this.auto = false,
  });

  final String id;
  final String url;
  final String name;
  final bool auto;

  /// Null for a file the API does not serve (yet, or any more).
  static HelpFileRef? of(HelpAttachment file) {
    final id = file.id;
    final url = file.url;
    return id == null || url == null
        ? null
        : HelpFileRef(
            id: id,
            url: url.toString(),
            name: file.name,
            auto: file.kind == HelpAttachmentKind.image,
          );
  }

  @override
  bool operator ==(Object other) =>
      other is HelpFileRef &&
      other.id == id &&
      other.url == url &&
      other.name == name &&
      other.auto == auto;

  @override
  int get hashCode => Object.hash(id, url, name, auto);
}

enum HelpFileStatus { idle, loading, ready, failed }

/// A thread's file on the phone: [file] once there, [progress] while it
/// comes down (null until the API says its size), or that it did not.
class HelpFileState {
  const HelpFileState({
    this.status = HelpFileStatus.idle,
    this.file,
    this.progress,
  });

  final HelpFileStatus status;
  final File? file;
  final double? progress;
}

/// Brings a thread's file onto the phone once, with the session token
/// ([SignedInFiles]): the bubble and the viewer share it, a file already
/// there opens at once, and a picture seen before never downloads again.
/// [fetch] downloads, and runs again after a failure.
class HelpFileNotifier extends Notifier<HelpFileState> {
  HelpFileNotifier(this.of);

  final HelpFileRef of;

  @override
  HelpFileState build() {
    final files = ref.watch(signedInFilesProvider);
    if (files == null) {
      return const HelpFileState(status: HelpFileStatus.failed);
    }
    final kept = files.kept(userId: _user, id: of.id, name: of.name);
    if (kept != null) {
      return HelpFileState(status: HelpFileStatus.ready, file: kept);
    }
    if (of.auto) {
      scheduleMicrotask(() {
        if (ref.mounted && state.status == HelpFileStatus.idle) fetch();
      });
    }
    return const HelpFileState();
  }

  String get _user => ref.read(sessionProvider).userId ?? '';

  /// Downloads the file, unless it is there or on its way.
  Future<void> fetch() async {
    final files = ref.read(signedInFilesProvider);
    if (files == null) return;
    if (state.status == HelpFileStatus.loading ||
        state.status == HelpFileStatus.ready) {
      return;
    }
    state = const HelpFileState(status: HelpFileStatus.loading);
    try {
      final file = await files.fetch(
        userId: _user,
        id: of.id,
        url: of.url,
        name: of.name,
        onProgress: (progress) {
          if (ref.mounted && state.status == HelpFileStatus.loading) {
            state = HelpFileState(
              status: HelpFileStatus.loading,
              progress: progress,
            );
          }
        },
      );
      if (ref.mounted) {
        state = HelpFileState(status: HelpFileStatus.ready, file: file);
      }
    } on Object {
      if (ref.mounted) {
        state = const HelpFileState(status: HelpFileStatus.failed);
      }
    }
  }
}

final helpFileProvider = NotifierProvider.autoDispose
    .family<HelpFileNotifier, HelpFileState, HelpFileRef>(HelpFileNotifier.new);
