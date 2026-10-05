import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'activations_data.dart';

/// Videos from the device. The proof is a screen recording made with the
/// phone's own recorder; the live version chooses it from the gallery with
/// image_picker (pickVideo, ImageSource.gallery; ImageSource.camera if the
/// owner wants recording in the app, which needs the camera permission
/// strings) and reads its length and first frame with video_player. The
/// demo hands back the recording of the Figma frames.
abstract class MediaService {
  /// Null when the person backs out of the picker. [about] names the
  /// business the recording proves a step for; the demo names its file
  /// after it, the device's picker has the file's own name.
  Future<ProofVideo?> pickVideo({String? about});

  /// A screenshot from the phone's own picker (file_picker, images only);
  /// its file name, or null when the person backs out.
  Future<String?> pickImage();
}

class DemoMediaService implements MediaService {
  DemoMediaService({
    this.delay = const Duration(milliseconds: 400),
    this.video = sample,
  });

  /// "kudi-box-signup.mp4", "0:42", "18 MB" (B9 · Proof · ready).
  static const sample = ProofVideo(
    name: 'kudi-box-signup.mp4',
    bytes: 18000000,
    length: Duration(seconds: 42),
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

  /// What the next screenshot pick returns; null backs out.
  String? image = 'screenshot.png';

  @override
  Future<String?> pickImage() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    picks++;
    return image;
  }

  @override
  Future<ProofVideo?> pickVideo({String? about}) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    picks++;
    final video = this.video;
    if (about == null || !identical(video, sample)) return video;
    return ProofVideo(
      name: recordingName(about, 'signup'),
      bytes: sample.bytes,
      length: sample.length,
    );
  }
}

/// The demo recordings with the phone's own picker for screenshots. Without
/// the plugin, as in tests, the pick falls back to the demo's.
class DeviceMediaService extends DemoMediaService {
  @override
  Future<String?> pickImage() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.image);
      return files.isEmpty ? null : files.first.name;
    } on MissingPluginException {
      return super.pickImage();
    }
  }
}

final mediaServiceProvider = Provider<MediaService>(
  (ref) => DeviceMediaService(),
);
