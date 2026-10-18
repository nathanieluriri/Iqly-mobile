import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// The phone's own check (Face ID, fingerprint) for confirming a withdrawal
/// (designer answer 4). When it is missing or refused the app asks for the
/// iQLY PIN instead.
abstract class BiometricService {
  /// Whether the phone can check the person, and what it calls the check.
  Future<BiometricKind?> available();

  /// Asks the phone to check the person; false when they cancel or fail.
  Future<bool> confirm(String reason);
}

enum BiometricKind {
  face('Face ID'),
  fingerprint('fingerprint');

  const BiometricKind(this.label);

  final String label;

  String get capitalised => label[0].toUpperCase() + label.substring(1);
}

/// The phone's sensor through local_auth: biometrics only, so the phone's
/// own passcode never stands in for the person. Any plugin failure reads
/// as no sensor or a refused check, and the PIN takes over.
class DeviceBiometrics implements BiometricService {
  DeviceBiometrics([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<BiometricKind?> available() async {
    try {
      if (!await _auth.isDeviceSupported() || !await _auth.canCheckBiometrics) {
        return null;
      }
      final types = await _auth.getAvailableBiometrics();
      if (types.isEmpty) return null;
      return types.contains(BiometricType.face) &&
              !types.contains(BiometricType.fingerprint)
          ? BiometricKind.face
          : BiometricKind.fingerprint;
    } on Object {
      return null;
    }
  }

  @override
  Future<bool> confirm(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on Object {
      return false;
    }
  }
}

/// The demo and tests have no sensor, so every withdrawal goes through the
/// PIN.
class NoBiometrics implements BiometricService {
  const NoBiometrics();

  @override
  Future<BiometricKind?> available() async => null;

  @override
  Future<bool> confirm(String reason) async => false;
}

final biometricServiceProvider = Provider<BiometricService>(
  (ref) => const NoBiometrics(),
);

/// The iQLY PIN kept on this phone for one account once the person turns on
/// the phone's check for withdrawals: a live withdrawal carries the PIN, so
/// the check unlocks the kept copy rather than standing in for it.
abstract class PinVault {
  Future<String?> read(String account);
  Future<void> write(String account, String pin);
  Future<void> clear(String account);
}

/// The Keychain on iOS (this device only) and Keystore-wrapped AES on
/// Android, as the session token is kept.
class SecurePinVault implements PinVault {
  SecurePinVault([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.unlocked_this_device,
            ),
          );

  final FlutterSecureStorage _storage;

  static String _key(String account) => 'iqly.withdrawPin.$account';

  @override
  Future<String?> read(String account) async {
    try {
      return await _storage.read(key: _key(account));
    } on Object {
      return null;
    }
  }

  @override
  Future<void> write(String account, String pin) =>
      _storage.write(key: _key(account), value: pin);

  @override
  Future<void> clear(String account) async {
    try {
      await _storage.delete(key: _key(account));
    } on Object {
      return;
    }
  }
}

class MemoryPinVault implements PinVault {
  final _pins = <String, String>{};

  @override
  Future<String?> read(String account) async => _pins[account];

  @override
  Future<void> write(String account, String pin) async => _pins[account] = pin;

  @override
  Future<void> clear(String account) async => _pins.remove(account);
}

final pinVaultProvider = Provider<PinVault>((ref) => MemoryPinVault());
