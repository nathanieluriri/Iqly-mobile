import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../data/api_client.dart';

/// The OneSignal app the API sends through. Public, like the Google client
/// ids; `--dart-define=ONESIGNAL_APP_ID=` (empty) leaves push off.
abstract final class PushConfig {
  static const oneSignalAppId = String.fromEnvironment(
    'ONESIGNAL_APP_ID',
    defaultValue: '5eec74b6-9fb7-45b8-afc6-812a97f9f5b8',
  );
}

/// The API's list of phones a signed-in person's pushes go to. A phone is
/// its OneSignal push subscription, registered under the session, so no
/// phone can claim someone else's notifications.
abstract class PushDevices {
  Future<void> register(String subscriptionId, String platform);
  Future<void> unregister(String subscriptionId);
}

class ApiPushDevices implements PushDevices {
  ApiPushDevices(this.api);

  final ApiClient api;

  @override
  Future<void> register(String subscriptionId, String platform) => api.post(
    '/notifications/devices',
    {'subscriptionId': subscriptionId, 'platform': platform},
  );

  @override
  Future<void> unregister(String subscriptionId) => api.post(
    '/notifications/devices/remove',
    {'subscriptionId': subscriptionId},
  );
}

/// The parts of the OneSignal SDK the app uses, so [Push] runs under test.
abstract class PushSdk {
  Future<void> initialize(String appId);
  String? get subscriptionId;
  bool get optedIn;
  void onSubscriptionChanged(VoidCallback listener);

  /// [data] is the push's additional data.
  void onOpened(void Function(Map<String, dynamic> data) listener);
  void onArrived(VoidCallback listener);
  Future<void> requestPermission();
}

class OneSignalSdk implements PushSdk {
  @override
  Future<void> initialize(String appId) => OneSignal.initialize(appId);

  @override
  String? get subscriptionId => OneSignal.User.pushSubscription.id;

  @override
  bool get optedIn => OneSignal.User.pushSubscription.optedIn ?? false;

  @override
  void onSubscriptionChanged(VoidCallback listener) =>
      OneSignal.User.pushSubscription.addObserver((_) => listener());

  @override
  void onOpened(void Function(Map<String, dynamic> data) listener) =>
      OneSignal.Notifications.addClickListener(
        (event) => listener(event.notification.additionalData ?? const {}),
      );

  @override
  void onArrived(VoidCallback listener) =>
      OneSignal.Notifications.addForegroundWillDisplayListener(
        (_) => listener(),
      );

  @override
  Future<void> requestPermission() async {
    await OneSignal.Notifications.requestPermission(false);
    await OneSignal.User.pushSubscription.optIn();
  }
}

/// Remote push. Each push carries the same route as a local notification
/// in its data, and Android styles it natively (IqlyPushExtension.kt) the
/// way Surfaces styles local ones.
class Push {
  Push({
    required this.devices,
    required this.signedIn,
    required this.onOpen,
    required this.onArrive,
    PushSdk? sdk,
    this.appId = PushConfig.oneSignalAppId,
    TargetPlatform? platform,
  }) : _sdk = sdk ?? OneSignalSdk(),
       _platform = platform ?? defaultTargetPlatform;

  final PushDevices devices;
  final bool Function() signedIn;
  final void Function(String route) onOpen;

  /// A push landed while iQLY is open: the bell count and feed refresh.
  final VoidCallback onArrive;
  final String appId;
  final PushSdk _sdk;
  final TargetPlatform _platform;

  bool _started = false;
  String? _registered;

  bool get supported =>
      !kIsWeb &&
      appId.isNotEmpty &&
      (_platform == TargetPlatform.android || _platform == TargetPlatform.iOS);

  Future<void> start() async {
    if (!supported || _started) return;
    _started = true;
    await _sdk.initialize(appId);
    _sdk.onOpened((data) {
      final route = data['route'];
      if (route is String) onOpen(route);
    });
    _sdk.onArrived(onArrive);
    _sdk.onSubscriptionChanged(() => unawaited(sync()));
    await sync();
  }

  /// After the phone's own prompt said yes: subscribes this phone.
  Future<void> permissionGranted() async {
    if (!_started) return;
    await _guard(_sdk.requestPermission);
    await sync();
  }

  /// Registers this phone for the signed-in person, once per subscription.
  Future<void> sync() async {
    if (!_started || !signedIn()) return;
    final id = _sdk.subscriptionId;
    if (id == null || !_sdk.optedIn || id == _registered) return;
    await _guard(() async {
      await devices.register(id, _platform.name);
      _registered = id;
    });
  }

  /// Before the session ends, so the phone stops getting the account's
  /// pushes.
  Future<void> signingOut() async {
    final id = _registered ?? (_started ? _sdk.subscriptionId : null);
    _registered = null;
    if (id == null) return;
    await _guard(() => devices.unregister(id));
  }

  /// The API ended the session itself, so there is nothing to unregister,
  /// and the next sign-in registers this phone again.
  void sessionLost() => _registered = null;

  static Future<void> _guard(Future<void> Function() call) async {
    try {
      await call().timeout(const Duration(seconds: 8));
    } on Object catch (error) {
      debugPrint('Push: $error');
    }
  }
}

/// Null under test and wherever main.dart did not start push.
final pushProvider = Provider<Push?>((ref) => null);
