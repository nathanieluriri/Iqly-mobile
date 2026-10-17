import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/backend.dart';
import '../../core/session.dart';
import '../../data/activations_data.dart';
import '../../data/activations_service.dart';
import '../../data/api_client.dart';
import '../../data/live/live_repository.dart' show liveModeProvider;
import '../../data/media_service.dart';
import '../../data/models.dart';
import '../wallet/wallet_state.dart';

/// The activations and your progress on each, kept for the session so the
/// list opens at once the second time. Changes the service pushes land here
/// as they happen. A reward that gets paid is credited to the wallet as a
/// ledger award with the activation's [Activation.creditId], so it counts
/// once whoever pays it. The wallet foots: DemoData's ledger (₦15,000.00 available, ₦65,000.00 earned,
/// designer answer 6) plus the reward (₦1,500 makes ₦16,500.00 and
/// ₦66,500.00; the B8 · Reward · credited frame still reads the older
/// ₦14,000.00). The live API credits the ledger itself, so a live payment
/// reads the wallet again instead.
class ActivationsNotifier extends AsyncNotifier<List<Activation>> {
  @override
  Future<List<Activation>> build() async {
    final service = ref.watch(activationsServiceProvider);
    final changes = service.changes().listen(_land);
    ref.onDispose(changes.cancel);
    return service.activations();
  }

  ActivationsService get _service => ref.read(activationsServiceProvider);

  void retry() => ref.invalidateSelf();

  /// Reads the list again behind what shows (a live screen opening, a push,
  /// a return to Discover); a failure keeps it. The preview's list is the
  /// session's own and never reads again.
  Future<void> refreshQuietly() async {
    if (!state.hasValue || !ref.read(_liveProvider)) return;
    final scope = ref.read(accountScopeProvider);
    final List<Activation> fresh;
    try {
      fresh = await _service.activations();
    } on Object {
      return;
    }
    if (!ref.mounted || !scope.open) return;
    final before = {
      for (final a in state.value ?? const <Activation>[]) a.id: a,
    };
    final listed = {for (final a in fresh) a.id};
    state = AsyncData([
      ...fresh,
      for (final id in _brought)
        if (!listed.contains(id)) ?before[id],
    ]);
    if (fresh.any((a) => a.credited && !(before[a.id]?.credited ?? true))) {
      _readWallet();
    }
  }

  /// Reads [id] again behind what shows, quietly, in a live launch, once
  /// the list is in: a screen opened from a link brings its activation into
  /// the list this way.
  Future<void> refreshOneQuietly(String id) async {
    if (!ref.read(_liveProvider)) return;
    try {
      await future;
      await refresh(id);
    } on Object {
      return;
    }
  }

  Future<void> start(String id) => _landing(_service.start(id));

  Future<void> refresh(String id) => _landing(_service.refresh(id));

  Future<void> sendProof(
    String id, {
    required int step,
    required String uploadId,
    required ProofVideo video,
    String phone = '',
    String note = '',
  }) => _landing(
    _service.sendProof(
      id,
      step: step,
      uploadId: uploadId,
      video: video,
      phone: phone,
      note: note,
    ),
  );

  /// Lands [answer] while its account is still the one signed in.
  Future<void> _landing(Future<Activation> answer) async {
    final scope = ref.read(accountScopeProvider);
    final activation = await answer;
    if (scope.open) _land(activation);
  }

  /// Opened from a link and not in the list (a paused one, say): kept
  /// through a fresh list, so its screen never empties.
  final _brought = <String>{};

  void _land(Activation activation) {
    final list = state.value;
    if (!ref.mounted || list == null) return;
    final before = list.where((a) => a.id == activation.id).firstOrNull;
    if (before == null) _brought.add(activation.id);
    state = AsyncData([
      for (final a in list) a.id == activation.id ? activation : a,
      if (before == null) activation,
    ]);
    if (activation.credited && !(before?.credited ?? false)) {
      _credit(activation);
    }
  }

  void _readWallet() {
    if (ref.exists(walletProvider)) {
      ref.read(walletProvider.notifier).refreshQuietly().ignore();
    }
  }

  Future<void> _credit(Activation activation) async {
    if (activation.live) {
      _readWallet();
      return;
    }
    final scope = ref.read(accountScopeProvider);
    try {
      await ref.read(walletProvider.future);
    } on Object {
      return;
    }
    if (!ref.mounted || !scope.open) return;
    ref
        .read(walletProvider.notifier)
        .credit(
          LedgerEntry(
            id: activation.creditId,
            type: LedgerType.award,
            amountKobo: activation.rewardKobo,
            createdAt: activation.progress!.paidAt!,
            business: activation.business,
            note: 'activation',
          ),
        );
  }
}

final _liveProvider = Provider<bool>(
  (ref) => ref.watch(liveModeProvider).isLive(LiveFeature.activations),
);

/// No automatic retry: the failed state offers "Try again".
final activationsProvider =
    AsyncNotifierProvider<ActivationsNotifier, List<Activation>>(
      ActivationsNotifier.new,
      retry: (_, _) => null,
    );

/// One activation, or null while the list loads.
final activationProvider = Provider.family<Activation?, String>(
  (ref, id) => ref
      .watch(activationsProvider)
      .value
      ?.where((a) => a.id == id)
      .firstOrNull,
);

enum ProofStage {
  /// Nothing picked: the ProofTile.
  none,

  /// The pick runs over [ActivationRules.proofLength] or
  /// [ActivationRules.proofBytes]: refused before it uploads, or by the
  /// API as it lands.
  refused,
  uploading,
  ready,
  failed,
}

/// The API's codes for a run that can take no proof any more: the
/// activation closed or went, the run ended or was paid, or never started.
/// Sending again can only be refused again.
bool activationRunEnded(String? code) => switch (code) {
  'ACTIVATION_CLOSED' ||
  'ACTIVATION_NOT_FOUND' ||
  'ACTIVATION_NOT_STARTED' ||
  'ACTIVATION_COMPLETION_PAID' ||
  'ACTIVATION_COMPLETION_EXPIRED' => true,
  _ => false,
};

/// Why a recording was refused.
enum ProofRefusal {
  length,
  size,

  /// Not a video the API takes (415 FILE_TYPE_NOT_ALLOWED): no frame words
  /// it, so the polaroid's Failed and Retry say it alone.
  kind,

  /// The run can take no proof any more ([activationRunEnded]).
  ended,

  /// The account is closing, so it takes no uploads.
  closing;

  static ProofRefusal of(ProofVideo video) =>
      video.tooLong ? ProofRefusal.length : ProofRefusal.size;

  /// What the API's refusal of an upload means, null for one that sending
  /// again can fix (a throttle, a fault on the API's side).
  static ProofRefusal? fromCode(String? code) => switch (code) {
    'VIDEO_TOO_LONG' => ProofRefusal.length,
    'FILE_TOO_LARGE' => ProofRefusal.size,
    'FILE_TYPE_NOT_ALLOWED' => ProofRefusal.kind,
    'ACCOUNT_CLOSING' => ProofRefusal.closing,
    _ when activationRunEnded(code) => ProofRefusal.ended,
    _ => null,
  };
}

/// The proof being put together on B9 · Upload proof, kept while you step
/// back to the activation and return.
class ProofDraft {
  const ProofDraft({
    this.stage = ProofStage.none,
    this.video,
    this.progress = 0,
    this.uploadId,
    this.phone = '',
    this.note = '',
    this.refusal,
  });

  final ProofStage stage;
  final ProofVideo? video;
  final double progress;
  final String? uploadId;
  final String phone;
  final String note;

  /// Set while [stage] is [ProofStage.refused].
  final ProofRefusal? refusal;

  /// A recording sits in the slot.
  bool get hasVideo => stage != ProofStage.none;

  ProofDraft copyWith({
    ProofStage? stage,
    ProofVideo? video,
    double? progress,
    String? Function()? uploadId,
    String? phone,
    String? note,
    ProofRefusal? refusal,
  }) {
    final next = stage ?? this.stage;
    return ProofDraft(
      stage: next,
      video: video ?? this.video,
      progress: progress ?? this.progress,
      uploadId: uploadId == null ? this.uploadId : uploadId(),
      phone: phone ?? this.phone,
      note: note ?? this.note,
      refusal: next == ProofStage.refused ? refusal ?? this.refusal : null,
    );
  }
}

class ProofDraftNotifier extends Notifier<ProofDraft> {
  ProofDraftNotifier(this.id);

  final String id;
  StreamSubscription<ProofUpload>? _upload;

  @override
  ProofDraft build() {
    ref.watch(accountProvider);
    ref.onDispose(() => _upload?.cancel());
    return const ProofDraft();
  }

  /// Opens the picker; a recording over a limit is refused, any other
  /// starts uploading.
  Future<void> pick() async {
    final scope = ref.read(accountScopeProvider);
    final video = await ref
        .read(mediaServiceProvider)
        .pickVideo(about: ref.read(activationProvider(id))?.business);
    if (!ref.mounted || !scope.open || video == null) return;
    if (video.refused) {
      state = state.copyWith(
        stage: ProofStage.refused,
        video: video,
        uploadId: () => null,
        refusal: ProofRefusal.of(video),
      );
      return;
    }
    _send(video);
  }

  void retry() {
    final video = state.video;
    if (video != null && !video.refused) _send(video);
  }

  void _send(ProofVideo video) {
    _upload?.cancel();
    state = state.copyWith(
      stage: ProofStage.uploading,
      video: video,
      progress: 0,
      uploadId: () => null,
    );
    _upload = ref
        .read(activationsServiceProvider)
        .upload(id, video)
        .listen(
          (upload) => state = state.copyWith(
            stage: upload.id == null ? ProofStage.uploading : ProofStage.ready,
            progress: upload.progress,
            uploadId: () => upload.id,
          ),
          onError: (Object error) {
            final refusal = error is ApiRefused
                ? ProofRefusal.fromCode(error.code)
                : null;
            state = state.copyWith(
              stage: refusal == null ? ProofStage.failed : ProofStage.refused,
              refusal: refusal,
            );
            if (refusal == ProofRefusal.ended) {
              ref
                  .read(activationsProvider.notifier)
                  .refreshOneQuietly(id)
                  .ignore();
            }
          },
        );
  }

  /// Takes the recording out (after the ConfirmSheet): back to the tile.
  void remove() {
    _upload?.cancel();
    final uploadId = state.uploadId;
    if (uploadId != null) {
      ref.read(activationsServiceProvider).discard(id, uploadId).ignore();
    }
    state = ProofDraft(phone: state.phone, note: state.note);
  }

  void setPhone(String phone) => state = state.copyWith(phone: phone);

  void setNote(String note) => state = state.copyWith(note: note);

  /// The API no longer has the upload (404 ACTIVATION_UPLOAD_NOT_FOUND):
  /// the recording has to go up again, which Retry does.
  void lost() {
    _upload?.cancel();
    state = state.copyWith(stage: ProofStage.failed, uploadId: () => null);
  }

  /// The proof went: nothing left to keep.
  void clear() {
    _upload?.cancel();
    state = const ProofDraft();
  }
}

final proofDraftProvider =
    NotifierProvider.family<ProofDraftNotifier, ProofDraft, String>(
      ProofDraftNotifier.new,
    );
