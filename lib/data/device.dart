import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Platform capabilities the screens ask for. The demo resolves without
/// touching the OS; the real one wraps the plugins named on each method.
abstract class DeviceService {
  /// permission_handler or firebase_messaging.
  Future<bool> requestNotificationPermission();

  /// Whether the phone lets iQLY notify (permission_handler).
  Future<bool> notificationsAllowed();

  /// The phone's notification settings for iQLY (app_settings).
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

/// The phone itself: links open in the browser or the app that owns them.
/// The other capabilities still stand in until their plugins land.
class PlatformDeviceService implements DeviceService {
  PlatformDeviceService([DeviceService? rest])
    : _rest = rest ?? DemoDeviceService();

  final DeviceService _rest;

  @override
  Future<void> openUrl(Uri url) =>
      launchUrl(url, mode: LaunchMode.externalApplication);

  @override
  Future<bool> requestNotificationPermission() =>
      _rest.requestNotificationPermission();

  @override
  Future<bool> notificationsAllowed() => _rest.notificationsAllowed();

  @override
  Future<void> openNotificationSettings() => _rest.openNotificationSettings();

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
