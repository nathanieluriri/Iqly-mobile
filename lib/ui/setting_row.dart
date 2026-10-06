import 'dart:async';

import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'switch.dart';

/// Exp/SettingRow: a preference row, label, one-line description and an
/// Exp/Switch. The whole row is the tap target and flips [state] through
/// [onChanged] with the select haptic. The divider is a 1 px line inset 16
/// on both sides.
///
/// Figma over brief: the row is a white Color/card band with no radius.
///
/// Motion (MOTION-SPEC 5.6, Figma 199:1311 "pair with Exp/SettingRow for a
/// full-width 64 px target"): while pressed the band fills panel, 100 ms in
/// and 160 out, a quick tap holding it for 100; the switch does the rest.
class IqSettingRow extends StatefulWidget {
  const IqSettingRow({
    super.key,
    this.label = 'Brief closing soon',
    this.description = 'A day before, and again an hour before',
    this.showDescription = true,
    this.divider = true,
    this.state = IqSwitchState.off,
    this.onChanged,
  });

  final String label;
  final String description;
  final bool showDescription;
  final bool divider;
  final IqSwitchState state;
  final ValueChanged<IqSwitchState>? onChanged;

  @override
  State<IqSettingRow> createState() => _IqSettingRowState();
}

class _IqSettingRowState extends State<IqSettingRow> {
  bool _pressed = false;
  bool _down = false;
  Timer? _hold;

  void _set(bool pressed) {
    if (pressed != _pressed) setState(() => _pressed = pressed);
  }

  void _press(TapDownDetails details) {
    _hold?.cancel();
    _hold = Timer(IqDurations.pressHold, () {
      _hold = null;
      if (!_down) _set(false);
    });
    _down = true;
    _set(true);
  }

  void _lift(TapUpDetails details) {
    _down = false;
    if (_hold == null) _set(false);
  }

  void _cancel() {
    _hold?.cancel();
    _hold = null;
    _down = false;
    _set(false);
  }

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onChanged = widget.onChanged;
    final label = widget.label;
    final description = widget.description;
    final showDescription = widget.showDescription;
    final divider = widget.divider;
    final state = widget.state;
    final active = onChanged != null;
    return MergeSemantics(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: active ? _press : null,
        onTapUp: active ? _lift : null,
        onTapCancel: active ? _cancel : null,
        onTap: onChanged == null
            ? null
            : () {
                IqHaptics.select.play();
                onChanged(
                  state == IqSwitchState.on
                      ? IqSwitchState.off
                      : IqSwitchState.on,
                );
              },
        child: AnimatedContainer(
          duration: _pressed ? IqDurations.dim : IqDurations.release,
          curve: IqCurves.easeOut,
          color: _pressed ? IqColors.panel : IqColors.card,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: IqSpace.s4,
                  vertical: IqSpace.s3,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: IqText.bodyStrong.copyWith(
                              color: IqColors.fg,
                            ),
                          ),
                          if (showDescription) ...[
                            const SizedBox(height: 1),
                            Text(
                              description,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: IqText.small.copyWith(color: IqColors.fg3),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    IqSwitch(state: state, onChanged: onChanged),
                  ],
                ),
              ),
              if (divider)
                const Positioned(
                  left: IqSpace.s4,
                  right: IqSpace.s4,
                  bottom: 0,
                  height: 1,
                  child: ColoredBox(color: IqColors.line),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
