import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'motion.dart';
import 'session.dart';

/// The Haptics preference: on unless the person turned it off, kept on this
/// phone only. [IqHaptics.enabled] follows it, so every haptic honours it.
class HapticsNotifier extends Notifier<bool> {
  static const key = 'prefs.haptics';

  @override
  bool build() {
    final on = ref.watch(sharedPreferencesProvider).getBool(key) ?? true;
    IqHaptics.enabled = on;
    return on;
  }

  Future<void> set(bool on) async {
    IqHaptics.enabled = on;
    state = on;
    await ref.read(sharedPreferencesProvider).setBool(key, on);
  }
}

final hapticsProvider = NotifierProvider<HapticsNotifier, bool>(
  HapticsNotifier.new,
);
