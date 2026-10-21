import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/responsive.dart';
import '../../core/transitions.dart';
import '../../theme/theme.dart';
import '../../ui/dock.dart';
import '../../ui/toast.dart';
import '../entry/first_tip.dart';

/// A dock switch onto [tab]: a tab that comes back shows what it had and
/// refreshes quietly behind it (designer answers, 5 Oct).
class TabEntry {
  const TabEntry(this.tab, this.serial);

  final IqDockActive tab;
  final int serial;
}

class TabEntryNotifier extends Notifier<TabEntry?> {
  @override
  TabEntry? build() => null;

  void enter(IqDockActive tab) =>
      state = TabEntry(tab, (state?.serial ?? 0) + 1);
}

final tabEntryProvider = NotifierProvider<TabEntryNotifier, TabEntry?>(
  TabEntryNotifier.new,
);

/// The signed-in app: four tabs over the Exp/Dock, a full width bar on the
/// home indicator (designer doc rev 57), measured from the view padding so
/// a keyboard passing over it never moves it. The first tip covers the
/// whole shell, dock too.
class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.active,
    required this.child,
    this.onTab,
  });

  final IqDockActive active;
  final Widget child;
  final ValueChanged<IqDockActive>? onTab;

  /// Bottom padding a tab's scroll view needs to clear the dock.
  static double contentInset(BuildContext context) => Layout.isTablet(context)
      ? IqSpace.s3
      : MediaQuery.viewPaddingOf(context).bottom + IqDock.height + IqSpace.s3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    final onTab = this.onTab;
    // On a tablet the frame's nav replaces the dock.
    final tablet = Layout.isTablet(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: FirstTipOverlay(
        child: Material(
          color: tablet ? IqColors.card : IqColors.bg,
          child: Stack(
            children: [
              Positioned.fill(child: LensCrossfade(child: child)),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: tablet
                    ? const SizedBox.shrink()
                    : IqToastFloor(
                        child: ColoredBox(
                          color: IqColors.bg,
                          child: Padding(
                            padding: EdgeInsets.only(bottom: bottom),
                            child: IqDock(
                              active: active,
                              onChanged: onTab == null
                                  ? null
                                  : (tab) {
                                      ref
                                          .read(tabEntryProvider.notifier)
                                          .enter(tab);
                                      onTab(tab);
                                    },
                            ),
                          ),
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
