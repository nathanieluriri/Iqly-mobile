import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/device.dart';

const _channel = MethodChannel('dexterous.com/flutter/local_notifications');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;
  late Map<String, Object?> answers;

  setUp(() {
    calls = [];
    answers = {};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add(call);
          return answers[call.method];
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  List<String> methods() => [for (final c in calls) c.method];

  group('Android', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
    });

    test(
      "Turn on shows the phone's own prompt and reports the answer",
      () async {
        answers['requestNotificationsPermission'] = false;
        final device = PlatformDeviceService();
        expect(await device.requestNotificationPermission(), isFalse);
        answers['requestNotificationsPermission'] = true;
        expect(await device.requestNotificationPermission(), isTrue);
        expect(methods(), [
          'requestNotificationsPermission',
          'requestNotificationsPermission',
        ]);
      },
    );

    test('the preferences banner reads the phone, and Open settings opens '
        "the app's notification settings", () async {
      answers['areNotificationsEnabled'] = false;
      final device = PlatformDeviceService();
      expect(await device.notificationsAllowed(), isFalse);
      await device.openNotificationSettings();
      expect(methods(), [
        'areNotificationsEnabled',
        'openAppNotificationSettings',
      ]);
    });
  });

  group('iOS', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      IOSFlutterLocalNotificationsPlugin.registerWith();
    });

    test('Turn on asks for alerts, badges and sounds', () async {
      answers['requestPermissions'] = true;
      final device = PlatformDeviceService();
      expect(await device.requestNotificationPermission(), isTrue);
      final call = calls.single;
      expect(call.method, 'requestPermissions');
      final args = (call.arguments as Map).cast<String, bool>();
      expect(args['alert'], isTrue);
      expect(args['badge'], isTrue);
      expect(args['sound'], isTrue);
    });

    test('allowed reads the phone; settings open on the phone', () async {
      answers['checkPermissions'] = {'isEnabled': false};
      final device = PlatformDeviceService();
      expect(await device.notificationsAllowed(), isFalse);
      await device.openNotificationSettings();
      expect(methods(), ['checkPermissions', 'openAppNotificationSettings']);
    });
  });
}
