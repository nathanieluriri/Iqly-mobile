import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'api_client.dart';
import 'api_config.dart';
import 'token_store.dart';

enum UpdateStatus { ok, available, required }

/// What the API says about this build (GET /mobile/app-version).
class AppRelease {
  const AppRelease({
    required this.installed,
    this.status = UpdateStatus.ok,
    this.minimum,
    this.latest,
    this.updateUrl,
  });

  /// This build, as pubspec.yaml names it: 0.1.0+1.
  final String installed;
  final UpdateStatus status;
  final String? minimum;
  final String? latest;
  final Uri? updateUrl;

  factory AppRelease.fromJson(String installed, Map<String, dynamic> data) {
    final url = data['updateUrl'];
    return AppRelease(
      installed: installed,
      status: switch (data['status']) {
        'update_required' => UpdateStatus.required,
        'update_available' => UpdateStatus.available,
        _ => UpdateStatus.ok,
      },
      minimum: data['minimum'] as String?,
      latest: data['latest'] as String?,
      updateUrl: url is String ? Uri.tryParse(url) : null,
    );
  }
}

/// A version without its build number, as people read it: 0.1.0.
String versionName(String version) => version.split('+').first;

abstract class AppVersionService {
  Future<AppRelease> check();
}

/// Asks without the session token: the answer is the same for everyone, and
/// it comes before sign-in too.
class LiveAppVersionService implements AppVersionService {
  LiveAppVersionService({
    http.Client? client,
    String baseUrl = ApiConfig.baseUrl,
  }) : _api = ApiClient(
         tokens: MemoryTokenStore(),
         client: client,
         baseUrl: baseUrl,
       );

  final ApiClient _api;

  static String get platform => switch (defaultTargetPlatform) {
    TargetPlatform.iOS => 'ios',
    final other => other.name,
  };

  static Future<String> installedVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.buildNumber.isEmpty
        ? info.version
        : '${info.version}+${info.buildNumber}';
  }

  @override
  Future<AppRelease> check() async {
    final installed = await installedVersion();
    final path = Uri(
      path: '/mobile/app-version',
      queryParameters: {'platform': platform, 'version': installed},
    );
    final response = await _api.get(path.toString());
    if (!response.ok) return AppRelease(installed: installed);
    return AppRelease.fromJson(installed, response.data);
  }
}

/// The demo build is always current.
class DemoAppVersionService implements AppVersionService {
  const DemoAppVersionService([this.release]);

  final AppRelease? release;

  @override
  Future<AppRelease> check() async =>
      release ?? const AppRelease(installed: '0.1.0+1');
}

final appVersionServiceProvider = Provider<AppVersionService>(
  (ref) => const DemoAppVersionService(),
);
