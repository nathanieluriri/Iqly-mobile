import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/patches.dart';
import 'deadline.dart';

enum PatchPhase { idle, downloading, ready, failed }

/// Shorebird patches for this release (Figma B · Patch, rules 1323:28306):
/// checked at launch and on resume at most once an hour. A patch on its way
/// shows Updating iQLY until it is on disk, then Update applied, which only
/// tells the person: the patch boots on the next open and the app never
/// closes itself (owner, 17 Oct). A download that
/// fails or takes over [giveUpAfter] shows Couldn't update, and the app stops
/// asking until the next launch.
class PatchesNotifier extends Notifier<PatchPhase> {
  static const giveUpAfter = Duration(seconds: 30);
  static const pollEvery = Duration(seconds: 1);
  static const resumeEvery = Duration(hours: 1);

  Future<void>? _running;
  DateTime? _checkedAt;
  bool _gaveUp = false;

  @override
  PatchPhase build() => PatchPhase.idle;

  Future<void> check() =>
      _running ??= _check().whenComplete(() => _running = null);

  Future<void> _check() async {
    if (_gaveUp || state != PatchPhase.idle) return;
    _checkedAt = ref.read(clockProvider)();
    final service = ref.read(patchServiceProvider);
    try {
      var found = await service.check();
      if (found == PatchCheck.available) {
        state = PatchPhase.downloading;
        found = await _download(service);
      }
      state = switch (found) {
        PatchCheck.ready => PatchPhase.ready,
        PatchCheck.available => PatchPhase.failed,
        PatchCheck.none => PatchPhase.idle,
      };
    } catch (_) {
      if (state == PatchPhase.downloading) state = PatchPhase.failed;
    }
  }

  // Shorebird's own launch download makes update() return at once, so the
  // patch is only known to be on disk once a check says so.
  Future<PatchCheck> _download(PatchService service) async {
    await service.download().timeout(giveUpAfter);
    for (var i = 0; i < giveUpAfter.inSeconds ~/ pollEvery.inSeconds; i++) {
      final found = await service.check();
      if (found != PatchCheck.available) return found;
      await Future<void>.delayed(pollEvery);
    }
    return PatchCheck.available;
  }

  void resumed() {
    final last = _checkedAt;
    final now = ref.read(clockProvider)();
    if (last != null && now.difference(last) < resumeEvery) return;
    unawaited(check());
  }

  /// Close on Update applied, or Continue on Couldn't update: back to the
  /// app, asking no more until the next launch.
  void dismiss() {
    _gaveUp = true;
    state = PatchPhase.idle;
  }
}

final patchesProvider = NotifierProvider<PatchesNotifier, PatchPhase>(
  PatchesNotifier.new,
);
