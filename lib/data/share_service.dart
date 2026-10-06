import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The system share sheet. The real one wraps share_plus (shareXFiles with
/// the PNG); the demo keeps what it was asked to share.
abstract class ShareService {
  Future<void> shareImage(Uint8List png, {required String name, String? text});

  /// Straight to [app] when it is installed (its share intent or URL
  /// scheme), else the system share sheet.
  Future<void> shareImageTo(
    ShareApp app,
    Uint8List png, {
    required String name,
    String? text,
  });

  /// Into the photo library; false when the person refused access.
  Future<bool> saveImage(Uint8List png, {required String name});
}

class DemoShareService implements ShareService {
  final shared = <({String name, String? text, int bytes})>[];

  @override
  Future<void> shareImage(
    Uint8List png, {
    required String name,
    String? text,
  }) async {
    shared.add((name: name, text: text, bytes: png.length));
  }

  final sharedTo = <({ShareApp app, String name, String? text, int bytes})>[];
  final saved = <({String name, int bytes})>[];

  @override
  Future<void> shareImageTo(
    ShareApp app,
    Uint8List png, {
    required String name,
    String? text,
  }) async {
    sharedTo.add((app: app, name: name, text: text, bytes: png.length));
  }

  @override
  Future<bool> saveImage(Uint8List png, {required String name}) async {
    saved.add((name: name, bytes: png.length));
    return true;
  }
}

final shareServiceProvider = Provider<ShareService>(
  (ref) => DemoShareService(),
);

/// The apps the share sheet offers by name (Exp/ShareTarget).
enum ShareApp { whatsapp, instagram, x, telegram }
