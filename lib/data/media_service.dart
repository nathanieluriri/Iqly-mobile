import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'activations_data.dart';

/// Whether the app may read the phone's videos.
enum MediaAccess { unasked, allowed, denied }

/// Videos from the device. The proof is a screen recording made with the
/// phone's own recorder and chosen with the phone's own picker.
abstract class MediaService {
  /// [MediaAccess.unasked] until the person answers the photos prompt
  /// (B9 · Proof · photo permission); the screen asks before it picks.
  MediaAccess get access;

  /// Records the answer to the photos prompt.
  void answer({required bool allow});

  /// Null when the person backs out of the picker or access is denied.
  /// [about] names the business the recording proves a step for; the demo
  /// names its file after it, the device's picker has the file's own name.
  Future<ProofVideo?> pickVideo({String? about});
}

/// The phone's own picker (file_picker). The OS asks for photo access
/// itself, so the screen's prompt never shows; a refusal reads as denied.
/// Without the plugin, as in tests and on a desktop build, it falls back to
/// the demo. The picker gives no running time: length stays null and the
/// size limit is checked here, the length by the API.
class DeviceMediaService implements MediaService {
  DeviceMediaService({MediaService? fallback})
    : fallback = fallback ?? DemoMediaService(access: MediaAccess.allowed);

  final MediaService fallback;
  var _access = MediaAccess.allowed;

  @override
  MediaAccess get access => _access;

  @override
  void answer({required bool allow}) =>
      _access = allow ? MediaAccess.allowed : MediaAccess.denied;

  @override
  Future<ProofVideo?> pickVideo({String? about}) async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.video);
      if (files.isEmpty) return null;
      final file = files.first;
      return ProofVideo(
        name: file.name,
        bytes: file.lengthSync() ?? await file.length() ?? 0,
      );
    } on MissingPluginException {
      return fallback.pickVideo(about: about);
    } on PlatformException {
      _access = MediaAccess.denied;
      return null;
    }
  }
}

class DemoMediaService implements MediaService {
  DemoMediaService({
    this.delay = const Duration(milliseconds: 400),
    this.video = sample,
    this.access = MediaAccess.unasked,
  });

  /// "kudi-box-signup.mp4", "0:42", "18 MB" (B9 · Proof · ready).
  static const sample = ProofVideo(
    name: 'kudi-box-signup.mp4',
    bytes: 18000000,
    length: Duration(seconds: 42),
  );

  /// "Your video is 1:42" (B9 · Proof · video too long).
  static const tooLong = ProofVideo(
    name: 'kudi-box-signup.mp4',
    bytes: 18000000,
    length: Duration(minutes: 1, seconds: 42),
  );

  /// "kudi-box-signup.mp4": a demo recording of [business]'s app, [what] it
  /// shows after the name, as the frames name theirs.
  static String recordingName(String business, String what) =>
      '${business.toLowerCase().replaceAll(' ', '-')}-$what.mp4';

  final Duration delay;

  /// What the next pick returns; null backs out. The [sample] takes the
  /// name of the business it proves a step for.
  ProofVideo? video;
  int picks = 0;

  @override
  MediaAccess access;

  @override
  void answer({required bool allow}) =>
      access = allow ? MediaAccess.allowed : MediaAccess.denied;

  @override
  Future<ProofVideo?> pickVideo({String? about}) async {
    if (access == MediaAccess.denied) return null;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    picks++;
    final video = this.video;
    if (about == null || video == null || video.name != sample.name) {
      return video;
    }
    return ProofVideo(
      name: recordingName(about, 'signup'),
      bytes: video.bytes,
      length: video.length,
    );
  }
}

final mediaServiceProvider = Provider<MediaService>(
  (ref) => DeviceMediaService(),
);
