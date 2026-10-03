import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Platform capabilities the screens ask for. The demo resolves without
/// touching the OS; the real one wraps the plugins named on each method.
abstract class DeviceService {
  /// permission_handler or firebase_messaging.
  Future<bool> requestNotificationPermission();

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

final deviceServiceProvider = Provider<DeviceService>(
  (ref) => DemoDeviceService(),
);

abstract final class LegalLinks {
  static final terms = Uri.parse('https://iqly.net/legal/terms-of-service');
  static final privacy = Uri.parse('https://iqly.net/legal/privacy-policy');
}
