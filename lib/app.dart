import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme/theme.dart';

class IqlyApp extends ConsumerWidget {
  const IqlyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'iQLY',
      theme: buildTheme(),
      routerConfig: ref.watch(routerProvider),
      debugShowCheckedModeBanner: false,
      // Paper under every route, so no transition ever fades to black.
      builder: (context, child) => ColoredBox(color: IqColors.bg, child: child),
    );
  }
}
