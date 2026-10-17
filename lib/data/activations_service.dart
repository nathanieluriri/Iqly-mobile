import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session.dart';
import 'activations_data.dart';

/// An upload on its way: [progress] from 0 to 1, then the upload's [id].
class ProofUpload {
  const ProofUpload(this.progress, {this.id});

  final double progress;
  final String? id;
}

/// Activations through the iQLY API (behind Flags.activations). The
/// business confirms steps on its side and iQLY pays the wallet; the app
/// starts activations, follows [changes] and sends proof.
abstract class ActivationsService {
  /// Open activations, with your progress on the ones you started.
  Future<List<Activation>> activations();

  /// Starts [id] for you.
  Future<Activation> start(String id);

  /// Every later change to an activation you started: a step confirmed,
  /// proof checked, the reward paid. The live API pushes or polls.
  Stream<Activation> changes();

  /// The latest state of [id], asked for now.
  Future<Activation> refresh(String id);

  /// Uploads [video] as proof for [id]: progress, then the upload id.
  Stream<ProofUpload> upload(String id, ProofVideo video);

  /// Drops an upload that will not be sent.
  Future<void> discard(String uploadId);

  /// Sends the uploaded recording as proof of [step], with the optional
  /// account phone number and note.
  Future<Activation> sendProof(
    String id, {
    required int step,
    required String uploadId,
    required ProofVideo video,
    String phone = '',
    String note = '',
  });
}

/// The B8 and B9 prototypes as live changes. A started activation confirms
/// its first step after [step] and the rest, paid, after another [step]
/// (row note: "step 1 confirmed (4 s) → all steps confirmed and paid
/// (4 s)"); proof is checked and paid [step] after it is sent. [refresh]
/// stands in for the business answering at once, as tapping the waiting
/// step or the Checking row does in the prototypes. With [step] null
/// nothing changes until [refresh].
///
/// [loadFailures], [startFailures], [uploadFailures] and [sendFailures]
/// fail that many calls first, for the failed states; [refusals] turns that
/// many proofs down when they are checked (B9 · Proof · not accepted).
class DemoActivationsService implements ActivationsService {
  DemoActivationsService({
    List<Activation>? seed,
    DateTime Function()? clock,
    this.load = const Duration(milliseconds: 1200),
    this.delay = const Duration(milliseconds: 700),
    this.step = const Duration(seconds: 4),
    this.uploadTick = const Duration(milliseconds: 300),
    this.loadFailures = 0,
    this.startFailures = 0,
    this.uploadFailures = 0,
    this.sendFailures = 0,
    this.refusals = 0,
  }) : _clock = clock ?? DateTime.now {
    for (final a in seed ?? DemoActivations(_clock()).all) {
      _store[a.id] = a;
    }
  }

  final Duration load;
  final Duration delay;
  final Duration? step;
  final Duration uploadTick;
  int loadFailures;
  int startFailures;
  int uploadFailures;
  int sendFailures;
  int refusals;
  final DateTime Function() _clock;

  final _store = <String, Activation>{};
  final _changes = StreamController<Activation>.broadcast();
  final _timers = <String, List<Timer>>{};
  final discarded = <String>[];
  final sent = <({String id, String phone, String note})>[];
  int _uploads = 0;

  Activation operator [](String id) => _store[id]!;

  Future<void> _wait(Duration duration) => duration == Duration.zero
      ? Future.value()
      : Future<void>.delayed(duration);

  void _put(Activation activation) {
    _store[activation.id] = activation;
    _changes.add(activation);
  }

  void _later(String id, Duration after, void Function() change) {
    late final Timer timer;
    timer = Timer(after, () {
      _timers[id]?.remove(timer);
      change();
    });
    (_timers[id] ??= []).add(timer);
  }

  void _cancel(String id) {
    for (final timer in _timers.remove(id) ?? const <Timer>[]) {
      timer.cancel();
    }
  }

  @override
  Future<List<Activation>> activations() async {
    await _wait(load);
    if (loadFailures > 0) {
      loadFailures--;
      throw Exception('offline');
    }
    return [..._store.values];
  }

  @override
  Future<Activation> start(String id) async {
    await _wait(delay);
    if (startFailures > 0) {
      startFailures--;
      throw Exception('offline');
    }
    final current = this[id];
    if (current.started) return current;
    final started = current.withProgress(
      ActivationProgress(startedAt: _clock()),
    );
    _store[id] = started;
    final beat = step;
    if (beat != null) {
      _later(id, beat, () => _confirmFirst(id));
      _later(id, beat * 2, () => _confirmAll(id));
    }
    return started;
  }

  void _confirmFirst(String id) {
    final current = this[id];
    final run = current.progress!;
    if (current.credited || run.confirmedAt.isNotEmpty) return;
    _put(current.withProgress(run.copyWith(confirmedAt: [_clock()])));
  }

  void _confirmAll(String id) {
    final current = this[id];
    final run = current.progress!;
    if (current.credited) return;
    final now = _clock();
    _put(
      current.withProgress(
        run.copyWith(
          confirmedAt: [
            ...run.confirmedAt,
            for (var i = run.confirmedAt.length; i < current.steps.length; i++)
              now,
          ],
          paidAt: now,
        ),
      ),
    );
  }

  void _checkProof(String id) {
    final current = this[id];
    final run = current.progress!;
    final proof = run.proof;
    if (current.credited || proof == null || !proof.accepted) return;
    if (refusals > 0) {
      refusals--;
      _put(
        current.withProgress(
          run.copyWith(proof: proof.refused(DemoActivations.endsEarly)),
        ),
      );
      return;
    }
    final now = _clock();
    _put(
      current.withProgress(
        run.copyWith(proof: proof.checked(now), paidAt: now),
      ),
    );
  }

  @override
  Stream<Activation> changes() => _changes.stream;

  @override
  Future<Activation> refresh(String id) async {
    await _wait(delay);
    final current = this[id];
    switch (current.phaseAt(_clock())) {
      case ActivationPhase.confirming:
        _cancel(id);
        _confirmAll(id);
      case ActivationPhase.checking:
        _cancel(id);
        _checkProof(id);
      case ActivationPhase.offer ||
          ActivationPhase.started ||
          ActivationPhase.notConfirmed ||
          ActivationPhase.notAccepted ||
          ActivationPhase.credited ||
          ActivationPhase.expired:
        break;
    }
    return this[id];
  }

  @override
  Stream<ProofUpload> upload(String id, ProofVideo video) async* {
    for (final share in const [0.25, 0.5, 0.75]) {
      await _wait(uploadTick);
      if (uploadFailures > 0) {
        uploadFailures--;
        throw Exception('offline');
      }
      yield ProofUpload(share);
    }
    await _wait(uploadTick);
    yield ProofUpload(1, id: 'upload-${++_uploads}');
  }

  @override
  Future<void> discard(String uploadId) async => discarded.add(uploadId);

  @override
  Future<Activation> sendProof(
    String id, {
    required int step,
    required String uploadId,
    required ProofVideo video,
    String phone = '',
    String note = '',
  }) async {
    await _wait(delay);
    if (sendFailures > 0) {
      sendFailures--;
      throw Exception('offline');
    }
    final current = this[id];
    final run = current.progress!;
    final sentProof = current.withProgress(
      run.copyWith(
        proof: ActivationProof(step: step, video: video, receivedAt: _clock()),
      ),
    );
    sent.add((id: id, phone: phone, note: note));
    _store[id] = sentProof;
    final beat = this.step;
    if (beat != null) _later(id, beat, () => _checkProof(id));
    return sentProof;
  }

  void dispose() {
    for (final id in [..._timers.keys]) {
      _cancel(id);
    }
    _changes.close();
  }
}

final activationsServiceProvider = Provider<ActivationsService>((ref) {
  ref.watch(accountProvider);
  final service = DemoActivationsService();
  ref.onDispose(service.dispose);
  return service;
});
