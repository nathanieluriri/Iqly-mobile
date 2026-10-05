import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/app.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/auth.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/device.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/next_fab.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iqly_mobile/data/activations_service.dart';

/// The whole app on a 390 x 844 phone with reduced motion and instant
/// services and data. Without [start] it plays the splash through to the landing.
/// [prepare] seeds providers before the first route. With [reduced] false
/// the motion plays and the app opens straight on [start], its entrance
/// still to play.
Future<ProviderContainer> bootApp(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  String? start,
  AuthService? auth,
  DemoDeviceService? device,
  void Function(ProviderContainer container)? prepare,
  bool reduced = true,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  if (reduced) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  SharedPreferences.setMockInitialValues(prefs);
  final shared = await SharedPreferences.getInstance();
  final router = !reduced && start != null
      ? buildRouter(initialLocation: start)
      : null;
  if (router != null) addTearDown(router.dispose);
  final container = ProviderContainer(
    overrides: [
      if (router != null) routerProvider.overrideWithValue(router),
      sharedPreferencesProvider.overrideWithValue(shared),
      authServiceProvider.overrideWithValue(
        auth ?? DemoAuthService(delay: Duration.zero),
      ),
      deviceServiceProvider.overrideWithValue(
        device ?? DemoDeviceService(delay: Duration.zero),
      ),
      repositoryProvider.overrideWithValue(DemoRepository(DemoData())),
      activationsServiceProvider.overrideWithValue(
        DemoActivationsService(load: Duration.zero, delay: Duration.zero),
      ),
    ],
  );
  addTearDown(container.dispose);
  prepare?.call(container);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const IqlyApp()),
  );
  if (router != null) return container;
  if (start == null) {
    await tester.pump(const Duration(seconds: 3));
  } else {
    container.read(routerProvider).go(start);
  }
  await tester.pumpAndSettle();
  return container;
}

Future<void> tapNext(WidgetTester tester) async {
  await tester.tap(find.byType(IqNextFab));
  await tester.pumpAndSettle();
}

Future<void> typeInto(WidgetTester tester, int index, String text) async {
  await tester.enterText(find.byType(EditableText).at(index), text);
  await tester.pump();
}

/// Records the haptics the app asks the platform for.
List<String> recordHaptics(WidgetTester tester) {
  final haptics = <String>[];
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'HapticFeedback.vibrate') {
      haptics.add(call.arguments as String);
    }
    return null;
  });
  addTearDown(
    () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return haptics;
}
