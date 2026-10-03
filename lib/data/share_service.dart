import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The system share sheet. The real one wraps share_plus (shareXFiles with
/// the PNG); the demo keeps what it was asked to share.
abstract class ShareService {
  Future<void> shareImage(Uint8List png, {required String name, String? text});
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
}

final shareServiceProvider = Provider<ShareService>(
  (ref) => DemoShareService(),
);
