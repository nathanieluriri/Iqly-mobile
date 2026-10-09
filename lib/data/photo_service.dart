import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

enum PhotoSource { camera, library }

/// A photo for the avatar, from the phone's camera or its library.
abstract class PhotoService {
  /// False where only the library is on offer (a desktop build).
  bool get hasCamera;

  /// The photo's bytes, or null when the person backs out or refuses
  /// access.
  Future<Uint8List?> pick(PhotoSource source);
}

/// The phone's own camera and photo picker (image_picker), which ask for
/// access themselves. Without the plugin, as in tests, it falls back to the
/// demo.
class DevicePhotoService implements PhotoService {
  DevicePhotoService({PhotoService? fallback})
    : fallback = fallback ?? DemoPhotoService();

  final PhotoService fallback;

  /// Big enough for the crop at 3x; the picker scales anything larger.
  static const double maxSide = 1600;

  @override
  bool get hasCamera =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<Uint8List?> pick(PhotoSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source == PhotoSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: maxSide,
        maxHeight: maxSide,
        preferredCameraDevice: CameraDevice.front,
      );
      if (file == null) return null;
      return await file.readAsBytes();
    } on MissingPluginException {
      return fallback.pick(source);
    } on UnimplementedError {
      return fallback.pick(source);
    } on PlatformException {
      return null;
    }
  }
}

/// Picks a sample photo from the app's own art after a short delay; null
/// backs out.
class DemoPhotoService implements PhotoService {
  DemoPhotoService({
    this.delay = const Duration(milliseconds: 400),
    this.asset = sample,
  });

  static const sample = 'assets/samples/covers/basket-ng-1.jpg';

  final Duration delay;
  String? asset;
  int picks = 0;

  @override
  bool get hasCamera => true;

  @override
  Future<Uint8List?> pick(PhotoSource source) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    picks++;
    final asset = this.asset;
    if (asset == null) return null;
    final data = await rootBundle.load(asset);
    return data.buffer.asUint8List();
  }
}

final photoServiceProvider = Provider<PhotoService>(
  (ref) => DevicePhotoService(),
);
