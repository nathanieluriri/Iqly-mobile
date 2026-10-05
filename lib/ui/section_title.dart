import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';
import 'vector.dart';

/// Exp/SectionTitle: a section heading with its item count and the "See all"
/// link, shown only when the section is truncated. The root clips its
/// content, so only the top sliver of the brush underline shows, as in Figma.
///
/// Figma over brief: the title is Mob/Card title in fg, the count and the
/// brush underline are hidden by default ([showCount], [showUnderline]) and
/// the count is Mob/Label, not mono.
///
/// Motion (spec 5.25, build extension): the underline wipes in left to right
/// (240 ms ease-out) when first seen, or 60 ms after the title starts
/// arriving in a list; the count rolls when it changes; the link dims to .6
/// while pressed. Static under reduced motion.
///
/// Figma over brief: the master link is "See all" only; Discover overrides the
/// text to "Filter" on some sections, carried by [link].
class IqSectionTitle extends StatefulWidget {
  const IqSectionTitle({
    super.key,
    this.title = 'Closing soon',
    this.count = '3',
    this.showCount = false,
    this.showLink = true,
    this.showUnderline = false,
    this.link = 'See all',
    this.onSeeAll,
  });

  final String title;
  final String count;
  final bool showCount;
  final bool showLink;
  final bool showUnderline;
  final String link;
  final VoidCallback? onSeeAll;

  static const double linkHitWidth = 72;

  @override
  State<IqSectionTitle> createState() => _IqSectionTitleState();
}

class _IqSectionTitleState extends State<IqSectionTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wipe = AnimationController(
    vsync: this,
    duration: IqDurations.mark,
  );
  late final Animation<double> _own = _wipe.drive(
    CurveTween(curve: IqCurves.easeOut),
  );
  Animation<double>? _beat;
  bool _linkPressed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _beat = ArriveItem.beatOf(
      context,
      lead: ArriveItem.underlineLead,
      length: IqDurations.mark,
    );
    if (MediaQuery.disableAnimationsOf(context)) _wipe.value = 1;
  }

  void _seen() {
    if (mounted && _beat == null && _wipe.isDismissed) _wipe.forward();
  }

  // The link's hit band sits over the row, so its pressed look reaches the
  // visible link a frame later.
  void _press(bool pressed) {
    if (pressed == _linkPressed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _linkPressed != pressed) {
        setState(() => _linkPressed = pressed);
      }
    });
  }

  @override
  void dispose() {
    _wipe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reveal = _beat ?? _own;
    return _VerticalSlop(
      child: FirstSeen(
        onSeen: _seen,
        child: ClipRect(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Figma's 28 pt spacer sits on the title baseline, which drops
              // the title box 12 below the top of the 32 pt row.
              Padding(
                padding: const EdgeInsets.only(top: IqSpace.s3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Flexible(
                            child: Text(
                              widget.title,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: IqText.cardTitle.copyWith(
                                color: IqColors.fg,
                              ),
                            ),
                          ),
                          if (widget.showCount) ...[
                            const SizedBox(width: IqSpace.s2),
                            RollingText(
                              widget.count,
                              style: IqText.label.copyWith(color: IqColors.fg3),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (widget.showLink) ...[
                      const SizedBox(width: IqSpace.s2),
                      ExcludeSemantics(
                        child: PressDim(
                          pressed: _linkPressed,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                widget.link,
                                style: IqText.smallStrong.copyWith(
                                  color: IqColors.primary,
                                ),
                              ),
                              const SizedBox(width: IqSpace.s0p5),
                              const IqIcon(
                                IqIcons.forward,
                                size: 16,
                                color: IqColors.brand,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.showUnderline)
                Positioned(
                  left: 0,
                  bottom: -3.2,
                  width: 75.84,
                  height: 4.2,
                  child: AnimatedBuilder(
                    animation: reveal,
                    child: const IqVector(
                      'assets/vectors/section-title-underline.svg',
                      color: IqColors.accent,
                    ),
                    builder: (context, child) =>
                        ClipRect(clipper: _Sweep(reveal.value), child: child),
                  ),
                ),
              if (widget.showLink)
                Positioned(
                  top: 0,
                  right: 0,
                  bottom: 0,
                  width: IqSectionTitle.linkHitWidth,
                  child: IqPressable(
                    onTap: widget.onSeeAll,
                    semanticLabel: widget.link,
                    builder: (context, pressed) {
                      _press(pressed);
                      return const SizedBox.expand();
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Sweep extends CustomClipper<Rect> {
  const _Sweep(this.reveal);

  final double reveal;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, -size.height, size.width * reveal, size.height * 3);

  @override
  bool shouldReclip(_Sweep oldClipper) => oldClipper.reveal != reveal;
}

/// Lets taps just above or below the box land on its top or bottom edge, so
/// the 33 pt row gives "See all" a 44 pt tall target without changing the
/// layout.
class _VerticalSlop extends SingleChildRenderObjectWidget {
  const _VerticalSlop({super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderVerticalSlop();
}

class _RenderVerticalSlop extends RenderProxyBox {
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final slop = size.height < 44 ? (44 - size.height) / 2 : 0.0;
    if (position.dx < 0 ||
        position.dx > size.width ||
        position.dy < -slop ||
        position.dy > size.height + slop) {
      return false;
    }
    final inside = Offset(
      position.dx,
      position.dy.clamp(0.0, size.height - 0.5),
    );
    if (hitTestChildren(result, position: inside)) {
      result.add(BoxHitTestEntry(this, inside));
      return true;
    }
    return false;
  }
}
