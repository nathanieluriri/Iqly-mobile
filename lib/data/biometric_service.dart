import 'package:flutter_riverpod/flutter_riverpod.dart';

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
}

/// The demo and tests have no sensor, so every withdrawal goes through the
/// PIN. A platform implementation replaces it once a plugin is chosen.
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
