import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../../data/activations_data.dart';
import '../../data/activations_service.dart';
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
/// ₦14,000.00). The live API credits the ledger itself and a wallet reload
/// brings the same row.
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

  void _land(Activation activation) {
    final list = state.value;
    if (!ref.mounted || list == null) return;
    final before = list.where((a) => a.id == activation.id).firstOrNull;
    state = AsyncData([
      for (final a in list) a.id == activation.id ? activation : a,
    ]);
    if (activation.credited && !(before?.credited ?? false)) {
      _credit(activation);
    }
  }

  Future<void> _credit(Activation activation) async {
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
  /// [ActivationRules.proofBytes]: refused before it uploads.
  refused,
  uploading,
  ready,
  failed,
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
  });

  final ProofStage stage;
  final ProofVideo? video;
  final double progress;
  final String? uploadId;
  final String phone;
  final String note;

  /// A recording sits in the slot.
  bool get hasVideo => stage != ProofStage.none;

  ProofDraft copyWith({
    ProofStage? stage,
    ProofVideo? video,
    double? progress,
    String? Function()? uploadId,
    String? phone,
    String? note,
  }) => ProofDraft(
    stage: stage ?? this.stage,
    video: video ?? this.video,
    progress: progress ?? this.progress,
    uploadId: uploadId == null ? this.uploadId : uploadId(),
    phone: phone ?? this.phone,
    note: note ?? this.note,
  );
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
          onError: (Object _) =>
              state = state.copyWith(stage: ProofStage.failed),
        );
  }

  /// Takes the recording out (after the ConfirmSheet): back to the tile.
  void remove() {
    _upload?.cancel();
    final uploadId = state.uploadId;
    if (uploadId != null) {
      ref.read(activationsServiceProvider).discard(uploadId);
    }
    state = ProofDraft(phone: state.phone, note: state.note);
  }

  void setPhone(String phone) => state = state.copyWith(phone: phone);

  void setNote(String note) => state = state.copyWith(note: note);

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
