import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';

enum IqTopBarVariant { home, page, sheet }

/// Exp/TopBar. Home: greeting, display title and the bell with an unread
/// count. Page: round back, centred title, optional trailing action. Sheet:
/// grabber, title and a 44 pt close. Fills the width; the status bar and
/// safe area belong to the screen.
///
/// [showBack] carries the screens whose Page bar has no back layer (B5
/// Withdrawal pending): the title then centres from the left padding.
///
/// Motion (spec 5.22, 5.18, 4.3; build extension): the round buttons fill
/// panel while pressed (100 ms, back in 160); a new greeting crossfades in
/// (150 ms); the unread count pops in (.6 to 1, 220 ms; no sooner than 200
/// ms after the bar appears), rolls when it changes and pops out (150 ms
/// ease-in) at zero. Across a push between two Page bars, each in a
/// ChromeHero with [shuttle], the back button holds still while the titles
/// cross.
class IqTopBar extends StatelessWidget implements PreferredSizeWidget {
  const IqTopBar({
    super.key,
    this.variant = IqTopBarVariant.home,
    this.title = 'Discover',
    this.greeting = 'Good afternoon, Adaeze',
    this.count = '2',
    this.showCount = true,
    this.showTrailing = false,
    this.showBack = true,
    this.trailingIcon = IqIcons.filter,
    this.trailingLabel = 'Filter',
    this.onBell,
    this.onBack,
    this.onTrailing,
    this.onClose,
  });

  final IqTopBarVariant variant;
  final String title;
  final String greeting;
  final String count;
  final bool showCount;
  final bool showTrailing;
  final bool showBack;
  final IqIcons trailingIcon;

  /// Screen reader label for the trailing action; match it to [trailingIcon].
  final String trailingLabel;
  final VoidCallback? onBell;
  final VoidCallback? onBack;
  final VoidCallback? onTrailing;
  final VoidCallback? onClose;

  /// A Page bar in flight between two pages, for a ChromeHero around the
  /// bar (spec 4.3): the back button holds still while the old title leaves
  /// over 0 to 120 ms ease-in and the new one comes in over 60 to 240
  /// ease-out, [progress] running from the leaving page's bar, [from], to the
  /// arriving page's, [to], whichever way the pages move.
  static Widget shuttle(
    BuildContext context,
    Animation<double> progress,
    Widget from,
    Widget to,
  ) {
    if ((from as IqTopBar).title == (to as IqTopBar).title) return to;
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        final now = IqDurations.screen * progress.value;
        double span(Duration from, Duration to, Curve curve) => curve.transform(
          ((now - from).inMicroseconds / (to - from).inMicroseconds).clamp(
            0.0,
            1.0,
          ),
        );
        final out = span(
          Duration.zero,
          IqChromeTiming.titleOut,
          IqCurves.easeIn,
        );
        final come = span(
          IqChromeTiming.titleInAt,
          IqChromeTiming.titleInEnd,
          IqCurves.easeOut,
        );
        return Stack(
          children: [
            ClipRect(clipper: const _BarSide(back: true), child: to),
            ClipRect(
              clipper: const _BarSide(back: false),
              child: Opacity(opacity: 1 - out, child: from),
            ),
            ClipRect(
              clipper: const _BarSide(back: false),
              child: Opacity(opacity: come, child: to),
            ),
          ],
        );
      },
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(switch (variant) {
    IqTopBarVariant.home => 96,
    IqTopBarVariant.page => 56,
    IqTopBarVariant.sheet => 76,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: preferredSize.height,
      width: double.infinity,
      child: ClipRect(
        child: switch (variant) {
          IqTopBarVariant.home => _home(),
          IqTopBarVariant.page => _page(),
          IqTopBarVariant.sheet => _sheet(),
        },
      ),
    );
  }

  Widget _home() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: IqSpace.s5,
        vertical: IqSpace.s2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _Greeting(greeting)),
              _RoundButton(
                onTap: onBell,
                semanticLabel: 'Notifications',
                fill: IqColors.card,
                stroke: IqColors.line,
                radius: 22,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    const IqIcon(IqIcons.bell, size: 24, color: IqColors.brand),
                    Positioned(
                      left: 16,
                      top: -14,
                      child: _Badge(count: count, shown: showCount),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: IqSpace.s0p5),
          Text(
            title,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: IqText.display.copyWith(color: IqColors.brand),
          ),
        ],
      ),
    );
  }

  Widget _page() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: IqSpace.s3),
      child: Row(
        children: [
          if (showBack) ...[
            _RoundButton(
              onTap: onBack,
              semanticLabel: 'Back',
              fill: IqColors.card,
              stroke: IqColors.line,
              radius: 22,
              child: const IqIcon(
                IqIcons.back,
                size: 22,
                color: IqColors.brand,
              ),
            ),
            const SizedBox(width: IqSpace.s2),
          ],
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: IqText.cardTitle.copyWith(color: IqColors.brand),
            ),
          ),
          const SizedBox(width: IqSpace.s2),
          if (showTrailing)
            _RoundButton(
              onTap: onTrailing,
              semanticLabel: trailingLabel,
              radius: 22,
              child: IqIcon(trailingIcon, size: 22, color: IqColors.brand),
            )
          else
            const SizedBox.square(dimension: 44),
        ],
      ),
    );
  }

  Widget _sheet() {
    return Stack(
      children: [
        Positioned(
          top: 6,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: IqColors.line2,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            IqSpace.s5,
            IqSpace.s2 + 14,
            IqSpace.s5,
            IqSpace.s2,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: IqText.title.copyWith(color: IqColors.brand),
                ),
              ),
              _RoundButton(
                onTap: onClose,
                semanticLabel: 'Close',
                fill: IqColors.panel,
                radius: 20,
                child: const IqIcon(
                  IqIcons.close,
                  size: 20,
                  color: IqColors.brand,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The Page bar's back button side (12 padding, 44 button, 8 gap) or the
/// rest of it.
class _BarSide extends CustomClipper<Rect> {
  const _BarSide({required this.back});

  final bool back;

  static const double _width = IqSpace.s3 + 44 + IqSpace.s2;

  @override
  Rect getClip(Size size) => back
      ? Rect.fromLTRB(0, 0, _width, size.height)
      : Rect.fromLTRB(_width, 0, size.width, size.height);

  @override
  bool shouldReclip(_BarSide old) => old.back != back;
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.child,
    required this.radius,
    this.onTap,
    this.semanticLabel,
    this.fill,
    this.stroke,
  });

  final Widget child;
  final double radius;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final Color? fill;
  final Color? stroke;

  @override
  Widget build(BuildContext context) {
    final rest = fill ?? IqColors.panel.withValues(alpha: 0);
    final down = fill == IqColors.panel ? IqColors.line : IqColors.panel;
    return IqPressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      builder: (context, pressed) => AnimatedContainer(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        duration: pressed ? IqDurations.dim : IqDurations.release,
        curve: IqCurves.easeOut,
        decoration: BoxDecoration(
          color: pressed ? down : rest,
          borderRadius: BorderRadius.circular(radius),
          border: stroke == null ? null : Border.all(color: stroke!),
        ),
        child: child,
      ),
    );
  }
}

/// The greeting line, crossfading when its words change (spec 5.22).
class _Greeting extends StatelessWidget {
  const _Greeting(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: IqDurations.crossfade,
      switchInCurve: IqCurves.easeOut,
      switchOutCurve: IqCurves.easeOut,
      layoutBuilder: (current, previous) => Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [...previous, ?current],
      ),
      child: Text(
        text,
        key: ValueKey(text),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: IqText.small.copyWith(color: IqColors.fg2),
      ),
    );
  }
}

/// The unread count on the bell (spec 5.18): pops in when it appears, no
/// sooner than 200 ms after the bar does; rolls when it changes; pops out
/// at zero. Shown or gone at once under reduced motion.
class _Badge extends StatefulWidget {
  const _Badge({required this.count, required this.shown});

  final String count;
  final bool shown;

  @override
  State<_Badge> createState() => _BadgeState();
}

class _BadgeState extends State<_Badge> with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    value: widget.shown ? 1 : 0,
  )..addStatusListener((_) => setState(() {}));
  late String _count = widget.count;
  final Duration _born = SchedulerBinding.instance.currentSystemFrameTimeStamp;

  @override
  void didUpdateWidget(_Badge old) {
    super.didUpdateWidget(old);
    if (widget.shown) _count = widget.count;
    if (widget.shown == old.shown) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pop.value = widget.shown ? 1 : 0;
    } else if (widget.shown) {
      final age = SchedulerBinding.instance.currentSystemFrameTimeStamp - _born;
      final wait = age < IqDurations.swap
          ? IqDurations.swap - age
          : Duration.zero;
      final total = wait + IqDurations.appear;
      _pop.value = 0;
      _pop.animateTo(
        1,
        duration: total,
        curve: Interval(
          wait.inMicroseconds / total.inMicroseconds,
          1,
          curve: IqCurves.easeOut,
        ),
      );
    } else {
      _pop.animateBack(
        0,
        duration: IqDurations.crossfade,
        curve: IqCurves.easeIn,
      );
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_pop.isDismissed) return const SizedBox.shrink();
    return FadeTransition(
      opacity: _pop,
      child: ScaleTransition(
        scale: _pop.drive(Tween(begin: IqScale.pop, end: 1)),
        child: _CountBadge(count: _count),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final String count;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: IqColors.brand,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: IqColors.bg, width: 2),
      ),
      child: RollingText(
        count,
        style: IqText.label.copyWith(color: IqColors.primaryFg),
      ),
    );
  }
}
