import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api_client.dart';
import 'deadline.dart';
import 'session.dart';

/// What the app can run on the iQLY API instead of the preview data it
/// ships with (contract section 8). Sign-in, the version check and push
/// devices are live whatever this says.
enum LiveFeature {
  profile,
  briefs,
  submit,
  submissions,
  wallet,
  withdrawals,
  notifications,
  account;

  /// The features this one calls into, which have to be live with it.
  Set<LiveFeature> get needs => switch (this) {
    LiveFeature.submit => const {LiveFeature.briefs, LiveFeature.profile},
    LiveFeature.submissions => const {LiveFeature.briefs},
    LiveFeature.wallet => const {LiveFeature.profile},
    LiveFeature.withdrawals => const {LiveFeature.wallet},
    LiveFeature.account => const {LiveFeature.profile, LiveFeature.wallet},
    LiveFeature.profile ||
    LiveFeature.briefs ||
    LiveFeature.notifications => const {},
  };

  /// This feature and everything it needs, all the way down.
  Set<LiveFeature> get closure => {
    this,
    for (final need in needs) ...need.closure,
  };
}

/// What `GET /health` says about the mobile API (contract section 2).
class HealthReport {
  const HealthReport({
    this.ready = false,
    this.contract = 0,
    this.features = const {},
  });

  /// Reads any answer, a 503 included, since its body still says what is
  /// ready. Anything missing or malformed reads as not ready.
  factory HealthReport.fromJson(Map<String, dynamic> body) {
    final data = body['data'];
    final mobile = data is Map ? data['mobile'] : null;
    if (mobile is! Map) return const HealthReport();
    final contract = mobile['contract'];
    final features = mobile['features'];
    return HealthReport(
      ready: mobile['ready'] == true,
      contract: contract is int ? contract : 0,
      features: {
        if (features is Map)
          for (final feature in LiveFeature.values)
            if (features[feature.name] == true) feature,
      },
    );
  }

  final bool ready;
  final int contract;

  /// The features switched on, before what they need is weighed.
  final Set<LiveFeature> features;
}

abstract class HealthService {
  Future<HealthReport> check();
}

class LiveHealthService implements HealthService {
  LiveHealthService(this.api);

  final ApiClient api;

  @override
  Future<HealthReport> check() async =>
      HealthReport.fromJson((await api.get('/health')).body);
}

/// Null in the preview build, which never asks.
final healthServiceProvider = Provider<HealthService?>((ref) => null);

/// A contract 1 feature that a live launch does not run: health switched it
/// off, or something it needs. Its reads fail and its actions refuse, so no
/// preview data ever stands in for the person's own.
class FeaturePaused implements Exception {
  const FeaturePaused(this.feature);

  final LiveFeature feature;

  @override
  String toString() => 'FeaturePaused(${feature.name})';
}

/// Riverpod's own retry, except for a paused feature: it stays paused for
/// the whole launch, so asking again cannot help.
Duration? retryUnlessPaused(int retryCount, Object error) =>
    error is FeaturePaused
    ? null
    : ProviderContainer.defaultRetry(retryCount, error);

/// The features this launch runs on the API. A launch that runs none is a
/// preview launch, on the preview data everywhere; in a live launch every
/// feature not live is paused.
@immutable
class Backend {
  const Backend(this.live);

  /// A live feature needs health to say it is ready for this contract, and
  /// on for it and for everything it needs.
  factory Backend.from(HealthReport report) {
    if (!report.ready || report.contract != contract) return preview;
    return Backend.of(report.features);
  }

  /// The features of [on] that find everything they need in [on] too.
  factory Backend.of(Iterable<LiveFeature> on) {
    final given = on.toSet();
    return Backend({
      for (final feature in LiveFeature.values)
        if (given.containsAll(feature.closure)) feature,
    });
  }

  /// The contract this build speaks.
  static const contract = 1;

  static const preview = Backend(<LiveFeature>{});

  final Set<LiveFeature> live;

  bool isLive(LiveFeature feature) => live.contains(feature);

  bool get isPreview => live.isEmpty;

  /// Not live in a live launch.
  bool isPaused(LiveFeature feature) => !isPreview && !isLive(feature);

  /// The live features' names, in the contract's order.
  List<String> get names => [
    for (final feature in LiveFeature.values)
      if (isLive(feature)) feature.name,
  ];

  @override
  bool operator ==(Object other) =>
      other is Backend && setEquals(other.live, live);

  @override
  int get hashCode => Object.hashAllUnordered(live);

  @override
  String toString() => isPreview ? 'Preview' : 'Live: ${names.join(', ')}';
}

/// The preview build: every feature on the data the app ships with, for
/// the whole launch, and nothing ever asked. main.dart puts
/// [LiveBackendNotifier] in its place in a build on the API.
class BackendNotifier extends Notifier<Backend> {
  @override
  Backend build() => Backend.preview;

  bool get checking => false;

  /// When the API last answered a health check, on this launch or before.
  DateTime? get checkedAt => null;

  Future<void> check() async {}

  /// Completes once the check in flight answers, or after [within].
  Future<void> settled(Duration within) async {}

  /// Fixes the mode for the rest of the launch. The splash calls it at the
  /// hand-off.
  Future<void> lock() async {}

  void resumed() {}
}

/// Decides each launch's mode from `GET /health`. A launch starts from what
/// the last answer decided and asks again; an answer before the splash
/// locks the mode decides this launch, any later one only the next. A check
/// that fails keeps what was decided, and nothing decided is preview.
class LiveBackendNotifier extends BackendNotifier {
  LiveBackendNotifier({required this.forgetPreview});

  /// What the latest answer decided, for the next launch to start from.
  static const decidedKey = 'backend.decided';
  static const checkedAtKey = 'backend.checkedAt';

  /// The mode the last launch locked.
  static const launchedKey = 'backend.launched';

  /// A resume asks again at most this often.
  static const resumeEvery = Duration(minutes: 15);

  /// Clears the device stores a preview launch filled, on the first launch
  /// that runs anything live.
  final Future<void> Function(Ref ref) forgetPreview;

  Future<void>? _running;
  Future<void>? _locking;
  DateTime? _askedAt;

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  Backend build() => _stored(decidedKey);

  @override
  bool get checking => _running != null;

  @override
  DateTime? get checkedAt =>
      DateTime.tryParse(_prefs.getString(checkedAtKey) ?? '');

  /// Asks the API, one check at a time.
  @override
  Future<void> check() =>
      _running ??= _check().whenComplete(() => _running = null);

  Future<void> _check() async {
    final health = ref.read(healthServiceProvider);
    if (health == null) return;
    _askedAt = ref.read(clockProvider)();
    try {
      final report = await health.check();
      if (!ref.mounted) return;
      final decided = Backend.from(report);
      if (_locking == null) state = decided;
      await Future.wait([
        _prefs.setStringList(decidedKey, decided.names),
        _prefs.setString(
          checkedAtKey,
          ref.read(clockProvider)().toIso8601String(),
        ),
      ]);
    } catch (_) {
      // Fail open: what was decided before stands.
    }
  }

  @override
  Future<void> settled(Duration within) async {
    await _running?.timeout(within, onTimeout: () {});
  }

  /// The mode holds from the call on, and preview records are gone from
  /// memory by the time it returns; the future completes once the device
  /// has caught up.
  @override
  Future<void> lock() => _locking ??= _lock(state);

  Future<void> _lock(Backend mode) async {
    if (_stored(launchedKey).isPreview && !mode.isPreview) {
      try {
        await forgetPreview(ref);
      } catch (error) {
        // Unrecorded, so the next launch clears again.
        debugPrint('Backend: preview records not cleared: $error');
        return;
      }
    }
    await _prefs.setStringList(launchedKey, mode.names);
  }

  /// Back in the foreground: asks again once 15 minutes have passed.
  @override
  void resumed() {
    final last = _askedAt;
    final now = ref.read(clockProvider)();
    if (last != null && now.difference(last) < resumeEvery) return;
    unawaited(check());
  }

  Backend _stored(String key) {
    final names = _prefs.getStringList(key);
    if (names == null) return Backend.preview;
    final byName = LiveFeature.values.asNameMap();
    return Backend.of(names.map((name) => byName[name]).nonNulls);
  }
}

/// This launch's mode: `ref.watch(backendProvider).isLive(LiveFeature.briefs)`.
final backendProvider = NotifierProvider<BackendNotifier, Backend>(
  BackendNotifier.new,
);
