import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iqly_mobile/router.dart';

void main() {
  test('no literal motion values in lib/ui and lib/features', () {
    // Deadlines and demo latency are not motion: they live in
    // lib/core/deadline.dart and lib/data, outside these folders.
    final literal = RegExp(r'\bCurves\.|\bCubic\(|\bDuration\(');
    // The Wallet and Profile rows were built beside the shared layer and keep
    // their values in one file each until they move onto it.
    const legacy = {
      'lib/features/profile/profile_motion.dart',
      'lib/features/wallet/wallet_motion.dart',
    };
    final offenders = <String>[];
    for (final folder in ['lib/ui', 'lib/features']) {
      for (final file in Directory(folder).listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        if (legacy.contains(file.path)) continue;
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (literal.hasMatch(lines[i])) {
            offenders.add('${file.path}:${i + 1}');
          }
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Use IqCurves and IqDurations from lib/core/motion.dart or the '
          'pages in lib/core/transitions.dart',
    );
  });

  test('every route builds its page from lib/core/transitions.dart', () {
    final router = buildRouter();
    addTearDown(router.dispose);
    final bare = <String>[];
    void walk(List<RouteBase> routes) {
      for (final route in routes) {
        switch (route) {
          case GoRoute(:final path, :final pageBuilder, :final builder):
            if (pageBuilder == null || builder != null) bare.add(path);
          case StatefulShellRoute(:final pageBuilder, :final builder):
            if (pageBuilder == null || builder != null) bare.add('shell');
          case ShellRoute(:final pageBuilder, :final builder):
            if (pageBuilder == null || builder != null) bare.add('shell');
        }
        walk(route.routes);
      }
    }

    walk(router.configuration.routes);
    expect(router.configuration.routes, isNotEmpty);
    expect(
      bare,
      isEmpty,
      reason:
          'A builder route falls back to a page with no transition: use '
          'pushPage, handoffPage, lensPage or sheetPage',
    );
  });
}
