import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart' as shorebird;

/// What Shorebird says about patches for this release.
enum PatchCheck { none, available, ready }

abstract class PatchService {
  /// The patch this launch is running, null on the release as shipped.
  Future<int?> current();

  Future<PatchCheck> check();

  /// Returns once the newest patch is on disk, or at once when Shorebird's
  /// own launch download is already running.
  Future<void> download();
}

class ShorebirdPatchService implements PatchService {
  ShorebirdPatchService({shorebird.ShorebirdUpdater? updater})
    : _given = updater;

  final shorebird.ShorebirdUpdater? _given;

  // Built on first use: its constructor calls into the engine on this
  // isolate, which must not hold up the first frame.
  late final shorebird.ShorebirdUpdater _updater =
      _given ?? shorebird.ShorebirdUpdater();

  @override
  Future<int?> current() async {
    if (!_updater.isAvailable) return null;
    return (await _updater.readCurrentPatch())?.number;
  }

  @override
  Future<PatchCheck> check() async {
    if (!_updater.isAvailable) return PatchCheck.none;
    return switch (await _updater.checkForUpdate()) {
      shorebird.UpdateStatus.outdated => PatchCheck.available,
      shorebird.UpdateStatus.restartRequired => PatchCheck.ready,
      _ => PatchCheck.none,
    };
  }

  @override
  Future<void> download() => _updater.update();
}

/// Builds without the Shorebird engine (flutter run, tests) have no patches.
class NoPatchService implements PatchService {
  const NoPatchService();

  @override
  Future<int?> current() async => null;

  @override
  Future<PatchCheck> check() async => PatchCheck.none;

  @override
  Future<void> download() async {}
}

final patchServiceProvider = Provider<PatchService>(
  (ref) => const NoPatchService(),
);
