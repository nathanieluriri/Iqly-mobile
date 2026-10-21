import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/motion.dart';
import '../core/responsive.dart';
import '../core/tablet_layout.dart';
import '../core/transitions.dart';
import '../theme/theme.dart';
import 'gift_button.dart';
import 'biz_crumb.dart';
import 'icon.dart';
import 'pressable.dart';
import 'wallet_chip.dart';

enum IqTopBarVariant { home, page, sheet }

/// Exp/TopBar. Home: the headline title, the wallet chip, the gift and the
/// bell with an unread count, on one 44 row. Page: round back, centred title, optional trailing action. Sheet:
/// grabber, title and a 44 pt close. Fills the width; the status bar and
/// safe area belong to the screen.
///
/// [showBack] carries the screens whose Page bar has no back layer (B5
/// Withdrawal pending): the title then centres from the left padding.
///
/// Figma over brief: Home is 60 tall now; the greeting is a hidden layer
/// ([showGreeting]) and the title is Mob/Headline, not Mob/Display.
///
/// Motion (spec 5.22, 5.18, 4.3; build extension): the round buttons fill
/// panel while pressed (100 ms, back in 160); a new greeting crossfades in
/// (150 ms); the unread count pops in (.6 to 1, 220 ms; no sooner than 200
/// ms after the bar appears), rolls when it changes and pops out (150 ms
/// ease-in) at zero. A Page bar with its back button carries itself as
/// chrome: across a push or a pop to another such bar the back button holds
/// still while the titles cross ([shuttle]). Home and Sheet bars share
/// nothing and ride their page.
class IqTopBar extends StatelessWidget implements PreferredSizeWidget {
  const IqTopBar({
    super.key,
    this.variant = IqTopBarVariant.home,
    this.title = 'Discover',
    this.greeting = 'Good afternoon, Adaeze',
    this.count = '2',
    this.showCount = true,
    this.showGreeting = false,
    this.showWallet = true,
    this.walletAmount = '₦12,500',
    this.showGift = false,
    this.giftTwinkle = false,
    this.showTrailing = false,
    this.showBack = true,
    this.trailingIcon = IqIcons.filter,
    this.trailingLabel = 'Filter',
    this.onBell,
    this.onWallet,
    this.onGift,
    this.onBack,
    this.onTrailing,
    this.onClose,
  });

  final IqTopBarVariant variant;
  final String title;
  final String greeting;
  final String count;
  final bool showCount;
  final bool showGreeting;
  final bool showWallet;
  final String walletAmount;
  final bool showGift;

  /// Runs the gift's one twinkle (designer answer 32); the screen decides.
  final bool giftTwinkle;
  final bool showTrailing;
  final bool showBack;
  final IqIcons trailingIcon;

  /// Screen reader label for the trailing action; match it to [trailingIcon].
  final String trailingLabel;
  final VoidCallback? onBell;
  final VoidCallback? onWallet;
  final VoidCallback? onGift;
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
    final old = _barOf(from);
    final next = _barOf(to);
    if (old.title == next.title) return next;
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
            ClipRect(clipper: const _BarSide(back: true), child: next),
            ClipRect(
              clipper: const _BarSide(back: false),
              child: Opacity(opacity: 1 - out, child: old),
            ),
            ClipRect(
              clipper: const _BarSide(back: false),
              child: Opacity(opacity: come, child: next),
            ),
          ],
        );
      },
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(switch (variant) {
    IqTopBarVariant.home => 60,
    IqTopBarVariant.page => 56,
    IqTopBarVariant.sheet => 76,
  });

  @override
  Widget build(BuildContext context) {
    if (Layout.isTablet(context)) {
      if (variant == IqTopBarVariant.page &&
          TabletInSplit.maybeOf(context) != null) {
        return const SizedBox.shrink();
      }
      final location = TabletLocation.of(context);
      if (variant == IqTopBarVariant.page &&
          location != null &&
          (title.isNotEmpty || TabletLocation.parentLabel(location) != null)) {
        return _TabletTrail(bar: this, location: location);
      }
      if (variant == IqTopBarVariant.sheet) return _drawn(grabber: false);
    }
    if (variant == IqTopBarVariant.page &&
        showBack &&
        ChromeHero.canCarry(context)) {
      return ChromeHero(
        tag: ChromeTags.back,
        shuttle: shuttle,
        child: _Carried(this),
      );
    }
    return _drawn();
  }

  Widget _drawn({bool grabber = true}) {
    return SizedBox(
      height: preferredSize.height,
      width: double.infinity,
      child: ClipRect(
        child: switch (variant) {
          IqTopBarVariant.home => _home(),
          IqTopBarVariant.page => _page(),
          IqTopBarVariant.sheet => _sheet(grabber: grabber),
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
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: IqText.headline.copyWith(color: IqColors.brand),
            ),
          ),
          if (showGreeting) ...[
            const SizedBox(width: IqSpace.s2),
            Flexible(child: _Greeting(greeting)),
          ],
          if (showWallet) ...[
            const SizedBox(width: IqSpace.s2),
            IqWalletChip(amount: walletAmount, onTap: onWallet),
          ],
          if (showGift) ...[
            const SizedBox(width: IqSpace.s2),
            IqGiftButton(twinkle: giftTwinkle, onTap: onGift),
          ],
          const SizedBox(width: IqSpace.s2),
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

  Widget _sheet({bool grabber = true}) {
    return Stack(
      children: [
        if (grabber)
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

/// A Page bar as its own chrome hero holds it; in flight [IqTopBar.shuttle]
/// draws the bars themselves.
class _Carried extends StatelessWidget {
  const _Carried(this.bar);

  final IqTopBar bar;

  @override
  Widget build(BuildContext context) => bar._drawn();
}

IqTopBar _barOf(Widget look) => look is _Carried ? look.bar : look as IqTopBar;

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
      hint: semanticLabel,
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
        child: IqCountBadge(count: _count),
      ),
    );
  }
}

/// The bell's count pill (brand fill, paper ring), also drawn by a row
/// that counts what waits behind it.
class IqCountBadge extends StatelessWidget {
  const IqCountBadge({super.key, required this.count});

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

/// A Page bar on a tablet (Mobile App · tablet): the crumbs from the nav
/// item the page sits under to the page itself, the first opening it as
/// Back would, and the bar's action at the end.
class _TabletTrail extends StatelessWidget {
  const _TabletTrail({required this.bar, required this.location});

  final IqTopBar bar;
  final String location;

  @override
  Widget build(BuildContext context) {
    final named = TabletLocation.parentLabel(location);
    if (bar.title.isEmpty && named != null) {
      return SizedBox(
        height: bar.preferredSize.height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: IqBizCrumb(label: named, onTap: bar.onBack),
          ),
        ),
      );
    }
    final parent = named == bar.title ? null : named;
    return SizedBox(
      height: bar.preferredSize.height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
        child: Row(
          children: [
            if (parent != null && bar.showBack) ...[
              IqBizCrumb(label: parent, onTap: bar.onBack),
              const SizedBox(width: IqSpace.s1),
            ],
            Expanded(
              child: parent != null && bar.showBack
                  ? IqBizCrumb(label: bar.title, state: IqBizCrumbState.current)
                  : Text(
                      bar.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: IqText.title.copyWith(color: IqColors.fg),
                    ),
            ),
            if (bar.showTrailing)
              _RoundButton(
                onTap: bar.onTrailing,
                semanticLabel: bar.trailingLabel,
                radius: 22,
                child: IqIcon(
                  bar.trailingIcon,
                  size: 22,
                  color: IqColors.brand,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
