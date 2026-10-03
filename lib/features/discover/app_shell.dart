import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/theme.dart';
import '../../ui/dock.dart';
import '../entry/first_tip.dart';

/// The signed-in app: four tabs over the floating Exp/Dock. The dock sits 8
/// above the home indicator on a paper band (Figma dock-area 738 to 810;
/// the content frame clips at the dock's top). The first tip covers the
/// whole shell, dock too.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.active,
    required this.child,
    this.onTab,
  });

  final IqDockActive active;
  final Widget child;
  final ValueChanged<IqDockActive>? onTab;

  static const double dockGap = 8;

  /// Bottom padding a tab's scroll view needs to clear the dock.
  static double contentInset(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom +
      dockGap +
      IqDock.height +
      IqSpace.s3;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: FirstTipOverlay(
        child: Material(
          color: IqColors.bg,
          child: Stack(
            children: [
              Positioned.fill(child: child),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: bottom + dockGap + IqDock.height,
                child: const ColoredBox(color: IqColors.bg),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: bottom + dockGap,
                child: Center(
                  child: IqDock(active: active, onChanged: onTab),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
