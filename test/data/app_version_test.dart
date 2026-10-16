import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iqly_mobile/data/app_version.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'iQLY',
      packageName: 'net.iqly.app',
      version: '0.1.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  LiveAppVersionService serviceAnswering(
    int status,
    Object body,
    List<http.Request> requests,
  ) => LiveAppVersionService(
    baseUrl: 'https://staging.api.iqly.net',
    client: MockClient((request) async {
      requests.add(request);
      return http.Response(jsonEncode(body), status);
    }),
  );

  test('asks for this build on this platform', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final requests = <http.Request>[];
    final release = await serviceAnswering(200, {
      'success': true,
      'data': {
        'status': 'update_required',
        'minimum': '0.2.0',
        'latest': '0.2.0+4',
        'updateUrl': 'https://staging.api.iqly.net/mobile/download/android',
      },
    }, requests).check();

    final url = requests.single.url;
    expect(url.path, '/mobile/app-version');
    expect(url.queryParameters, {'platform': 'android', 'version': '0.1.0+1'});
    expect(url.query, contains('0.1.0%2B1'));
    expect(release.installed, '0.1.0+1');
    expect(release.status, UpdateStatus.required);
    expect(release.minimum, '0.2.0');
    expect(release.latest, '0.2.0+4');
    expect(
      release.updateUrl,
      Uri.parse('https://staging.api.iqly.net/mobile/download/android'),
    );
  });

  test('names iOS the way the API does', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(LiveAppVersionService.platform, 'ios');
  });

  test('asks without the session token', () async {
    final requests = <http.Request>[];
    await serviceAnswering(200, {}, requests).check();
    expect(requests.single.headers.containsKey('authorization'), isFalse);
  });

  test('anything but a clear answer reads as current', () async {
    final release = await serviceAnswering(400, {
      'success': false,
    }, <http.Request>[]).check();
    expect(release.status, UpdateStatus.ok);

    final odd = AppRelease.fromJson('0.1.0+1', {'status': 'later'});
    expect(odd.status, UpdateStatus.ok);
  });

  test('reads an available build', () {
    final release = AppRelease.fromJson('0.1.0+1', {
      'status': 'update_available',
      'latest': '0.1.0+2',
      'updateUrl': 'https://staging.api.iqly.net/mobile/download/android',
    });
    expect(release.status, UpdateStatus.available);
    expect(release.minimum, isNull);
  });

  test('a version reads without its build number', () {
    expect(versionName('0.2.0+4'), '0.2.0');
    expect(versionName('0.2.0'), '0.2.0');
  });
}
