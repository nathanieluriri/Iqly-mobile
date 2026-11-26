import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/assessments/screen_guard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(ScreenGuard.name);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('asks the phone to lock the screen', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
    await ScreenGuard().setSecure(true);
    expect(calls.single.method, 'setSecure');
    expect(calls.single.arguments, isTrue);
  });

  test('a missing native half is not an error', () async {
    await ScreenGuard().setSecure(false);
  });
}
