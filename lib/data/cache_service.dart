import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Saved briefs and images kept on the phone (B7 · Clear cache sheet).
abstract class CacheService {
  Future<int> sizeBytes();
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

final cacheServiceProvider = Provider<CacheService>(
  (ref) => DemoCacheService(),
);

/// "42 MB".
String megabytes(int bytes) => '${(bytes / 1000000).round()} MB';
