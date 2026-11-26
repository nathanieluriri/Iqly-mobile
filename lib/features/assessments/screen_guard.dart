import 'package:flutter/services.dart';

/// Blocks screenshots and recordings on the test screen.
class ScreenGuard {
  ScreenGuard([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel(name);

  static const name = 'net.iqly/secure';

  final MethodChannel _channel;

  Future<void> setSecure(bool on) async {
    try {
      await _channel.invokeMethod<bool>('setSecure', on);
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  void onCaptured(void Function() handler) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'captured') handler();
    });
  }
}
