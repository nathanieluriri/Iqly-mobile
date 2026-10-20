import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/backend.dart';
import '../core/deadline.dart';
import '../core/session.dart';
import '../ui/recording_player.dart' show Recordings;
import 'activations_data.dart';
import 'api_client.dart';
import 'live/live_account.dart';
import 'live/live_repository.dart' show liveModeProvider;
import 'signed_in_files.dart';

/// An upload on its way: [progress] from 0 to 1, then the upload's [id].
class ProofUpload {
  const ProofUpload(this.progress, {this.id});

  final double progress;
  final String? id;
}

/// Activations (behind Flags.activations). The business confirms steps on
/// its side and iQLY pays the wallet; the app starts activations, follows
/// [changes] and sends proof. On the API a refusal throws [ApiRefused] with
/// its code and no answer [ApiUnreachable].
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

  /// Drops the upload [uploadId] of [id] that will not be sent.
  Future<void> discard(String id, String uploadId);

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
/// With a confirmation mode the rules of 19 Oct hold: a proof-mode run
/// waits on its recordings, each confirming its own step; in postback mode
/// a checked proof confirms its step and the business's app the rest
/// [step] later. A per-step activation pays each step as it is confirmed.
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
    final postback = current.confirmationMode == ConfirmationMode.postback;
    final started = current.withProgress(
      ActivationProgress(
        startedAt: _clock(),
        refCode: postback ? DemoActivations.runCode : null,
      ),
    );
    _store[id] = started;
    final beat = step;
    if (beat != null && current.confirmationMode != ConfirmationMode.proof) {
      _later(id, beat, () => _confirmFirst(id));
      _later(id, beat * 2, () => _confirmAll(id));
    }
    return started;
  }

  /// [run]'s payouts with [steps] paid at [at], on a per-step activation.
  static List<ActivationStepPayout> _paying(
    Activation activation,
    ActivationProgress run,
    Iterable<int> steps,
    DateTime at,
  ) => [
    ...run.stepPayouts,
    if (activation.perStep)
      for (final i in steps)
        if (activation.paysFor(i) > 0)
          ActivationStepPayout(
            step: i,
            kobo: activation.paysFor(i),
            paidAt: at,
            ledgerId: '${activation.creditId}-step-$i',
          ),
  ];

  void _confirmFirst(String id) {
    final current = this[id];
    final run = current.progress!;
    if (current.credited || run.confirmedAt.isNotEmpty) return;
    final now = _clock();
    _put(
      current.withProgress(
        run.copyWith(
          confirmedAt: [now],
          stepPayouts: _paying(current, run, const [0], now),
        ),
      ),
    );
  }

  void _confirmAll(String id) {
    final current = this[id];
    final run = current.progress!;
    if (current.credited) return;
    final now = _clock();
    final left = [
      for (var i = run.confirmedAt.length; i < current.steps.length; i++) i,
    ];
    _put(
      current.withProgress(
        run.copyWith(
          confirmedAt: [...run.confirmedAt, for (final _ in left) now],
          stepPayouts: _paying(current, run, left, now),
          paidAt: now,
        ),
      ),
    );
  }

  /// Checks the proof in: true when it was accepted. Without a mode it pays
  /// the run, as before; with one it confirms the step it proves, and the
  /// run is paid once that was the last.
  bool _checkProof(String id, {bool thenRest = false}) {
    final current = this[id];
    final run = current.progress!;
    final proof = run.proof;
    if (current.credited || proof == null || !proof.accepted) return false;
    if (refusals > 0) {
      refusals--;
      _put(
        current.withProgress(
          run.copyWith(proof: proof.refused(DemoActivations.endsEarly)),
        ),
      );
      return false;
    }
    final now = _clock();
    if (current.confirmationMode == null) {
      _put(
        current.withProgress(
          run.copyWith(proof: proof.checked(now), paidAt: now),
        ),
      );
      return true;
    }
    final confirmed = [...run.confirmedAt, now];
    final last = confirmed.length >= current.steps.length;
    _put(
      current.withProgress(
        run.copyWith(
          confirmedAt: confirmed,
          proof: proof.checked(now),
          stepPayouts: _paying(current, run, [proof.step], now),
          paidAt: last ? now : null,
        ),
      ),
    );
    final beat = step;
    if (thenRest &&
        !last &&
        beat != null &&
        current.confirmationMode == ConfirmationMode.postback) {
      _later(id, beat, () => _confirmAll(id));
    }
    return true;
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
        if (_checkProof(id) &&
            current.confirmationMode == ConfirmationMode.postback) {
          _confirmAll(id);
        }
      case ActivationPhase.offer ||
          ActivationPhase.started ||
          ActivationPhase.notConfirmed ||
          ActivationPhase.recording ||
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
  Future<void> discard(String id, String uploadId) async =>
      discarded.add(uploadId);

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
    if (beat != null) _later(id, beat, () => _checkProof(id, thenRest: true));
    return sentProof;
  }

  void dispose() {
    for (final id in [..._timers.keys]) {
      _cancel(id);
    }
    _changes.close();
  }
}

/// Activations on the API (contract 11.2): the open ones and the person's
/// runs, kept for a read without a connection. Starting, the proof upload
/// and the proof go online only. Nothing streams from the API: the screens
/// read again as they open and when a push lands, so [changes] stays
/// quiet. [stepProof] is health's `activationStepProof`: only an API that
/// runs the rules of 19 Oct has its confirmation and reward modes read.
class LiveActivationsService implements ActivationsService {
  LiveActivationsService(
    this.link, {
    DateTime Function()? clock,
    this.stepProof = false,
  }) : _clock = clock ?? DateTime.now;

  final AccountLink link;
  final bool stepProof;
  final DateTime Function() _clock;
  final _changes = StreamController<Activation>.broadcast();

  ApiClient get _api => link.api;

  static String _path(String id) => '/activations/${Uri.encodeComponent(id)}';

  /// `/activations/mine` reads this many at a time.
  static const _page = 100;

  /// Stops paging an answer that never ends.
  static const _maxPages = 20;

  /// The open activations and the person's runs on the rest, then any run
  /// of theirs that list left out.
  @override
  Future<List<Activation>> activations() async {
    final (:json, :fetchedAt) = await link.fetchDated(
      '/activations',
      AccountKeys.activations,
    );
    final listed = _items(json, at: fetchedAt);
    await _authorize();
    final mine = await _mine().catchError((Object _) => const <Activation>[]);
    final ids = {for (final a in listed) a.id};
    return [
      ...listed,
      for (final a in mine)
        if (!ids.contains(a.id)) a,
    ];
  }

  Future<List<Activation>> _mine() async {
    final runs = <Activation>[];
    String? cursor;
    for (var page = 0; page < _maxPages; page++) {
      final query = Uri(queryParameters: {'limit': '$_page', 'cursor': ?cursor})
          .query;
      final res = await link.scope.guard(_api.get('/activations/mine?$query'));
      if (!res.ok) throw ApiRefused.of(res);
      runs.addAll(_items(res.data));
      cursor = apiText(res.data['nextCursor']);
      if (cursor == null) break;
    }
    return runs;
  }

  /// The activations of [json], read as of [at] when it is a copy kept
  /// from then: its phases stand only until time moves on from it.
  List<Activation> _items(Map<String, dynamic> json, {DateTime? at}) => [
    if (json['items'] case final List<Object?> items)
      for (final item in items)
        ?activationFromJson(item, now: at ?? _clock(), stepProof: stepProof),
  ];

  Future<Activation> _one(Future<ApiResponse> sending) async {
    final res = await link.scope.guard(sending);
    final activation = res.ok
        ? activationFromJson(res.data, now: _clock(), stepProof: stepProof)
        : null;
    if (activation == null) throw ApiRefused.of(res);
    await _authorize();
    return activation;
  }

  /// Proof recordings play only with the session's token, from a copy
  /// downloaded once to the account's folder ([SignedInFiles]).
  Future<void> _authorize() async {
    final token = await _api.tokens.read();
    Recordings.signedIn = token == null
        ? null
        : (base: _api.baseUrl, token: token);
    final files = SignedInFiles(api: _api);
    final user = link.userId() ?? '';
    Recordings.fetchSignedIn = token == null
        ? null
        : (source) async {
            final name = source.pathSegments.lastOrNull ?? 'proof';
            final file = await files.fetch(
              userId: user,
              id: source.hasQuery
                  ? '${source.path}_${source.query}'
                  : source.path,
              url: source.toString(),
              name: name.contains('.') ? name : '$name.mp4',
            );
            return Uri.file(file.path);
          };
  }

  @override
  Future<Activation> start(String id) => _one(_api.post('${_path(id)}/start'));

  @override
  Stream<Activation> changes() => _changes.stream;

  @override
  Future<Activation> refresh(String id) => _one(_api.get(_path(id)));

  /// The recording goes from the phone's file; one that cannot be read
  /// fails as an upload does. An upload left before it lands is dropped
  /// once it has.
  @override
  Stream<ProofUpload> upload(String id, ProofVideo video) {
    var left = false;
    late final StreamController<ProofUpload> out;
    Future<void> send() async {
      final source = video.source;
      if (source == null || source.scheme != 'file') {
        throw const ApiUnreachable(nothingSent: true);
      }
      final bytes = await File(source.toFilePath()).readAsBytes();
      final length = video.length;
      final res = await link.scope.guard(
        _api.multipart(
          '${_path(id)}/proof/uploads',
          fields: {
            if (length != null)
              'lengthSeconds': '${(length.inMilliseconds / 1000).ceil()}',
          },
          files: [
            ApiFile(
              field: 'file',
              filename: video.name,
              bytes: bytes,
              contentType: videoMediaType(video.name),
            ),
          ],
          onProgress: (share) {
            if (!left && share < 1) out.add(ProofUpload(share));
          },
        ),
      );
      final uploadId = res.ok ? apiText(res.data['id']) : null;
      if (uploadId == null) throw ApiRefused.of(res);
      if (left) return discard(id, uploadId);
      out.add(ProofUpload(1, id: uploadId));
    }

    out = StreamController<ProofUpload>(
      onListen: () => send().then(
        (_) => out.close(),
        onError: (Object error) {
          if (!left) out.addError(error);
          out.close();
        },
      ),
      onCancel: () => left = true,
    );
    return out.stream;
  }

  @override
  Future<void> discard(String id, String uploadId) async {
    try {
      await _api.delete(
        '${_path(id)}/proof/uploads/${Uri.encodeComponent(uploadId)}',
      );
    } on ApiUnreachable {
      return;
    }
  }

  @override
  Future<Activation> sendProof(
    String id, {
    required int step,
    required String uploadId,
    required ProofVideo video,
    String phone = '',
    String note = '',
  }) => _one(
    _api.post('${_path(id)}/proof', {
      'step': step,
      'uploadId': uploadId,
      if (phone.isNotEmpty) 'phone': phone,
      if (note.isNotEmpty) 'note': note,
    }),
  );

  void dispose() {
    _changes.close();
    Recordings.signedIn = null;
    Recordings.fetchSignedIn = null;
  }
}

/// Activations a live launch does not run: reads fail, nothing is sent.
class PausedActivationsService implements ActivationsService {
  const PausedActivationsService();

  static Future<Never> _paused() =>
      Future.error(const FeaturePaused(LiveFeature.activations));

  @override
  Future<List<Activation>> activations() => _paused();

  @override
  Future<Activation> start(String id) => _paused();

  @override
  Stream<Activation> changes() => const Stream.empty();

  @override
  Future<Activation> refresh(String id) => _paused();

  @override
  Stream<ProofUpload> upload(String id, ProofVideo video) =>
      Stream.error(const FeaturePaused(LiveFeature.activations));

  @override
  Future<void> discard(String id, String uploadId) async {}

  @override
  Future<Activation> sendProof(
    String id, {
    required int step,
    required String uploadId,
    required ProofVideo video,
    String phone = '',
    String note = '',
  }) => _paused();
}

/// The media type the API checks a recording by, from its extension.
String videoMediaType(String name) {
  final dot = name.lastIndexOf('.');
  return switch (dot < 0 ? '' : name.substring(dot + 1).toLowerCase()) {
    'mp4' || 'm4v' => 'video/mp4',
    'mov' => 'video/quicktime',
    'webm' => 'video/webm',
    '3gp' => 'video/3gpp',
    _ => 'application/octet-stream',
  };
}

/// A contract 11.2 activation, or null without an id, a business, a title
/// or a close. The app works its phase out from the run as the API does;
/// an activation the business closed early, or a run that ended, counts as
/// closed from then ([now] when the API does not say when). Its modes, step
/// amounts, run code, step payouts, held steps and the phase the API worked
/// out (kept with [now]) are read with [stepProof] only; a mode the build
/// does not know reads as none.
Activation? activationFromJson(
  Object? json, {
  required DateTime now,
  bool stepProof = false,
}) {
  if (json is! Map) return null;
  final id = apiText(json['id']);
  final business = apiText(json['businessName']);
  final title = apiText(json['title']);
  var closesAt = apiTime(json['closesAt']);
  if (id == null || business == null || title == null || closesAt == null) {
    return null;
  }
  final run = json['progress'];
  final progress = run is Map ? _progress(run, stepProof: stepProof) : null;
  final perStep = stepProof && json['rewardMode'] == 'per_step';
  final mode = stepProof
      ? switch (json['confirmationMode']) {
          'proof' => ConfirmationMode.proof,
          'postback' => ConfirmationMode.postback,
          _ => null,
        }
      : null;
  final ended = run is Map && run['status'] == 'expired';
  if ((json['status'] == 'closed' || ended) && closesAt.isAfter(now)) {
    final at = run is Map ? apiTime(run['expiredAt']) : null;
    closesAt = at != null && at.isBefore(now) ? at : now;
  }
  return Activation(
    id: id,
    business: business,
    title: title,
    minutes: apiInt(json['minutes']) ?? 0,
    rewardKobo: apiInt(json['rewardKobo']) ?? 0,
    closesAt: closesAt,
    spotsLeft: apiInt(json['spotsLeft']) ?? 0,
    spotsTotal: apiInt(json['spotsTotal']) ?? 0,
    steps: [
      if (json['steps'] case final List<Object?> steps)
        for (final step in steps)
          if (step is Map)
            ActivationStep(
              title: apiText(step['title']) ?? '',
              hint: apiText(step['hint']) ?? '',
              howTo: apiText(step['howTo']),
              rewardKobo: perStep ? apiInt(step['rewardKobo']) : null,
            ),
    ],
    link: Uri.tryParse(apiText(json['link']) ?? '') ?? Uri(),
    progress: progress,
    live: true,
    logoUrl: apiText(json['logoUrl']),
    imageUrl: apiText(json['imageUrl']),
    paused: json['status'] == 'paused',
    confirmationMode: mode,
    rewardMode: perStep ? RewardMode.perStep : RewardMode.perRun,
    sentPhase: stepProof ? _phase(json['phase'], mode) : null,
    sentAt: stepProof ? now : null,
  );
}

/// The API's `phase` as the app names it: `not_confirmed` is the step to
/// record in proof mode.
ActivationPhase? _phase(Object? phase, ConfirmationMode? mode) =>
    switch (phase) {
      'offer' => ActivationPhase.offer,
      'started' => ActivationPhase.started,
      'confirming' => ActivationPhase.confirming,
      'not_confirmed' when mode == ConfirmationMode.proof =>
        ActivationPhase.recording,
      'not_confirmed' => ActivationPhase.notConfirmed,
      'checking' => ActivationPhase.checking,
      'not_accepted' => ActivationPhase.notAccepted,
      'credited' => ActivationPhase.credited,
      'expired' => ActivationPhase.expired,
      _ => null,
    };

ActivationProgress? _progress(
  Map<dynamic, dynamic> json, {
  required bool stepProof,
}) {
  final startedAt = apiTime(json['startedAt']);
  if (startedAt == null) return null;
  final proof = json['proof'];
  return ActivationProgress(
    startedAt: startedAt,
    confirmedAt: [
      if (json['confirmedAt'] case final List<Object?> times)
        for (final at in times) ?apiTime(at),
    ],
    proof: proof is Map ? _proof(proof) : null,
    paidAt: apiTime(json['paidAt']),
    ledgerId: apiText(json['ledgerId']),
    refCode: stepProof ? apiText(json['refCode']) : null,
    stepPayouts: [
      if (stepProof)
        if (json['stepPayouts'] case final List<Object?> payouts)
          for (final payout in payouts) ?_payout(payout),
    ],
    heldSteps: [
      if (stepProof)
        if (json['heldSteps'] case final List<Object?> held)
          for (final step in held)
            if (step is Map)
              if (apiInt(step['step']) case final int i)
                ActivationHeldStep(step: i, until: apiTime(step['until'])),
    ],
    ended: json['status'] == 'expired',
  );
}

ActivationStepPayout? _payout(Object? json) {
  if (json is! Map) return null;
  final step = apiInt(json['step']);
  final kobo = apiInt(json['kobo']);
  final paidAt = apiTime(json['paidAt']);
  if (step == null || kobo == null || paidAt == null) return null;
  return ActivationStepPayout(
    step: step,
    kobo: kobo,
    paidAt: paidAt,
    ledgerId: apiText(json['ledgerId']),
  );
}

/// A refused proof keeps the business's reason; refused without one, it
/// still reads as not accepted.
ActivationProof? _proof(Map<dynamic, dynamic> json) {
  final step = apiInt(json['step']);
  final receivedAt = apiTime(json['receivedAt']);
  final video = json['video'];
  if (step == null || receivedAt == null || video is! Map) return null;
  final seconds = apiInt(video['lengthSeconds']);
  final url = apiText(video['url']);
  return ActivationProof(
    step: step,
    receivedAt: receivedAt,
    checkedAt: apiTime(json['checkedAt']),
    notAccepted: json['status'] == 'rejected'
        ? apiText(json['notAccepted']) ?? ''
        : null,
    video: ProofVideo(
      name: apiText(video['name']) ?? '',
      bytes: apiInt(video['bytes']) ?? 0,
      length: seconds == null ? null : Duration(seconds: seconds),
      source: url == null ? null : Uri.tryParse(url),
    ),
  );
}

/// The demo in a preview launch, the API while activations run live; a
/// live launch without them refuses, so no sample shows as the person's.
final activationsServiceProvider = Provider<ActivationsService>((ref) {
  ref.watch(accountProvider);
  if (ref.watch(liveModeProvider).isPreview) {
    final service = DemoActivationsService();
    ref.onDispose(service.dispose);
    return service;
  }
  final link = ref.watch(liveLinkProvider(LiveFeature.activations));
  if (link == null) return const PausedActivationsService();
  final service = LiveActivationsService(
    link,
    clock: ref.watch(clockProvider),
    stepProof: ref
        .watch(liveModeProvider)
        .isLive(LiveFeature.activationStepProof),
  );
  ref.onDispose(service.dispose);
  return service;
});
