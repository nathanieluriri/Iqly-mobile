import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'highlight.dart';
import 'icon.dart';

enum IqStepRowState { todo, active, done }

/// Exp/StepRow: a step in an activation, a numbered bubble beside the title
/// and an optional body, over a dashed divider. Todo is outlined, Active
/// gets the orange sticker and the Highlight under its title, Done is inked
/// with the brush check. Fills its parent's width (358 in Figma).
///
/// Completing a step pops the bubble to ink (1.1 scale, 200 ms), wipes the
/// check in (160 ms) and slides the highlighter off to the right (180 ms).
/// Reduced motion: colour change only.
///
/// Figma over brief: the number and title are per-instance text, so they are
/// parameters here beside the Figma Body, Show body and Divider props.
/// Figma over its title: the dashed thread is the divider under each row.
class IqStepRow extends StatefulWidget {
  const IqStepRow({
    super.key,
    this.state = IqStepRowState.todo,
    this.number = '2',
    this.title = 'Verify your BVN in the app',
    this.body = 'Settings → Verification. About 2 minutes.',
    this.showBody = true,
    this.divider = true,
  });

  final IqStepRowState state;
  final String number;
  final String title;
  final String body;
  final bool showBody;
  final bool divider;

  static const Duration pop = Duration(milliseconds: 200);
  static const Duration check = Duration(milliseconds: 160);
  static const Duration slide = Duration(milliseconds: 180);

  @override
  State<IqStepRow> createState() => _IqStepRowState();
}

class _IqStepRowState extends State<IqStepRow> with TickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: IqStepRow.pop,
  );
  late final AnimationController _check = AnimationController(
    vsync: this,
    duration: IqStepRow.check,
    value: 1,
  );

  bool get _reduced => MediaQuery.disableAnimationsOf(context);

  @override
  void didUpdateWidget(IqStepRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state == IqStepRowState.done &&
        oldWidget.state != IqStepRowState.done &&
        !_reduced) {
      _pop.forward(from: 0);
      _check.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    _check.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = _reduced;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: IqSpace.s3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedBuilder(
                animation: _pop,
                builder: (context, child) => Transform.scale(
                  scale:
                      1 +
                      0.1 *
                          Curves.easeOut.transform(
                            _pop.value < 0.5
                                ? _pop.value * 2
                                : 2 - _pop.value * 2,
                          ),
                  child: child,
                ),
                child: _bubble(reduced),
              ),
              const SizedBox(width: IqSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _title(reduced),
                    if (widget.showBody) ...[
                      const SizedBox(height: IqSpace.s0p5),
                      Text(
                        widget.body,
                        style: IqText.small.copyWith(color: IqColors.fg3),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (widget.divider)
          const SizedBox(
            height: 0,
            child: CustomPaint(painter: _DashPainter(IqColors.brandLine2)),
          ),
      ],
    );
  }

  Widget _bubble(bool reduced) {
    final state = widget.state;
    return AnimatedContainer(
      duration: reduced ? Duration.zero : IqStepRow.pop,
      curve: Curves.easeOut,
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: switch (state) {
          IqStepRowState.todo => IqColors.brandLine2.withValues(alpha: 0),
          IqStepRowState.active => IqColors.accent,
          IqStepRowState.done => IqColors.brand,
        },
        border: state == IqStepRowState.todo
            ? Border.all(color: IqColors.brandLine2, width: 1.5)
            : null,
      ),
      child: state == IqStepRowState.done
          ? AnimatedBuilder(
              animation: _check,
              builder: (context, child) => ClipRect(
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: _check.value,
                  child: child,
                ),
              ),
              child: const IqIcon(
                IqIcons.check,
                size: 16,
                color: IqColors.sidebarFg,
              ),
            )
          : Text(
              widget.number,
              style: IqText.label.copyWith(
                color: state == IqStepRowState.active
                    ? IqColors.brand
                    : IqColors.fg2,
              ),
            ),
    );
  }

  Widget _title(bool reduced) {
    final state = widget.state;
    final Widget title = state == IqStepRowState.active
        ? IqHighlight(key: const ValueKey('mark'), text: widget.title)
        : Text(
            widget.title,
            key: ValueKey(state),
            style: IqText.bodyStrong.copyWith(
              color: state == IqStepRowState.done ? IqColors.fg2 : IqColors.fg,
            ),
          );
    return AnimatedSwitcher(
      duration: reduced ? Duration.zero : IqStepRow.slide,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topLeft,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) {
        final leaving =
            child.key == const ValueKey('mark') &&
            state != IqStepRowState.active;
        if (!leaving) return FadeTransition(opacity: animation, child: child);
        return ClipRect(
          child: SlideTransition(
            position: Tween(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: title,
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter(this.color);

  final Color color;

  static const double dash = 4;
  static const double gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    // The Figma line is centred on the row's bottom edge and clipped by it.
    const y = -0.5;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      final end = (x + dash).clamp(0.0, size.width);
      canvas.drawLine(Offset(x, y), Offset(end, y), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) => oldDelegate.color != color;
}
