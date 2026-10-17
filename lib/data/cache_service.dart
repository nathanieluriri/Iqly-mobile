import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session.dart';
import 'live/live_repository.dart';
import 'local/local_providers.dart';
import 'local/local_store.dart';

/// Saved briefs and images kept on the phone (B7 · Clear cache sheet).
abstract class CacheService {
  /// What clearing frees, in bytes; null when it cannot be counted.
  Future<int?> sizeBytes();
  Future<void> clear();
}

/// The frame's 42 MB until cleared.
class DemoCacheService implements CacheService {
  int bytes = 42000000;

  @override
  Future<int> sizeBytes() async => bytes;

  @override
  Future<void> clear() async => bytes = 0;
}

/// A live launch: the API answers [store] keeps for [userId], and the
/// images the app holds. Drafts and the outbox stay (plan 4.9). The images
/// live in memory only, so the size counts the kept answers alone.
class LiveCacheService implements CacheService {
  LiveCacheService(this.store, this.userId, {ImageCache Function()? images})
    : _images = images ?? (() => PaintingBinding.instance.imageCache);

  final LocalStore store;
  final String? userId;
  final ImageCache Function() _images;

  @override
  Future<int?> sizeBytes() async {
    final id = userId;
    final store = this.store;
    if (id == null) return 0;
    if (store is! CacheBytes) return null;
    try {
      return await (store as CacheBytes).cacheBytes(id);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> clear() async {
    final id = userId;
    if (id != null) await store.deleteCache(id);
    _images()
      ..clear()
      ..clearLiveImages();
  }
}

/// The demo's in a preview launch; the signed-in person's in a live one.
final cacheServiceProvider = Provider<CacheService>((ref) {
  if (ref.watch(liveModeProvider).isPreview) return DemoCacheService();
  final account = ref.watch(accountProvider);
  return LiveCacheService(
    ref.watch(localStoreProvider),
    account == null || account.isEmpty ? null : account,
  );
});

/// "42 MB", or "120 KB" under a megabyte.
String storageSize(int bytes) => bytes >= 1000000
    ? '${(bytes / 1000000).round()} MB'
    : '${(bytes / 1000).ceil()} KB';
