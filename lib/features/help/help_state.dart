import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../../data/activations_data.dart';
import '../../data/help_data.dart';
import '../../data/help_service.dart';
import '../../data/local/local_rows.dart';
import '../../data/models.dart';
import '../../data/support_files.dart' show SupportSource;
import '../wallet/wallet_state.dart';

/// The title of a thread about [activation] ("Kudi Box activation" in the
/// frame), or the screen's own name without one.
String helpSubject(Activation? activation) =>
    activation == null ? 'Help' : '${activation.business} activation';

/// A send to support that did not go, in the words the app already uses:
/// no answer is [offline]'s, a throttle asks for a minute, anything the API
/// refused is a plain "Couldn’t send."
String helpFailureText(
  HelpFailure? failure, {
  String offline = 'Couldn’t send. Check your connection.',
}) => switch (failure) {
  null || HelpFailure.offline => offline,
  HelpFailure.tooManyTries => 'Too many tries. Wait a minute, then try again.',
  _ => 'Couldn’t send.',
};

/// A file the API refused, in words from the limits of its kind (contract
/// 12.1): a recording over a minute keeps the ProofTile's own copy.
({String? title, String hint}) helpRefusalWords(
  HelpFailure failure,
  HelpAttachmentKind? kind,
) => switch (kind ?? HelpAttachmentKind.video) {
  HelpAttachmentKind.image => (
    title: failure == HelpFailure.tooLarge
        ? 'That picture is over 10 MB'
        : 'That picture can’t be sent',
    hint: 'Pictures go up to 10 MB: JPG, PNG, WebP or GIF.',
  ),
  HelpAttachmentKind.audio => (
    title: switch (failure) {
      HelpFailure.tooLong => 'That voice note is over 5 minutes',
      HelpFailure.tooLarge => 'That voice note is over 10 MB',
      _ => 'That voice note can’t be sent',
    },
    hint:
        'Voice notes go up to 5 minutes and 10 MB: M4A, AAC, MP3, OGG, WAV '
        'or AMR.',
  ),
  HelpAttachmentKind.video => switch (failure) {
    HelpFailure.tooLong => (title: null, hint: ''),
    HelpFailure.tooLarge => (
      title: 'That recording is over 50 MB',
      hint: 'Videos go up to 60 s and 50 MB: MP4, MOV, WebM or 3GP.',
    ),
    _ => (
      title: 'That video can’t be sent',
      hint: 'Videos go up to 60 s and 50 MB: MP4, MOV, WebM or 3GP.',
    ),
  },
};

/// What the person is writing to support: the message, the optional
/// recording (or the one going up, or the one whose upload did not go) and
/// how sending went.
class HelpDraft {
  const HelpDraft({
    this.message = '',
    this.recording,
    this.upload,
    this.unsent,
    this.refused,
    this.refusedKind,
    this.sending = false,
    this.failed = false,
    this.failure,
    this.key,
  });

  final String message;
  final HelpAttachment? recording;

  /// The recording going up, until it is ready.
  final HelpUpload? upload;

  /// A recording whose upload got no answer, to upload again.
  final HelpAttachment? unsent;

  /// Why the API refused the file picked last (its size, length or type),
  /// and what kind of file it was.
  final HelpFailure? refused;
  final HelpAttachmentKind? refusedKind;

  /// The Idempotency-Key the send carries, kept until the API answers it
  /// for sure.
  final String? key;
  final bool sending;
  final bool failed;

  /// Why the send did not go, when the API said.
  final HelpFailure? failure;

  bool get canSend =>
      message.trim().isNotEmpty && upload == null && unsent == null && !sending;

  HelpDraft copyWith({
    String? message,
    HelpAttachment? Function()? recording,
    HelpUpload? Function()? upload,
    HelpAttachment? Function()? unsent,
    HelpFailure? Function()? refused,
    HelpAttachmentKind? Function()? refusedKind,
    bool? sending,
    bool? failed,
    HelpFailure? Function()? failure,
    String? key,
  }) => HelpDraft(
    message: message ?? this.message,
    recording: recording == null ? this.recording : recording(),
    upload: upload == null ? this.upload : upload(),
    unsent: unsent == null ? this.unsent : unsent(),
    refused: refused == null ? this.refused : refused(),
    refusedKind: refusedKind == null ? this.refusedKind : refusedKind(),
    sending: sending ?? this.sending,
    failed: failed ?? this.failed,
    failure: failure == null ? this.failure : failure(),
    key: key ?? this.key,
  );
}

/// The Help request (141:5818). It lives as long as the screen.
class HelpDraftNotifier extends Notifier<HelpDraft> {
  StreamSubscription<HelpUpload>? _upload;

  @override
  HelpDraft build() {
    ref.onDispose(() => _upload?.cancel());
    return HelpDraft(key: LocalRows.newId());
  }

  void write(String message) => state = state.copyWith(
    message: message,
    failed: false,
    failure: () => null,
  );

  /// Picks a recording of [about]'s app and uploads it
  /// (HelpService.addRecording).
  void addRecording({
    String? about,
    SupportSource source = SupportSource.photos,
  }) {
    if (state.upload != null) return;
    _follow(
      ref.read(helpServiceProvider).addRecording(about: about, source: source),
    );
  }

  /// Uploads again the recording whose upload got no answer.
  void retryUpload() {
    final file = state.unsent;
    if (file == null || state.upload != null) return;
    _follow(ref.read(helpServiceProvider).upload(file));
  }

  void _follow(Stream<HelpUpload> steps) {
    _upload?.cancel();
    state = state.copyWith(
      unsent: () => null,
      refused: () => null,
      refusedKind: () => null,
    );
    HelpAttachment? going;
    _upload = steps.listen(
      (step) {
        going = step.file;
        state = step.done
            ? state.copyWith(recording: () => step.file, upload: () => null)
            : state.copyWith(upload: () => step);
      },
      onError: (Object error) {
        final refused = error is HelpRefused && error.refusesFile
            ? error.failure
            : null;
        final file = going;
        state = state.copyWith(
          upload: () => null,
          refused: () => refused,
          refusedKind: () => file?.kind,
          unsent: () => refused == null ? file : null,
        );
      },
      onDone: () {
        if (state.upload != null) {
          state = state.copyWith(upload: () => null);
        }
      },
    );
  }

  /// Drops the recording, uploaded or not; the API forgets an upload that
  /// was never sent.
  void removeRecording() {
    final recording = state.recording;
    state = state.copyWith(recording: () => null, unsent: () => null);
    if (recording != null) {
      ref.read(helpServiceProvider).discard(recording).ignore();
    }
  }

  /// Sends the draft about [subject], the [activation] it names if any;
  /// the new ticket, or null when it did not go.
  Future<HelpTicket?> send(String subject, {Activation? activation}) async {
    final draft = state;
    if (!draft.canSend) return null;
    state = draft.copyWith(sending: true, failed: false, failure: () => null);
    try {
      final ticket = await ref
          .read(helpTicketsProvider.notifier)
          .open(
            HelpRequest(
              subject: subject,
              message: draft.message.trim(),
              attachment: draft.recording,
              activation: activation,
              idempotencyKey: draft.key,
            ),
          );
      state = state.copyWith(sending: false);
      return ticket;
    } catch (error) {
      final failure = error is HelpRefused ? error.failure : null;
      final upload =
          error is HelpRefused &&
          (error.code == 'SUPPORT_UPLOAD_NOT_FOUND' ||
              error.code == 'SUPPORT_UPLOAD_IN_USE');
      state = state.copyWith(
        sending: false,
        failed: true,
        failure: () => failure,
        recording: upload ? () => null : null,
        key: failure == HelpFailure.offline || failure == null
            ? null
            : LocalRows.newId(),
      );
      return null;
    }
  }
}

final helpDraftProvider =
    NotifierProvider.autoDispose<HelpDraftNotifier, HelpDraft>(
      HelpDraftNotifier.new,
    );

/// The help threads of this session, kept up to date while support answers
/// them. A reply that credits a reward puts it on the wallet's ledger, so
/// the thread's updated balance and the Wallet foot. An answer that lands
/// once its account is no longer signed in goes nowhere.
class HelpTicketsNotifier extends Notifier<Map<String, HelpTicket>> {
  final _watching = <String, StreamSubscription<HelpTicket>>{};

  /// The threads on screen, and whether each has been marked read since.
  final _open = <String, bool>{};

  @override
  Map<String, HelpTicket> build() {
    ref.watch(accountProvider);
    ref.onDispose(() {
      for (final watch in _watching.values) {
        watch.cancel();
      }
      _watching.clear();
    });
    return const {};
  }

  Future<HelpTicket> open(HelpRequest request) async {
    final scope = ref.read(accountScopeProvider);
    final ticket = await ref.read(helpServiceProvider).send(request);
    if (scope.open) {
      _put(ticket);
      follow(ticket.id);
    }
    return ticket;
  }

  /// Keeps [id] up to date with what support does. A watch that ends (the
  /// API's answers each end with the thread as it is) can be asked again;
  /// one that fails says so in [helpLoadFailedProvider], as gone when the
  /// API has no such thread.
  void follow(String id) {
    if (_watching.containsKey(id)) return;
    final failed = ref.read(helpLoadFailedProvider.notifier);
    _watching[id] = ref
        .read(helpServiceProvider)
        .watch(id)
        .listen(
          (ticket) {
            failed.cleared(id);
            _put(ticket);
          },
          onError: (Object error) {
            _watching.remove(id)?.cancel();
            final gone =
                error is HelpRefused && error.failure == HelpFailure.gone;
            if (gone || !state.containsKey(id)) failed.failed(id, gone: gone);
          },
          onDone: () => _watching.remove(id),
        );
  }

  /// A thread on screen, asked again when a push lands. Once the screen has
  /// marked it read, a reply that lands while it is open is marked read too.
  void opened(String id) => _open[id] = false;

  void closed(String id) => _open.remove(id);

  void refreshOpen() {
    for (final id in _open.keys) {
      follow(id);
    }
  }

  /// The person opened [id]: on the API the badge counts it at once.
  Future<void> markRead(String id) async {
    final scope = ref.read(accountScopeProvider);
    if (_open.containsKey(id)) _open[id] = true;
    await ref.read(helpServiceProvider).markRead(id);
    if (!scope.open || !ref.read(supportLiveProvider)) return;
    final ticket = state[id];
    if (ticket != null && ticket.unread) _put(ticket.copyWith(unread: false));
    ref.invalidate(supportUnreadProvider);
  }

  Future<void> reply(String id, String body, {String? idempotencyKey}) =>
      _putting(
        ref
            .read(helpServiceProvider)
            .reply(id, body, idempotencyKey: idempotencyKey),
      );

  Future<void> resolve(String id) =>
      _putting(ref.read(helpServiceProvider).resolve(id));

  Future<void> _putting(Future<HelpTicket> answer) async {
    final scope = ref.read(accountScopeProvider);
    final ticket = await answer;
    if (scope.open) _put(ticket);
  }

  void _put(HelpTicket ticket) {
    final before = state[ticket.id];
    state = {...state, ticket.id: ticket};
    if (ticket.credit case final credit?) _credit(credit);
    // Support wrote again while the thread is open and already read.
    if (ticket.unread &&
        before != null &&
        _open[ticket.id] == true &&
        _replies(ticket) > _replies(before) &&
        ref.read(supportLiveProvider)) {
      markRead(ticket.id).catchError((Object _) {});
    }
  }

  static int _replies(HelpTicket ticket) =>
      ticket.messages.where((m) => m.author == HelpAuthor.support).length;

  Future<void> _credit(LedgerEntry award) async {
    final scope = ref.read(accountScopeProvider);
    try {
      await ref.read(walletProvider.future);
    } catch (_) {
      return;
    }
    if (scope.open) ref.read(walletProvider.notifier).credit(award);
  }
}

/// The threads whose read did not answer them, each true when the API has
/// no such thread (gone) and false when it gave no answer, so the thread
/// says it is gone or offers Try again rather than stay blank.
class HelpLoadFailedNotifier extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() {
    ref.watch(accountProvider);
    return const {};
  }

  void failed(String id, {bool gone = false}) => state = {...state, id: gone};

  void cleared(String id) {
    if (state.containsKey(id)) state = {...state}..remove(id);
  }
}

final helpLoadFailedProvider =
    NotifierProvider<HelpLoadFailedNotifier, Map<String, bool>>(
      HelpLoadFailedNotifier.new,
    );

final helpTicketsProvider =
    NotifierProvider<HelpTicketsNotifier, Map<String, HelpTicket>>(
      HelpTicketsNotifier.new,
    );

/// The one support inbox (B21 · Support, 485:39190): every conversation,
/// latest message first, refreshed whenever a thread of this session moves.
/// No automatic retry: the inbox offers Try again.
final conversationsProvider = FutureProvider.autoDispose<List<HelpTicket>>(
  retry: (_, _) => null,
  (ref) {
    ref.watch(helpTicketsProvider);
    return ref.watch(helpServiceProvider).conversations();
  },
);

/// The threads with a reply not yet opened, for the badges: only while
/// support runs on the API (the preview draws none), counted again as the
/// threads of this session move. Without an answer, none.
final supportUnreadProvider = FutureProvider.autoDispose<int>(
  retry: (_, _) => null,
  (ref) async {
    if (!ref.watch(supportLiveProvider)) return 0;
    ref.watch(helpTicketsProvider);
    try {
      return await ref.watch(helpServiceProvider).unread();
    } on Exception {
      return 0;
    }
  },
);
