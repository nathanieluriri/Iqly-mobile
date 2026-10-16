import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_version.dart';
import 'deadline.dart';
import 'session.dart';

/// What the version check last said about this build, null until it answers
/// (Figma note 1313:92110). A check that fails keeps what was known, so a
/// fault never locks anyone out.
class UpdatesNotifier extends Notifier<AppRelease?> {
  /// The newest version Discover has offered, and when.
  static const offeredKey = 'updates.offered';
  static const offeredAtKey = 'updates.offeredAt';

  /// Discover offers the same version again after this, until it is installed.
  static const reofferAfter = Duration(hours: 24);

  /// A resume checks again at most this often.
  static const resumeEvery = Duration(hours: 1);

  /// How long the splash holds past its own run for an answer.
  static const splashWait = Duration(seconds: 2);

  Future<void>? _running;
  DateTime? _checkedAt;

  @override
  AppRelease? build() => null;

  bool get checking => _running != null;

  bool get required => state?.status == UpdateStatus.required;

  /// Asks the API, one check at a time.
  Future<void> check() =>
      _running ??= _check().whenComplete(() => _running = null);

  Future<void> _check() async {
    _checkedAt = ref.read(clockProvider)();
    try {
      state = await ref.read(appVersionServiceProvider).check();
    } catch (_) {
      // Fail open: whatever was known stands.
    }
  }

  /// Completes once the check in flight answers, or after [within].
  Future<void> settled(Duration within) async {
    await _running?.timeout(within, onTimeout: () {});
  }

  /// Back in the foreground: checks again once an hour has passed.
  void resumed() {
    final last = _checkedAt;
    final now = ref.read(clockProvider)();
    if (last != null && now.difference(last) < resumeEvery) return;
    unawaited(check());
  }

  /// Whether Discover should offer the newer build: at once for a new
  /// version, then once a day until it is installed.
  bool get offer {
    final release = state;
    if (release?.status != UpdateStatus.available) return false;
    final prefs = ref.read(sharedPreferencesProvider);
    if (release!.latest != prefs.getString(offeredKey)) return true;
    final at = DateTime.tryParse(prefs.getString(offeredAtKey) ?? '');
    return at == null ||
        !ref.read(clockProvider)().isBefore(at.add(reofferAfter));
  }

  Future<void> offered() async {
    final latest = state?.latest;
    if (latest == null) return;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(offeredKey, latest);
    await prefs.setString(
      offeredAtKey,
      ref.read(clockProvider)().toIso8601String(),
    );
  }
}

final updatesProvider = NotifierProvider<UpdatesNotifier, AppRelease?>(
  UpdatesNotifier.new,
);
