import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/haptics.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/setting_row.dart';
import 'package:iqly_mobile/ui/switch.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../golden/golden.dart' show loadAppFonts;
import '../golden/screens/more_harness.dart';

List<String> _haptics(WidgetTester tester) {
  final played = <String>[];
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'HapticFeedback.vibrate') {
      played.add(call.arguments as String);
    }
    return null;
  });
  addTearDown(
    () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return played;
}

void main() {
  setUpAll(loadAppFonts);
  tearDown(() => IqHaptics.enabled = true);

  test('on by default, and what was kept is honoured at launch', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    ProviderContainer launch() {
      final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(c.dispose);
      return c;
    }

    final first = launch();
    expect(first.read(hapticsProvider), isTrue);
    expect(IqHaptics.enabled, isTrue);
    await first.read(hapticsProvider.notifier).set(false);
    expect(prefs.getBool(HapticsNotifier.key), isFalse);

    IqHaptics.enabled = true;
    expect(launch().read(hapticsProvider), isFalse);
    expect(IqHaptics.enabled, isFalse);
  });

  testWidgets('the Haptics switch on Your profile turns every haptic off and '
      'back on', (tester) async {
    final played = _haptics(tester);
    final container = await pumpMore(tester, Routes.profile);
    final row = find.widgetWithText(IqSettingRow, 'Haptics');
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    expect(tester.widget<IqSettingRow>(row).state, IqSwitchState.on);

    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(tester.widget<IqSettingRow>(row).state, IqSwitchState.off);
    expect(container.read(hapticsProvider), isFalse);
    played.clear();
    for (final haptic in IqHaptics.values) {
      await haptic.play();
    }
    await tester.pump(const Duration(milliseconds: 100));
    expect(played, isEmpty);

    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(container.read(hapticsProvider), isTrue);
    await IqHaptics.destructive.play();
    expect(played, ['HapticFeedbackType.heavyImpact']);
  });
}
