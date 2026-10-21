import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Exp/Web/RangeField (local, sync to DS; 1723:13945): the reward pool
/// range, a two-handle slider over the two values with "to" between. The
/// handles are 20 across on a 4 track; a drag moves the nearer one.
class IqWebRangeField extends StatelessWidget {
  const IqWebRangeField({
    super.key,
    required this.min,
    required this.max,
    this.values = const RangeValues(0, 1),
    this.onChanged,
  });

  /// The labels of the two ends as they stand now.
  final String min;
  final String max;

  /// Where the handles sit, from 0 to 1.
  final RangeValues values;
  final ValueChanged<RangeValues>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 44,
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              activeTrackColor: IqColors.brand,
              inactiveTrackColor: IqColors.line,
              disabledActiveTrackColor: IqColors.brand,
              disabledInactiveTrackColor: IqColors.line,
              thumbColor: IqColors.card,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
              overlayColor: IqColors.brandSoft,
              rangeThumbShape: const _Handle(),
              rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
              showValueIndicator: ShowValueIndicator.never,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: RangeSlider(values: values, onChanged: onChanged),
          ),
        ),
        Row(
          children: [
            Expanded(child: _Value(min)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: IqSpace.s2),
              child: Text(
                'to',
                style: IqWebText.metaCaption.copyWith(color: IqColors.fg3),
              ),
            ),
            Expanded(child: _Value(max)),
          ],
        ),
      ],
    );
  }
}

class _Value extends StatelessWidget {
  const _Value(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: IqSpace.s2p5,
        vertical: IqSpace.s1p5,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(IqRadius.md),
        border: Border.all(color: IqColors.line),
      ),
      child: Text(
        text,
        maxLines: 1,
        style: IqWebText.bodySmall.copyWith(color: IqColors.fg),
      ),
    );
  }
}

class _Handle extends RangeSliderThumbShape {
  const _Handle();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.square(20);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    bool isDiscrete = false,
    bool isEnabled = false,
    bool? isOnTop,
    TextDirection? textDirection,
    required SliderThemeData sliderTheme,
    Thumb? thumb,
    bool? isPressed,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(center, 10, Paint()..color = IqColors.card);
    canvas.drawCircle(
      center,
      9,
      Paint()
        ..color = IqColors.brand
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}
