import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/backend.dart';
import 'core/edge_haptics.dart';
import 'core/patches.dart';
import 'core/updates.dart';
import 'data/onboarding_service.dart' show genderAskedProvider;
import 'features/onboarding/onboarding_flow.dart';
import 'data/live/live_repository.dart';
import 'features/activations/activations_state.dart';
import 'features/shell/tablet_frame.dart';
import 'features/splash/patch_dialog.dart';
import 'features/submissions/submissions_state.dart';
import 'router.dart';
import 'theme/theme.dart';

class IqlyApp extends ConsumerStatefulWidget {
  const IqlyApp({super.key});

  @override
  ConsumerState<IqlyApp> createState() => _IqlyAppState();
}

class _IqlyAppState extends ConsumerState<IqlyApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        ref.read(updatesProvider.notifier).resumed();
        ref.read(backendProvider.notifier).resumed();
        ref.read(patchesProvider.notifier).resumed();
        if (!ref.read(liveModeProvider).isPreview &&
            ref.exists(mySubmissionsProvider)) {
          ref.read(mySubmissionsProvider.notifier).refreshQuietly();
        }
        if (ref.exists(activationsProvider)) {
          ref.read(activationsProvider.notifier).refreshQuietly().ignore();
        }
      },
    );
    unawaited(ref.read(patchesProvider.notifier).check());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    OnboardingFlow.askGender = ref.watch(genderAskedProvider);
    return MaterialApp.router(
      title: 'iQLY',
      theme: buildTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      // Paper under every route, so no transition ever fades to black.
      builder: (context, child) => PatchPresenter(
        router: router,
        child: EdgeHaptics(
          child: ColoredBox(
            color: IqColors.bg,
            child: TabletFrame(router: router, child: child!),
          ),
        ),
      ),
    );
  }
}
