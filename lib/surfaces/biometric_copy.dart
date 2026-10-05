import '../core/money.dart';
import 'surface_copy.dart';

/// The words the app hands the system biometric prompt at withdraw
/// (350:17937 BiometricSheet, 347:16539 Face ID). The Wallet lane passes
/// these to local_auth; the sheet itself is the OS's.
class BiometricCopy {
  const BiometricCopy({
    required this.title,
    required this.subtitle,
    required this.hint,
    required this.cancel,
    required this.fallback,
  });

  final String title;

  /// Android subtitle, and the iOS localizedReason.
  final String subtitle;
  final String hint;
  final String cancel;

  /// Leaves the system prompt for the iQLY 4-digit PIN.
  final String fallback;

  factory BiometricCopy.withdraw({
    required int amountKobo,
    required String destination,
  }) => BiometricCopy(
    title: SurfaceCopy.confirmItIsYou,
    subtitle: SurfaceCopy.withdrawTo(naira(amountKobo), destination),
    hint: SurfaceCopy.touchSensor,
    cancel: SurfaceCopy.cancel,
    fallback: SurfaceCopy.usePin,
  );
}
