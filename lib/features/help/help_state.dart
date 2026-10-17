import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../../data/activations_data.dart';
import '../../data/help_data.dart';
import '../../data/help_service.dart';
import '../../data/models.dart';
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
    this.sending = false,
    this.failed = false,
    this.failure,
  });

  final String message;
  final HelpAttachment? recording;

  /// The recording going up, until it is ready.
  final HelpUpload? upload;

  /// A recording whose upload got no answer, to upload again.
  final HelpAttachment? unsent;

  /// Why the API refused the file picked last (its size, length or type).
  final HelpFailure? refused;
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
    bool? sending,
    bool? failed,
    HelpFailure? Function()? failure,
  }) => HelpDraft(
    message: message ?? this.message,
    recording: recording == null ? this.recording : recording(),
    upload: upload == null ? this.upload : upload(),
    unsent: unsent == null ? this.unsent : unsent(),
    refused: refused == null ? this.refused : refused(),
    sending: sending ?? this.sending,
    failed: failed ?? this.failed,
    failure: failure == null ? this.failure : failure(),
  );
}

/// The Help request (141:5818). It lives as long as the screen.
class HelpDraftNotifier extends Notifier<HelpDraft> {
  StreamSubscription<HelpUpload>? _upload;

  @override
  HelpDraft build() {
    ref.onDispose(() => _upload?.cancel());
    return const HelpDraft();
  }

  void write(String message) => state = state.copyWith(
    message: message,
    failed: false,
    failure: () => null,
  );

  /// Picks a recording of [about]'s app and uploads it
  /// (HelpService.addRecording).
  void addRecording({String? about}) {
    if (state.upload != null) return;
    _follow(ref.read(helpServiceProvider).addRecording(about: about));
  }

  /// Uploads again the recording whose upload got no answer.
  void retryUpload() {
    final file = state.unsent;
    if (file == null || state.upload != null) return;
    _follow(ref.read(helpServiceProvider).upload(file));
  }

  void _follow(Stream<HelpUpload> steps) {
    _upload?.cancel();
    state = state.copyWith(unsent: () => null, refused: () => null);
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
  final _open = <String>{};

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
  /// one that fails says so in [helpLoadFailedProvider].
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
          onError: (Object _) {
            _watching.remove(id)?.cancel();
            if (!state.containsKey(id)) failed.failed(id);
          },
          onDone: () => _watching.remove(id),
        );
  }

  /// A thread on screen, asked again when a push lands.
  void opened(String id) => _open.add(id);

  void closed(String id) => _open.remove(id);

  void refreshOpen() {
    for (final id in _open) {
      follow(id);
    }
  }

  /// The person opened [id]: on the API the badge counts it at once.
  Future<void> markRead(String id) async {
    final scope = ref.read(accountScopeProvider);
    await ref.read(helpServiceProvider).markRead(id);
    if (!scope.open || !ref.read(supportLiveProvider)) return;
    final ticket = state[id];
    if (ticket != null && ticket.unread) _put(ticket.copyWith(unread: false));
    ref.invalidate(supportUnreadProvider);
  }

  Future<void> reply(String id, String body) =>
      _putting(ref.read(helpServiceProvider).reply(id, body));

  Future<void> resolve(String id) =>
      _putting(ref.read(helpServiceProvider).resolve(id));

  Future<void> _putting(Future<HelpTicket> answer) async {
    final scope = ref.read(accountScopeProvider);
    final ticket = await answer;
    if (scope.open) _put(ticket);
  }

  void _put(HelpTicket ticket) {
    state = {...state, ticket.id: ticket};
    if (ticket.credit case final credit?) _credit(credit);
  }

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

/// The threads whose first read got no answer, so the thread can offer Try
/// again rather than stay blank.
class HelpLoadFailedNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    ref.watch(accountProvider);
    return const {};
  }

  void failed(String id) => state = {...state, id};

  void cleared(String id) {
    if (state.contains(id)) state = {...state}..remove(id);
  }
}

final helpLoadFailedProvider =
    NotifierProvider<HelpLoadFailedNotifier, Set<String>>(
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
