import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Platform capabilities the screens ask for. The demo resolves without
/// touching the OS; the real one wraps the plugins named on each method.
abstract class DeviceService {
  /// The phone's own prompt (Android 13+ and iOS); true when iQLY may
  /// notify afterwards.
  Future<bool> requestNotificationPermission();

  /// Whether the phone lets iQLY notify.
  Future<bool> notificationsAllowed();

  /// The phone's notification settings for iQLY.
  Future<void> openNotificationSettings();

  /// android_intent_plus (main/APP_EMAIL) and url_launcher (message: on iOS);
  /// mailto: would open a compose sheet, not the inbox.
  Future<void> openEmailApp();

  /// url_launcher.
  Future<void> openUrl(Uri url);
}

class DemoDeviceService implements DeviceService {
  DemoDeviceService({this.delay = const Duration(milliseconds: 300)});

  final Duration delay;
  final List<Uri> opened = [];
  bool notificationsOn = true;
  int settingsOpened = 0;

  @override
  Future<bool> notificationsAllowed() async => notificationsOn;

  @override
  Future<void> openNotificationSettings() async => settingsOpened++;

  @override
  Future<bool> requestNotificationPermission() async {
    await Future<void>.delayed(delay);
    return true;
  }

  @override
  Future<void> openEmailApp() => Future<void>.delayed(delay);

  @override
  Future<void> openUrl(Uri url) async {
    opened.add(url);
  }
}

/// The phone itself: links open in the browser or the app that owns them,
/// and notification permission is the OS's own, through
/// flutter_local_notifications. The email app still stands in.
class PlatformDeviceService implements DeviceService {
  PlatformDeviceService({
    FlutterLocalNotificationsPlugin? notifications,
    DeviceService? rest,
  }) : _notifications = notifications ?? FlutterLocalNotificationsPlugin(),
       _rest = rest ?? DemoDeviceService();

  final FlutterLocalNotificationsPlugin _notifications;
  final DeviceService _rest;

  AndroidFlutterLocalNotificationsPlugin? get _android => _notifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => _notifications
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> openUrl(Uri url) =>
      launchUrl(url, mode: LaunchMode.externalApplication);

  @override
  Future<bool> requestNotificationPermission() async {
    final android = _android;
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _ios;
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return true;
  }

  @override
  Future<bool> notificationsAllowed() async {
    final android = _android;
    if (android != null) return await android.areNotificationsEnabled() ?? true;
    final ios = _ios;
    if (ios != null) return (await ios.checkPermissions())?.isEnabled ?? true;
    return true;
  }

  @override
  Future<void> openNotificationSettings() async {
    final android = _android;
    if (android != null) {
      await android.openAppNotificationSettings();
      return;
    }
    await _ios?.openAppNotificationSettings();
  }

  @override
  Future<void> openEmailApp() => _rest.openEmailApp();
}

final deviceServiceProvider = Provider<DeviceService>(
  (ref) => DemoDeviceService(),
);

abstract final class LegalLinks {
  static final terms = Uri.parse('https://iqly.net/legal/terms-of-service');
  static final privacy = Uri.parse('https://iqly.net/legal/privacy-policy');
}
