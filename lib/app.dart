import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/edge_haptics.dart';
import 'core/updates.dart';
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
      onResume: () => ref.read(updatesProvider.notifier).resumed(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'iQLY',
      theme: buildTheme(),
      routerConfig: ref.watch(routerProvider),
      debugShowCheckedModeBanner: false,
      // Paper under every route, so no transition ever fades to black.
      builder: (context, child) => EdgeHaptics(
        child: ColoredBox(color: IqColors.bg, child: child),
      ),
    );
  }
}
