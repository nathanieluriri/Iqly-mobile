import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/device.dart';
import '../../data/models.dart';
import '../../data/profile_service.dart';
import '../../data/repository.dart';

/// The switches of Notification preferences. A flip shows at once and goes
/// back if the account does not take it.
class NotificationPreferencesNotifier
    extends AsyncNotifier<Map<NotificationTopic, bool>> {
  @override
  Future<Map<NotificationTopic, bool>> build() =>
      ref.read(profileServiceProvider).notificationPreferences();

  /// False when the account refused it and the switch went back.
  Future<bool> set(NotificationTopic topic, bool on) async {
    final before = state.value;
    if (before == null) return false;
    state = AsyncData({...before, topic: on});
    try {
      await ref
          .read(profileServiceProvider)
          .setNotificationPreference(topic, on);
      return true;
    } on Exception {
      final now = state.value ?? before;
      state = AsyncData({...now, topic: before[topic] ?? !on});
      return false;
    }
  }
}

final notificationPreferencesProvider =
    AsyncNotifierProvider<
      NotificationPreferencesNotifier,
      Map<NotificationTopic, bool>
    >(NotificationPreferencesNotifier.new);

/// What Delete account weighs: the available balance to withdraw first and
/// what is already on its way (walletTotals, as on the web).
final accountWalletProvider = FutureProvider<WalletTotals>((ref) async {
  final repo = ref.watch(repositoryProvider);
  final (ledger, withdrawals) = await (repo.ledger(), repo.withdrawals()).wait;
  return walletTotals(ledger, withdrawals);
});

/// Whether the phone lets iQLY notify; checked each time preferences open.
final notificationsAllowedProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(deviceServiceProvider).notificationsAllowed(),
);
