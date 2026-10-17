import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../theme/theme.dart';
import '../splash/patch_dialog.dart';

/// Runs [work] under the full-screen filling mark, then goes to [to]: a
/// slow account action (sign out, delete, keep it closed) never leaves the
/// person on a dead screen. The cover fades in as the sheet that asked goes
/// down and fades out over the next page as it comes in.
Future<void> leaveUnderLoader(
  BuildContext context, {
  required String label,
  required Future<void> Function() work,
  required String to,
  Object? extra,
}) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  final router = GoRouter.of(context);
  final shown = ValueNotifier<bool>(true);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Cover(
      label: label,
      shown: shown,
      onGone: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
  try {
    await work();
    router.go(to, extra: extra);
  } finally {
    shown.value = false;
  }
}

class _Cover extends StatelessWidget {
  const _Cover({
    required this.label,
    required this.shown,
    required this.onGone,
  });

  final String label;
  final ValueNotifier<bool> shown;
  final VoidCallback onGone;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: shown,
      builder: (context, on, child) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: on ? 1 : 0),
        duration: motion(
          context,
          on ? IqDurations.crossfade : IqDurations.screen,
        ),
        onEnd: on ? null : onGone,
        builder: (context, opacity, child) =>
            Opacity(opacity: opacity, child: child),
        child: child,
      ),
      child: AbsorbPointer(
        child: Semantics(
          label: label,
          liveRegion: true,
          child: const ColoredBox(
            color: IqColors.bg,
            child: SizedBox.expand(child: Center(child: IqFillLoader())),
          ),
        ),
      ),
    );
  }
}
