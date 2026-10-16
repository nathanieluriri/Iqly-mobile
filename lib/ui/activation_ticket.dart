import 'dart:async';

import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'button.dart';
import 'countdown.dart';
import 'pressable.dart';
import 'spots_stamp.dart';

enum IqActivationTicketKind { hero, list, started, full, closed }

/// Exp/ActivationTicket: an activation as a paper ticket. The business tile
/// and name with the countdown beside it, the title, the steps line, the
/// spots stamp, then the reward with the action beside it. Hero is the dark
/// ticket for the top of the list. Fills its parent's width (358 in Figma).
///
/// The countdown and the spots are exposed: [time], [countdownTone],
/// [spotsLeft], [spotsTotal] and [spotsTone] default to the Figma master of
/// each kind. [onTap] opens the ticket (scales .98, 120 ms); [onAction] is
/// the button. Enters with a fade and 12 px rise, 260 ms ease-out, after
/// [enterDelay] (stagger lists 40 ms apart); reduced motion fades only.
/// [showOf] carries the taken count, which the paper masters show and the
/// B8 screens' instances leave out.
///
/// Figma over its note: no stub, perforation or arrow; the reward sits in
/// the footer beside an Exp/Button.
/// Figma over brief: Hero uses the sidebar-accent tile and sidebar-fg ink.
/// Figma over brief: five kinds, each with its own button and labels.
class IqActivationTicket extends StatefulWidget {
  const IqActivationTicket({
    super.key,
    this.kind = IqActivationTicketKind.hero,
    this.brand = 'Kudi Box',
    this.title = 'Open a Kudi Box account and save ₦1,000',
    this.steps,
    this.reward = 'Earn ₦1,500',
    this.time,
    this.countdownTone,
    this.spotsLeft,
    this.spotsTotal = 500,
    this.spotsTone,
    this.showOf,
    this.onTap,
    this.onAction,
    this.enterDelay = Duration.zero,
  });

  final IqActivationTicketKind kind;
  final String brand;
  final String title;
  final String? steps;
  final String reward;
  final String? time;
  final IqCountdownTone? countdownTone;
  final int? spotsLeft;
  final int spotsTotal;
  final IqSpotsStampTone? spotsTone;
  final bool? showOf;
  final VoidCallback? onTap;
  final VoidCallback? onAction;
  final Duration enterDelay;

  static const Duration enter = IqDurations.enter;
  static const Duration press = IqDurations.press;

  @override
  State<IqActivationTicket> createState() => _IqActivationTicketState();
}

class _IqActivationTicketState extends State<IqActivationTicket>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: IqActivationTicket.enter,
  );
  late final Animation<double> _rise = _enter.drive(
    CurveTween(curve: IqCurves.easeOut),
  );
  bool _started = false;
  bool _reduced = false;
  Timer? _delay;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_started) return;
    _started = true;
    if (widget.enterDelay == Duration.zero) {
      _enter.forward();
    } else {
      _delay = Timer(widget.enterDelay, _enter.forward);
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final look = _TicketLook.of(widget.kind);
    return FadeTransition(
      opacity: _rise,
      child: AnimatedBuilder(
        animation: _rise,
        builder: (context, child) => Transform.translate(
          offset: Offset(
            0,
            _reduced ? 0 : IqTravel.riseCard * (1 - _rise.value),
          ),
          child: child,
        ),
        child: IqPressable(
          tactile: false,
          onTap: widget.onTap,
          builder: (context, pressed) => AnimatedScale(
            scale: pressed && !_reduced ? IqScale.cardPress : 1,
            duration: pressMotion(context, pressed),
            curve: IqCurves.easeOut,
            child: _card(context, look),
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, _TicketLook look) {
    final hero = widget.kind == IqActivationTicketKind.hero;
    final initial = widget.brand.isEmpty
        ? ''
        : widget.brand.characters.first.toUpperCase();
    return Container(
      padding: const EdgeInsets.all(18),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: look.fill,
        borderRadius: BorderRadius.circular(IqRadius.xl2),
        border: hero ? null : Border.all(color: IqColors.brandLine2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: look.tile,
                  shape: BoxShape.circle,
                ),
                child: ExcludeSemantics(
                  child: Text(
                    initial,
                    style: IqText.label.copyWith(color: look.tileInk),
                  ),
                ),
              ),
              const SizedBox(width: IqSpace.s2),
              Expanded(
                child: Text(
                  widget.brand,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: IqText.small.copyWith(color: look.quiet),
                ),
              ),
              IqCountdown(
                time: widget.time ?? look.time,
                tone: widget.countdownTone ?? look.countdown,
              ),
            ],
          ),
          const SizedBox(height: IqSpace.s3),
          Text(widget.title, style: IqText.cardTitle.copyWith(color: look.ink)),
          const SizedBox(height: IqSpace.s1),
          Text(
            widget.steps ?? look.steps,
            style: IqText.small.copyWith(color: look.quiet),
          ),
          const SizedBox(height: IqSpace.s3),
          IqSpotsStamp(
            left: widget.spotsLeft ?? look.spotsLeft,
            total: widget.spotsTotal,
            tone: widget.spotsTone ?? look.spots,
            showOf: widget.showOf ?? !hero,
            onInk: hero,
          ),
          const SizedBox(height: IqSpace.s3),
          Padding(
            padding: const EdgeInsets.only(top: IqSpace.s1),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.reward,
                        style: IqText.figureSmall.copyWith(color: look.ink),
                      ),
                      Text(
                        'per completion',
                        style: IqText.small.copyWith(color: look.quiet),
                      ),
                    ],
                  ),
                ),
                IqButton(
                  label: look.action,
                  kind: look.button,
                  showIcon: false,
                  disabled: look.disabled,
                  onTap: widget.onAction,
                  width: _hugWidth(context, look.action),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static double _hugWidth(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: IqText.button),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width.ceilToDouble() + IqSpace.s6 * 2;
    painter.dispose();
    return width;
  }
}

class _TicketLook {
  const _TicketLook({
    required this.fill,
    required this.tile,
    required this.tileInk,
    required this.ink,
    required this.quiet,
    required this.button,
    required this.action,
    required this.time,
    required this.countdown,
    required this.spotsLeft,
    required this.spots,
    this.steps = '3 steps · about 10 min',
    this.disabled = false,
  });

  final Color fill;
  final Color tile;
  final Color tileInk;
  final Color ink;
  final Color quiet;
  final IqButtonKind button;
  final String action;
  final String time;
  final IqCountdownTone countdown;
  final int spotsLeft;
  final IqSpotsStampTone spots;
  final String steps;
  final bool disabled;

  static const _paper = (
    fill: IqColors.card,
    tile: IqColors.accentSoft,
    tileInk: IqColors.accentStrong,
    ink: IqColors.brand,
    quiet: IqColors.fg2,
  );

  static _TicketLook of(IqActivationTicketKind kind) => switch (kind) {
    IqActivationTicketKind.hero => const _TicketLook(
      fill: IqColors.brand,
      tile: IqColors.sidebarAccent,
      tileInk: IqColors.sidebarFg,
      ink: IqColors.sidebarFg,
      quiet: IqColors.sidebarFg,
      button: IqButtonKind.inverse,
      action: 'Start',
      time: '5h 40m',
      countdown: IqCountdownTone.hot,
      spotsLeft: 12,
      spots: IqSpotsStampTone.critical,
    ),
    IqActivationTicketKind.list => _TicketLook(
      fill: _paper.fill,
      tile: _paper.tile,
      tileInk: _paper.tileInk,
      ink: _paper.ink,
      quiet: _paper.quiet,
      button: IqButtonKind.primary,
      action: 'Start',
      time: '2 days',
      countdown: IqCountdownTone.calm,
      spotsLeft: 188,
      spots: IqSpotsStampTone.plenty,
    ),
    IqActivationTicketKind.started => _TicketLook(
      fill: _paper.fill,
      tile: _paper.tile,
      tileInk: _paper.tileInk,
      ink: _paper.ink,
      quiet: _paper.quiet,
      button: IqButtonKind.secondary,
      action: 'Continue',
      time: '36h',
      countdown: IqCountdownTone.calm,
      spotsLeft: 188,
      spots: IqSpotsStampTone.plenty,
      steps: 'Step 1 of 3 confirmed · about 10 min',
    ),
    IqActivationTicketKind.full => _TicketLook(
      fill: _paper.fill,
      tile: _paper.tile,
      tileInk: _paper.tileInk,
      ink: _paper.ink,
      quiet: _paper.quiet,
      button: IqButtonKind.primary,
      action: 'Full',
      time: '18h',
      countdown: IqCountdownTone.warm,
      spotsLeft: 0,
      spots: IqSpotsStampTone.full,
      disabled: true,
    ),
    IqActivationTicketKind.closed => _TicketLook(
      fill: _paper.fill,
      tile: _paper.tile,
      tileInk: _paper.tileInk,
      ink: _paper.ink,
      quiet: _paper.quiet,
      button: IqButtonKind.primary,
      action: 'Ended',
      time: 'Closed',
      countdown: IqCountdownTone.closed,
      spotsLeft: 0,
      spots: IqSpotsStampTone.full,
      disabled: true,
    ),
  };
}
