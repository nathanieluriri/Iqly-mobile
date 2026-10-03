import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion.dart';
import '../../core/transitions.dart';
import '../../theme/theme.dart';
import '../../ui/dock.dart';
import '../entry/first_tip.dart';

/// A tap on the lit Dock tab while that tab shows its root: the tab's list
/// scrolls to the top (spec 3.6).
class TabRetap {
  const TabRetap(this.tab, this.serial);

  final IqDockActive tab;
  final int serial;
}

class TabRetapNotifier extends Notifier<TabRetap?> {
  @override
  TabRetap? build() => null;

  void retap(IqDockActive tab) =>
      state = TabRetap(tab, (state?.serial ?? 0) + 1);
}

final tabRetapProvider = NotifierProvider<TabRetapNotifier, TabRetap?>(
  TabRetapNotifier.new,
);

/// Scrolls [controller] back to the top when its [tab] is tapped again
/// (spec 3.6): from three screens away at most, over 300 ms ease-in-out; a
/// jump under reduced motion.
void scrollToTopOnRetap(
  WidgetRef ref,
  BuildContext context,
  IqDockActive tab,
  ScrollController controller,
) {
  ref.listen(tabRetapProvider, (previous, next) {
    if (next == null || next.tab != tab || !controller.hasClients) return;
    final position = controller.position;
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.jumpTo(position.minScrollExtent);
      return;
    }
    final far = position.viewportDimension * 3;
    if (position.pixels > far) controller.jumpTo(far);
    controller.animateTo(
      position.minScrollExtent,
      duration: IqDurations.screen,
      curve: IqCurves.easeInOut,
    );
  });
}

/// The signed-in app: four tabs over the floating Exp/Dock. The dock sits 8
/// above the home indicator on a paper band (Figma dock-area 738 to 810;
/// the content frame clips at the dock's top), measured from the view
/// padding so a keyboard passing over it never moves it. The first tip
/// covers the whole shell, dock too. Tapping the lit tab while its stack is
/// at the root ([atRoot]) scrolls that tab's list to the top.
class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.active,
    required this.child,
    this.onTab,
    this.atRoot = true,
  });

  final IqDockActive active;
  final Widget child;
  final ValueChanged<IqDockActive>? onTab;
  final bool atRoot;

  static const double dockGap = 8;

  /// Bottom padding a tab's scroll view needs to clear the dock.
  static double contentInset(BuildContext context) =>
      MediaQuery.viewPaddingOf(context).bottom +
      dockGap +
      IqDock.height +
      IqSpace.s3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    final onTab = this.onTab;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: FirstTipOverlay(
        child: Material(
          color: IqColors.bg,
          child: Stack(
            children: [
              Positioned.fill(child: LensCrossfade(child: child)),
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
                  child: IqDock(
                    active: active,
                    onChanged: onTab == null
                        ? null
                        : (tab) {
                            if (tab == active && atRoot) {
                              ref.read(tabRetapProvider.notifier).retap(tab);
                            }
                            onTab(tab);
                          },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
