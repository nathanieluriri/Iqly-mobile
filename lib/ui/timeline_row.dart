import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'icon.dart';

enum IqTimelineRowState { done, current, upcoming }

/// Exp/TimelineRow: one step of claim progress, a dot on a thread. Done is
/// inked with the brush check, Current is the orange dot with a soft ring
/// that breathes 1 to 1.3 over 1.6 s, Upcoming is an outline. Becoming Done
/// inks the dot in 180 ms and draws the thread down in 240 ms ease-out.
/// Reduced motion: static ring, colour change only.
///
/// Figma over its note: only the threads under Current and Upcoming are
/// dashed; the thread under Done is solid brand.
/// Figma over the icon rule: the Done check is 12 px.
/// Brief rule kept: [failed] puts the Current core and ring on Color/err.
class IqTimelineRow extends StatefulWidget {
  const IqTimelineRow({
    super.key,
    this.state = IqTimelineRowState.done,
    this.title = 'Proof received',
    this.meta = 'Today, 2:14 pm',
    this.showLine = true,
    this.failed = false,
  });

  final IqTimelineRowState state;
  final String title;
  final String meta;
  final bool showLine;
  final bool failed;

  static const Duration ink = Duration(milliseconds: 180);
  static const Duration draw = Duration(milliseconds: 240);
  static const Duration breathe = Duration(milliseconds: 1600);

  @override
  State<IqTimelineRow> createState() => _IqTimelineRowState();
}

class _IqTimelineRowState extends State<IqTimelineRow>
    with TickerProviderStateMixin {
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: IqTimelineRow.breathe,
  );
  late final AnimationController _thread = AnimationController(
    vsync: this,
    duration: IqTimelineRow.draw,
    value: 1,
  );

  bool get _reduced => MediaQuery.disableAnimationsOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncRing();
  }

  @override
  void didUpdateWidget(IqTimelineRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state == IqTimelineRowState.done &&
        oldWidget.state != IqTimelineRowState.done &&
        !_reduced) {
      _thread.value = 0;
      Future.delayed(IqTimelineRow.ink, () {
        if (mounted) _thread.animateTo(1, curve: Curves.easeOut);
      });
    }
    _syncRing();
  }

  void _syncRing() {
    final breathing = widget.state == IqTimelineRowState.current && !_reduced;
    if (!breathing) {
      _ring.value = 0;
      _ring.stop();
    } else if (!_ring.isAnimating) {
      _ring.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ring.dispose();
    _thread.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final hot = widget.failed ? IqColors.err : IqColors.accent;
    final duration = _reduced ? Duration.zero : IqTimelineRow.ink;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      if (state == IqTimelineRowState.current)
                        ScaleTransition(
                          scale: Tween(begin: 1.0, end: 1.3).animate(
                            CurvedAnimation(
                              parent: _ring,
                              curve: Curves.easeInOut,
                            ),
                          ),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: hot.withValues(alpha: 0.25),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      AnimatedContainer(
                        duration: duration,
                        curve: Curves.easeOut,
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: switch (state) {
                            IqTimelineRowState.done => IqColors.brand,
                            IqTimelineRowState.current => hot,
                            IqTimelineRowState.upcoming =>
                              IqColors.brand.withValues(alpha: 0),
                          },
                          border: state == IqTimelineRowState.upcoming
                              ? Border.all(
                                  color: IqColors.brandLine2,
                                  width: 1.5,
                                )
                              : null,
                        ),
                        child: state == IqTimelineRowState.done
                            ? const IqIcon(
                                IqIcons.check,
                                size: 12,
                                color: IqColors.sidebarFg,
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
                if (widget.showLine) ...[
                  const SizedBox(height: IqSpace.s1),
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _thread,
                      builder: (context, _) => CustomPaint(
                        size: const Size(1.5, double.infinity),
                        painter: _ThreadPainter(
                          dashed: state != IqTimelineRowState.done,
                          reveal: state == IqTimelineRowState.done
                              ? _thread.value
                              : 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: IqSpace.s0p5, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: duration,
                    style: IqText.bodyStrong.copyWith(
                      color: state == IqTimelineRowState.upcoming
                          ? IqColors.fg3
                          : IqColors.fg,
                    ),
                    child: Text(widget.title),
                  ),
                  const SizedBox(height: IqSpace.s0p5),
                  Text(
                    widget.meta,
                    style: IqText.small.copyWith(color: IqColors.fg3),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadPainter extends CustomPainter {
  const _ThreadPainter({required this.dashed, required this.reveal});

  final bool dashed;
  final double reveal;

  static const double _dash = 4;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dashed ? IqColors.brandLine2 : IqColors.brand
      ..strokeWidth = 1.5;
    // Aligns the 1.5 px stroke's left edge to a pixel so one column is solid.
    final x = (size.width / 2).floorToDouble() - 0.25;
    final end = size.height * reveal;
    if (!dashed) {
      canvas.drawLine(Offset(x, 0), Offset(x, end), paint);
      return;
    }
    for (var y = 0.0; y < end; y += _dash + _gap) {
      final to = (y + _dash).clamp(0.0, end);
      canvas.drawLine(Offset(x, y), Offset(x, to), paint);
    }
  }

  @override
  bool shouldRepaint(_ThreadPainter old) =>
      old.dashed != dashed || old.reveal != reveal;
}
