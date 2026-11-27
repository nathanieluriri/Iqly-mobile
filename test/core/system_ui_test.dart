import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/system_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('Android startup requests edge-to-edge mode', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    await configureEdgeToEdge();

    expect(calls.map((call) => call.method), [
      'SystemChrome.setEnabledSystemUIMode',
    ]);
    expect(calls.single.arguments, SystemUiMode.edgeToEdge.toString());
  });

  test('other platforms keep their default system UI mode', () async {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.windows]) {
      calls.clear();
      debugDefaultTargetPlatformOverride = platform;

      await configureEdgeToEdge();

      expect(calls, isEmpty, reason: '$platform should keep its default mode');
    }
  });

  test('paper overlays keep dark icons on transparent bars', () {
    final style = IqSystemUi.paper;

    expect(style.statusBarColor, Colors.transparent);
    expect(style.systemNavigationBarColor, Colors.transparent);
    expect(style.systemNavigationBarDividerColor, Colors.transparent);
    expect(style.statusBarIconBrightness, Brightness.dark);
    expect(style.systemNavigationBarIconBrightness, Brightness.dark);
    expect(style.statusBarBrightness, Brightness.light);
    expect(style.systemStatusBarContrastEnforced, isFalse);
    expect(style.systemNavigationBarContrastEnforced, isFalse);
  });

  test('ink overlays keep light icons on transparent bars', () {
    final style = IqSystemUi.ink;

    expect(style.statusBarColor, Colors.transparent);
    expect(style.systemNavigationBarColor, Colors.transparent);
    expect(style.systemNavigationBarDividerColor, Colors.transparent);
    expect(style.statusBarIconBrightness, Brightness.light);
    expect(style.systemNavigationBarIconBrightness, Brightness.light);
    expect(style.statusBarBrightness, Brightness.dark);
    expect(style.systemStatusBarContrastEnforced, isFalse);
    expect(style.systemNavigationBarContrastEnforced, isFalse);
  });
}
