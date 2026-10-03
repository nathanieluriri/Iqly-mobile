import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../core/transitions.dart';
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
/// destructive action is confirmed (spec 3.8). The sheet rises 280 ms
/// ease-out as the scrim fades to .5 and follows a drag down; Remove gives
/// the destructive haptic and the button sinks for 100 ms before the sheet
/// drops (200 ms), the button held down; Keep it drops it at once. From the
/// choice on, the sheet ignores taps, drags and the scrim. Reduced motion
/// fades in place.
Future<bool> showIqConfirmSheet(
  BuildContext context, {
  String title = 'Remove this recording?',
  String body =
      'You will need to upload it again before you can send the proof.',
  String confirmLabel = 'Remove recording',
  String cancelLabel = 'Keep it',
}) async {
  final result = await Navigator.of(context).push<bool>(
    IqSheetRoute<bool>(
      scrim: IqScrim.sheet,
      rise: IqDurations.sheetConfirm,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      builder: (context) => MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: _ConfirmSheetBody(
          title: title,
          body: body,
          confirmLabel: confirmLabel,
          cancelLabel: cancelLabel,
        ),
      ),
    ),
  );
  return result ?? false;
}

class _ConfirmSheetBody extends StatefulWidget {
  const _ConfirmSheetBody({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  final String title;
  final String body;
  final String confirmLabel;
  final String cancelLabel;

  @override
  State<_ConfirmSheetBody> createState() => _ConfirmSheetBodyState();
}

class _ConfirmSheetBodyState extends State<_ConfirmSheetBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sink = AnimationController(vsync: this);
  bool _closing = false;
  bool _dropping = false;

  // One pop only: a second tap during the sink or the drop would otherwise
  // pop the route underneath.
  void _close(bool result) {
    if (_closing) return;
    setState(() => _closing = true);
    final route = ModalRoute.of(context);
    if (route is IqSheetRoute) route.lock();
    void drop() {
      if (!mounted || route == null || !route.isCurrent) return;
      // Freezes the sunk button while the sheet drops.
      setState(() => _dropping = true);
      Navigator.of(context).pop(result);
    }

    final sink = result ? motion(context, IqDurations.sink) : Duration.zero;
    if (sink == Duration.zero) {
      drop();
    } else {
      _sink.duration = sink;
      _sink.forward().then((_) => drop());
    }
  }

  @override
  void dispose() {
    _sink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: _closing,
      child: TickerMode(
        enabled: !_dropping,
        child: IqConfirmSheet(
          title: widget.title,
          body: widget.body,
          confirmLabel: widget.confirmLabel,
          cancelLabel: widget.cancelLabel,
          onConfirm: () => _close(true),
          onCancel: () => _close(false),
        ),
      ),
    );
  }
}
