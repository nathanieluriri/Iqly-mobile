import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/activations_data.dart';
import '../../data/help_data.dart';
import '../../data/help_service.dart';
import '../../data/models.dart';
import '../wallet/wallet_state.dart';

/// The title of a thread about [activation] ("Kudi Box activation" in the
/// frame), or the screen's own name without one.
String helpSubject(Activation? activation) =>
    activation == null ? 'Help' : '${activation.business} activation';

/// What the person is writing to support: the message, the optional
/// recording (or the one going up) and how sending went.
class HelpDraft {
  const HelpDraft({
    this.message = '',
    this.recording,
    this.upload,
    this.sending = false,
    this.failed = false,
  });

  final String message;
  final HelpAttachment? recording;

  /// The recording going up, until it is ready.
  final HelpUpload? upload;
  final bool sending;
  final bool failed;

  bool get canSend => message.trim().isNotEmpty && upload == null && !sending;

  HelpDraft copyWith({
    String? message,
    HelpAttachment? Function()? recording,
    HelpUpload? Function()? upload,
    bool? sending,
    bool? failed,
  }) => HelpDraft(
    message: message ?? this.message,
    recording: recording == null ? this.recording : recording(),
    upload: upload == null ? this.upload : upload(),
    sending: sending ?? this.sending,
    failed: failed ?? this.failed,
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

  void write(String message) =>
      state = state.copyWith(message: message, failed: false);

  /// Picks a recording of [about]'s app and uploads it
  /// (HelpService.addRecording).
  void addRecording({String? about}) {
    if (state.upload != null) return;
    _upload?.cancel();
    _upload = ref
        .read(helpServiceProvider)
        .addRecording(about: about)
        .listen(
          (step) => state = step.done
              ? state.copyWith(recording: () => step.file, upload: () => null)
              : state.copyWith(upload: () => step),
          onError: (Object _) => state = state.copyWith(upload: () => null),
          onDone: () {
            if (state.upload != null) {
              state = state.copyWith(upload: () => null);
            }
          },
        );
  }

  void removeRecording() => state = state.copyWith(recording: () => null);

  /// Sends the draft about [subject], the [activation] it names if any;
  /// the new ticket, or null when it did not go.
  Future<HelpTicket?> send(String subject, {Activation? activation}) async {
    final draft = state;
    if (!draft.canSend) return null;
    state = draft.copyWith(sending: true, failed: false);
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
    } catch (_) {
      state = state.copyWith(sending: false, failed: true);
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
/// the thread's updated balance and the Wallet foot.
class HelpTicketsNotifier extends Notifier<Map<String, HelpTicket>> {
  final _watching = <String, StreamSubscription<HelpTicket>>{};

  @override
  Map<String, HelpTicket> build() {
    ref.onDispose(() {
      for (final watch in _watching.values) {
        watch.cancel();
      }
      _watching.clear();
    });
    return const {};
  }

  Future<HelpTicket> open(HelpRequest request) async {
    final ticket = await ref.read(helpServiceProvider).send(request);
    _put(ticket);
    follow(ticket.id);
    return ticket;
  }

  /// Keeps [id] up to date with what support does.
  void follow(String id) {
    if (_watching.containsKey(id)) return;
    _watching[id] = ref.read(helpServiceProvider).watch(id).listen(_put);
  }

  Future<void> reply(String id, String body) async =>
      _put(await ref.read(helpServiceProvider).reply(id, body));

  Future<void> resolve(String id) async =>
      _put(await ref.read(helpServiceProvider).resolve(id));

  void _put(HelpTicket ticket) {
    state = {...state, ticket.id: ticket};
    if (ticket.credit case final credit?) _credit(credit);
  }

  Future<void> _credit(LedgerEntry award) async {
    try {
      await ref.read(walletProvider.future);
    } catch (_) {
      return;
    }
    ref.read(walletProvider.notifier).credit(award);
  }
}

final helpTicketsProvider =
    NotifierProvider<HelpTicketsNotifier, Map<String, HelpTicket>>(
      HelpTicketsNotifier.new,
    );
