import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/polls_data.dart';
import 'package:iqly_mobile/surfaces/live_activity.dart';
import 'package:iqly_mobile/surfaces/surfaces.dart';
import 'package:iqly_mobile/surfaces/widget_snapshot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 10, 3, 9, 41);
  const channel = MethodChannel(SurfacesBridge.name);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('publishes the timeline and thumbnails', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
    final timeline = WidgetTimeline.of(
      briefs: DemoData(now: now).briefs,
      polls: demoPolls(now),
      now: now,
    );
    final ok = await SurfacesBridge().publishWidgets(timeline, {
      'thumb_sunline.png': Uint8List.fromList([1, 2]),
    });
    expect(ok, isTrue);
    expect(calls.single.method, 'publishWidgets');
    final args = calls.single.arguments as Map;
    expect((args['timeline'] as Map)['version'], 1);
    expect((args['thumbs'] as Map).keys, ['thumb_sunline.png']);
  });

  test('a missing native half is not an error', () async {
    final w3 = DemoData(now: now).withdrawals.first;
    final bridge = SurfacesBridge();
    expect(
      await bridge.payoutActivity(
        PayoutActivityState.of(w3, notificationId: 'n1')!,
      ),
      isFalse,
    );
    expect(await bridge.takeLaunchLink(), isNull);
  });

  test('the method channel name matches both native halves', () {
    final kotlin = File(
      'android/app/src/main/kotlin/net/iqly/app/SurfacesChannel.kt',
    ).readAsStringSync();
    final swift = File('ios/RunnerSurfaces/SurfacesChannel.swift')
        .readAsStringSync();
    expect(kotlin, contains('"${SurfacesBridge.name}"'));
    expect(swift, contains('"${SurfacesBridge.name}"'));
  });

  test('generated native assets are current', () async {
    final result = await Process.run('dart', [
      'run',
      'tool/gen_surface_assets.dart',
      '--check',
    ]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
  });
}
