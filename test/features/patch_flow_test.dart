import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iqly_mobile/core/deadline.dart';
import 'package:iqly_mobile/core/patches.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/patches.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/features/splash/patch_dialog.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../golden/screens/app_harness.dart';
import '../support/fake_patches.dart';

void main() {
  late FakePatchService service;

  setUp(() => service = FakePatchService());

  late GoRouter router;

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    String location = Routes.helpCentre,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    SharedPreferences.setMockInitialValues(signedInPrefs());
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
        repositoryProvider.overrideWithValue(ScriptedRepository()),
        clockProvider.overrideWithValue(() => figmaNow),
        patchServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    router = buildRouter(initialLocation: location);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: buildTheme(),
          routerConfig: router,
          builder: (context, child) =>
              PatchPresenter(router: router, child: child!),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('the dialog stays up when the page under it is replaced, as '
      'the splash hands over to Discover', (tester) async {
    service.found = [PatchCheck.available, PatchCheck.available];
    final c = await pump(tester);
    c.read(patchesProvider.notifier).check();
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(IqPatchDialog), findsOneWidget);
    router.go(Routes.home);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(IqPatchDialog), findsOneWidget);
    expect(find.text('Updating iQLY'), findsOneWidget);

    service.found = [PatchCheck.ready];
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Update applied'), findsOneWidget);
    c.read(patchesProvider.notifier).dismiss();
    await tester.pumpAndSettle();
  });

  testWidgets('a patch shows over the app and cannot be closed', (
    tester,
  ) async {
    service.found = [PatchCheck.available, PatchCheck.available];
    final c = await pump(tester);
    c.read(patchesProvider.notifier).check();
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Updating iQLY'), findsOneWidget);
    expect(find.text('DOWNLOADING UPDATE'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Updating iQLY'), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Updating iQLY'), findsOneWidget);

    service.found = [PatchCheck.ready];
    service.checks = 0;
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Update applied'), findsOneWidget);
    expect(find.textContaining('over the air'), findsOneWidget);
    expect(find.textContaining('Restart the app'), findsOneWidget);
    expect(find.byType(IqButton), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(IqPatchDialog), findsNothing);
    expect(c.read(patchesProvider), PatchPhase.idle);
  });

  testWidgets('Continue after a failure returns to the app', (tester) async {
    service.found = [PatchCheck.available];
    service.fail = true;
    final c = await pump(tester);
    await c.read(patchesProvider.notifier).check();
    await tester.pumpAndSettle();
    expect(find.text("Couldn't update"), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.byType(IqPatchDialog), findsNothing);
  });

  testWidgets('never over Time to update', (tester) async {
    service.found = [PatchCheck.ready];
    final c = await pump(tester, location: Routes.update);
    await c.read(patchesProvider.notifier).check();
    await tester.pumpAndSettle();
    expect(find.byType(IqPatchDialog), findsNothing);
  });
}
