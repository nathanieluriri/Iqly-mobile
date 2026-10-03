import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'button.dart';

/// Exp/ConfirmSheet: the "are you sure" before a destructive action, a
/// grabber, a plain question, what happens next, the Danger sticker button
/// and Keep it. The scrim belongs to the route: use [showIqConfirmSheet].
///
/// Figma over brief: the Danger button keeps its err-soft sticker shadow.
/// Figma over its note: the buttons stack full width, Remove above Keep it.
/// Figma over brief: the scrim is ink at 50%, not the TipCard 60%.
/// Figma over brief: the home indicator placeholder becomes the OS inset (34 minimum).
class IqConfirmSheet extends StatelessWidget {
  const IqConfirmSheet({
    super.key,
    this.title = 'Remove this recording?',
    this.body =
        'You will need to upload it again before you can send the proof.',
    this.confirmLabel = 'Remove recording',
    this.cancelLabel = 'Keep it',
    this.onConfirm,
    this.onCancel,
  });

  final String title;
  final String body;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  static const double radius = 24;
  static const double homeIndicator = 34;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: IqColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: IqSpace.s2, bottom: IqSpace.s1),
            child: Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: IqColors.line2,
                  borderRadius: BorderRadius.circular(IqRadius.full),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              IqSpace.s5,
              IqSpace.s3,
              IqSpace.s5,
              IqSpace.s2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: IqText.title.copyWith(color: IqColors.brand),
                ),
                const SizedBox(height: IqSpace.s2),
                Text(body, style: IqText.body.copyWith(color: IqColors.fg2)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              IqSpace.s4,
              IqSpace.s3,
              IqSpace.s4,
              IqSpace.s2,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IqButton(
                  kind: IqButtonKind.danger,
                  label: confirmLabel,
                  showIcon: false,
                  width: double.infinity,
                  onTap: onConfirm,
                ),
                const SizedBox(height: IqSpace.s2),
                IqButton(
                  kind: IqButtonKind.ghost,
                  label: cancelLabel,
                  showIcon: false,
                  width: double.infinity,
                  onTap: onCancel,
                ),
              ],
            ),
          ),
          SizedBox(height: math.max(inset, homeIndicator)),
        ],
      ),
    );
  }
}

/// Shows [IqConfirmSheet] over an ink scrim and resolves to true when the
/// destructive action is confirmed. The sheet rises 280 ms ease-out while
/// the scrim fades to .5; on confirm the button sinks (the sticker press)
/// before the sheet drops 200 ms ease-in. Reduced motion fades in place.
Future<bool> showIqConfirmSheet(
  BuildContext context, {
  String title = 'Remove this recording?',
  String body =
      'You will need to upload it again before you can send the proof.',
  String confirmLabel = 'Remove recording',
  String cancelLabel = 'Keep it',
}) async {
  final result = await Navigator.of(context).push<bool>(
    _ConfirmSheetRoute(
      builder: (context) => IqConfirmSheet(
        title: title,
        body: body,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        onConfirm: () => Future.delayed(
          MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 100),
          () {
            if (context.mounted) Navigator.of(context).pop(true);
          },
        ),
        onCancel: () => Navigator.of(context).pop(false),
      ),
      label: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    ),
  );
  return result ?? false;
}

class _ConfirmSheetRoute extends PopupRoute<bool> {
  _ConfirmSheetRoute({required this.builder, required this.label});

  final WidgetBuilder builder;
  final String label;

  @override
  Color? get barrierColor => IqColors.brand.withValues(alpha: 0.5);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => label;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 280);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Builder(builder: builder),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return FadeTransition(opacity: animation, child: child);
    }
    return SlideTransition(
      position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
        CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
          reverseCurve: Curves.easeIn,
        ),
      ),
      child: child,
    );
  }
}
