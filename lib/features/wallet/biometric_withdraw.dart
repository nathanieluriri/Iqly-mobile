import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion.dart';
import '../../core/session.dart';
import '../../core/transitions.dart';
import '../../data/biometric_service.dart';
import '../../ui/toast.dart';
import 'pin_sheet.dart';

/// The phone's check for live withdrawals (owner, 18 Oct): what the phone
/// offers, and whether this account has turned it on here.
typedef BiometricWithdraw = ({BiometricKind? kind, bool on});

final biometricWithdrawProvider = FutureProvider.autoDispose<BiometricWithdraw>(
  (ref) async {
    final kind = await ref.watch(biometricServiceProvider).available();
    final account = ref.watch(sessionProvider).userId;
    final on =
        kind != null &&
        account != null &&
        await ref.watch(pinVaultProvider).read(account) != null;
    return (kind: kind, on: on);
  },
);

/// The kept PIN once the phone has checked the person, or null when the
/// check is off, missing or refused, so the PIN sheet asks instead.
Future<String?> pinFromBiometrics(WidgetRef ref, String reason) async {
  final account = ref.read(sessionProvider).userId;
  if (account == null) return null;
  final pin = await ref.read(pinVaultProvider).read(account);
  if (pin == null) return null;
  final biometrics = ref.read(biometricServiceProvider);
  if (await biometrics.available() == null) return null;
  return await biometrics.confirm(reason) ? pin : null;
}

/// A kept PIN the API refused (changed or reset elsewhere) is dropped, and
/// the check turns itself off until the person turns it on again.
Future<void> forgetBiometricPin(WidgetRef ref) async {
  final account = ref.read(sessionProvider).userId;
  if (account == null) return;
  await ref.read(pinVaultProvider).clear(account);
  ref.invalidate(biometricWithdrawProvider);
}

/// Turns the check on (the PIN once, checked by the API, then the phone's
/// own check) or off.
Future<void> setBiometricWithdraw(
  BuildContext context,
  WidgetRef ref,
  bool on,
) async {
  final account = ref.read(sessionProvider).userId;
  final vault = ref.read(pinVaultProvider);
  if (account == null) return;
  if (!on) {
    await vault.clear(account);
    ref.invalidate(biometricWithdrawProvider);
    return;
  }
  final biometrics = ref.read(biometricServiceProvider);
  final kind = await biometrics.available();
  if (kind == null || !context.mounted) return;
  final pin = await showIqSheet<String>(
    Navigator.of(context, rootNavigator: true).context,
    (context) => Material(
      type: MaterialType.transparency,
      child: PinSheet(
        body:
            'Enter your iQLY PIN once. After that your ${kind.label} '
            'confirms every withdrawal on this phone.',
        action: 'Continue',
        offerBiometric: false,
      ),
    ),
    scrim: IqScrim.sheet,
  );
  if (pin == null || pin.isEmpty) return;
  if (!await biometrics.confirm('Turn on ${kind.label} for withdrawals')) {
    return;
  }
  await vault.write(account, pin);
  ref.invalidate(biometricWithdrawProvider);
  IqHaptics.success.play();
  if (context.mounted) {
    IqToast.show(context, '${kind.capitalised} turned on for withdrawals');
  }
}
