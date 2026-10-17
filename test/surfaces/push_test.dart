import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/surfaces/push.dart';

class _Sdk implements PushSdk {
  String? id;
  bool opted = true;
  int permissionAsks = 0;
  VoidCallback? changed;
  void Function(Map<String, dynamic>)? opened;
  VoidCallback? arrived;

  @override
  Future<void> initialize(String appId) async {}

  @override
  String? get subscriptionId => id;

  @override
  bool get optedIn => opted;

  @override
  void onSubscriptionChanged(VoidCallback listener) => changed = listener;

  @override
  void onOpened(void Function(Map<String, dynamic>) listener) =>
      opened = listener;

  @override
  void onArrived(VoidCallback listener) => arrived = listener;

  @override
  Future<void> requestPermission() async => permissionAsks++;
}

class _Devices implements PushDevices {
  final calls = <String>[];

  @override
  Future<void> register(String subscriptionId, String platform) async =>
      calls.add('register $subscriptionId $platform');

  @override
  Future<void> unregister(String subscriptionId) async =>
      calls.add('unregister $subscriptionId');
}

void main() {
  late _Sdk sdk;
  late _Devices devices;
  late bool signedIn;
  late List<String> opened;
  late int arrivals;

  setUp(() {
    sdk = _Sdk();
    devices = _Devices();
    signedIn = true;
    opened = [];
    arrivals = 0;
  });

  Push push({String appId = 'app'}) => Push(
    devices: devices,
    signedIn: () => signedIn,
    onOpen: opened.add,
    onArrive: () => arrivals++,
    sdk: sdk,
    appId: appId,
    platform: TargetPlatform.android,
  );

  test('without an app id push stays off', () async {
    sdk.id = 's1';
    final p = push(appId: '');
    await p.start();
    expect(p.supported, isFalse);
    expect(devices.calls, isEmpty);
    expect(sdk.changed, isNull);
  });

  test('a signed-in phone registers its subscription once', () async {
    sdk.id = 's1';
    final p = push();
    await p.start();
    await p.sync();
    expect(devices.calls, ['register s1 android']);

    sdk.id = 's2';
    sdk.changed!();
    await Future<void>.delayed(Duration.zero);
    expect(devices.calls, ['register s1 android', 'register s2 android']);
  });

  test(
    'nothing registers before sign-in or before the phone opts in',
    () async {
      signedIn = false;
      sdk.id = 's1';
      final p = push();
      await p.start();
      expect(devices.calls, isEmpty);

      signedIn = true;
      sdk.opted = false;
      await p.sync();
      expect(devices.calls, isEmpty);

      await p.permissionGranted();
      expect(sdk.permissionAsks, 1);
      sdk.opted = true;
      await p.sync();
      expect(devices.calls, ['register s1 android']);
    },
  );

  test('signing out unregisters the phone first', () async {
    sdk.id = 's1';
    final p = push();
    await p.start();
    await p.signingOut();
    expect(devices.calls, ['register s1 android', 'unregister s1']);
  });

  test('a session the API ended sends nothing, and the next sign-in '
      'registers the phone again', () async {
    sdk.id = 's1';
    final p = push();
    await p.start();
    p.sessionLost();
    expect(devices.calls, ['register s1 android']);
    await p.sync();
    expect(devices.calls, ['register s1 android', 'register s1 android']);
  });

  test('a tap opens the route the push carries; arrivals refresh', () async {
    final p = push();
    await p.start();
    sdk.opened!({'route': '/wallet/withdrawals/w3'});
    sdk.opened!({'other': 1});
    sdk.arrived!();
    expect(opened, ['/wallet/withdrawals/w3']);
    expect(arrivals, 1);
  });
}
