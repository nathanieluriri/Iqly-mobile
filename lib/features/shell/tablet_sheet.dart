import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../core/transitions.dart';
import '../../theme/theme.dart';
import '../../ui/icon.dart';
import '../../ui/pressable.dart';

/// Opens [builder] as the portrait side sheet (T7, T13): [width] wide on
/// the right, 12 from the edges, over the scrim; the 44 close button or a
/// tap on the scrim closes it.
Future<T?> showTabletSideSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double width = 400,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: IqScrim.sheet,
    transitionDuration: IqDurations.enter,
    pageBuilder: (context, animation, secondary) {
      final pad = MediaQuery.viewPaddingOf(context);
      return Padding(
        padding: EdgeInsets.fromLTRB(
          0,
          pad.top + IqSpace.s3,
          pad.right + IqSpace.s3,
          pad.bottom + IqSpace.s3,
        ),
        child: Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: width,
            child: Material(
              color: IqColors.card,
              borderRadius: BorderRadius.circular(IqRadius.xl2),
              clipBehavior: Clip.antiAlias,
              child: builder(context),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondary, child) {
      final curve = CurvedAnimation(parent: animation, curve: IqCurves.easeOut);
      return SlideTransition(
        position: Tween(
          begin: const Offset(0.1, 0),
          end: Offset.zero,
        ).animate(curve),
        child: FadeTransition(opacity: curve, child: child),
      );
    },
  );
}

/// Opens [builder] as a centred dialog [width] wide over the scrim (the
/// Withdraw, PIN and poll dialogs), capped at the window height less the
/// safe areas.
Future<T?> showTabletDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double width = 480,
  bool dismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: IqScrim.sheet,
    transitionDuration: IqDurations.swap,
    pageBuilder: (context, animation, secondary) {
      final media = MediaQuery.of(context);
      final pad = media.viewPadding;
      return Padding(
        padding: EdgeInsets.only(
          top: pad.top + IqSpace.s6,
          bottom: pad.bottom + IqSpace.s6 + media.viewInsets.bottom,
        ),
        child: Center(
          child: SizedBox(
            width: width,
            child: Material(
              color: IqColors.card,
              borderRadius: BorderRadius.circular(IqRadius.xl2),
              clipBehavior: Clip.antiAlias,
              child: builder(context),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondary, child) {
      final curve = CurvedAnimation(parent: animation, curve: IqCurves.easeOut);
      return FadeTransition(
        opacity: curve,
        child: ScaleTransition(
          scale: Tween(begin: 0.97, end: 1.0).animate(curve),
          child: child,
        ),
      );
    },
  );
}

/// The 44 round close button of a sheet or dialog.
class TabletClose extends StatelessWidget {
  const TabletClose({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IqPressable(
      onTap: onTap ?? () => Navigator.of(context).maybePop(),
      semanticLabel: 'Close',
      builder: (context, pressed) => Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: pressed ? IqColors.panel : IqColors.card,
          shape: BoxShape.circle,
          border: Border.all(color: IqColors.line),
        ),
        child: const IqIcon(IqIcons.close, size: 18, color: IqColors.fg),
      ),
    );
  }
}

/// A white card with the line border and radius 18, the tablet panel
/// surfaces (tables, side panels, settings cards).
class TabletCard extends StatelessWidget {
  const TabletCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: IqColors.card,
        borderRadius: BorderRadius.circular(IqRadius.xl2),
      ),
      // The border sits on top so filled rows do not cover it.
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(IqRadius.xl2),
        border: Border.all(color: IqColors.line),
      ),
      child: child,
    );
  }
}

/// A route that shows [child] as the centred tablet dialog [width] wide,
/// for a sheet route that a tablet opens as a dialog (a poll, Withdraw).
class TabletDialogPage<T> extends Page<T> {
  const TabletDialogPage({
    super.key,
    super.name,
    super.arguments,
    required this.child,
    this.width = 560,
  });

  final Widget child;
  final double width;

  @override
  Route<T> createRoute(BuildContext context) => RawDialogRoute<T>(
    settings: this,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: IqScrim.sheet,
    transitionDuration: IqDurations.swap,
    pageBuilder: (context, animation, secondary) {
      final media = MediaQuery.of(context);
      final pad = media.viewPadding;
      return Padding(
        padding: EdgeInsets.only(
          top: pad.top + IqSpace.s6,
          bottom: pad.bottom + IqSpace.s6 + media.viewInsets.bottom,
        ),
        child: Center(
          child: SizedBox(
            width: width,
            child: Material(
              color: IqColors.card,
              borderRadius: BorderRadius.circular(IqRadius.xl2),
              clipBehavior: Clip.antiAlias,
              child: child,
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondary, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: IqCurves.easeOut),
      child: child,
    ),
  );
}
