import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../data/activations_data.dart';
import '../../theme/theme.dart';
import '../../ui/brief_card.dart';
import '../../ui/button.dart';
import '../../ui/cover_with_logo.dart';
import '../../ui/illustration.dart';
import '../../ui/meta.dart';
import '../../ui/recording_player.dart';
import '../../ui/skeleton.dart';
import 'activation_format.dart';

/// The paper action bar at the foot of a screen: 12 above and below, the
/// actions 8 apart, full width.
class ActionBar extends StatelessWidget {
  const ActionBar({super.key, required this.children, this.divider = false});

  final List<Widget> children;

  /// The hairline over the bar, where the content scrolls under it.
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: IqColors.bg,
        border: divider
            ? const Border(top: BorderSide(color: IqColors.line))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: IqSpace.s4,
          vertical: IqSpace.s3,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, child) in children.indexed) ...[
              if (i > 0) const SizedBox(height: IqSpace.s2),
              child,
            ],
          ],
        ),
      ),
    );
  }
}

/// Whether a page above hides the screen around [context]: its tickers are
/// off, or the page has just started to leave and still covers it whole
/// (the first frame of a pop, when the tickers are already back on).
bool covered(BuildContext context) {
  if (!TickerMode.valuesOf(context).enabled) return true;
  return ModalRoute.of(context)?.secondaryAnimation?.value == 1;
}

/// The Dissolve between the states of one screen (spec 3.4): the new state
/// fades in over the old, 300 ms ease-out (the old reads ease-in as it
/// goes), a 150 ms crossfade under reduced motion. While a page above
/// covers the screen the change is a cut, so the screen is already in its
/// new state when that page leaves (Send proof back to Your proof, whose
/// change lands as the proof page starts to pop). The old state takes no
/// taps and offers no heroes on its way out, so the new state's top bar
/// joins a push or pop from the frame it is built (spec 4.3). [fit]
/// passthrough lets the states size the space, top aligned.
class StateDissolve extends StatefulWidget {
  const StateDissolve({
    super.key,
    required this.child,
    this.fit = StackFit.expand,
  });

  /// Keyed by the state; a new key dissolves.
  final Widget child;
  final StackFit fit;

  @override
  State<StateDissolve> createState() => _StateDissolveState();
}

class _StateDissolveState extends State<StateDissolve>
    with SingleTickerProviderStateMixin {
  // Preserved: the platform's remove-animations setting would otherwise
  // cut the 150 ms crossfade to 5% of its length.
  late final AnimationController _fade = AnimationController(
    vsync: this,
    value: 1,
    animationBehavior: AnimationBehavior.preserve,
  );
  late final Animation<double> _in = _fade.drive(
    CurveTween(curve: IqCurves.easeOut),
  );
  late final Animation<double> _out = ReverseAnimation(
    _fade.drive(CurveTween(curve: FlippedCurve(IqCurves.easeOut))),
  );
  Widget? _previous;

  @override
  void didUpdateWidget(StateDissolve old) {
    super.didUpdateWidget(old);
    if (old.child.key == widget.child.key) return;
    final length = motion(context, IqDurations.screen, fade: true);
    if (covered(context) || length == Duration.zero) {
      _previous = null;
      _fade.value = 1;
      return;
    }
    final previous = _previous = old.child;
    _fade
      ..duration = length
      ..forward(from: 0).whenCompleteOrCancel(() {
        if (mounted && _previous == previous) {
          setState(() => _previous = null);
        }
      });
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final previous = _previous;
    return Stack(
      alignment: Alignment.topCenter,
      fit: widget.fit,
      children: [
        if (previous != null)
          FadeTransition(
            key: previous.key,
            opacity: _out,
            child: HeroMode(
              enabled: false,
              child: IgnorePointer(child: previous),
            ),
          ),
        FadeTransition(
          key: widget.child.key,
          opacity: _in,
          child: HeroMode(
            child: IgnorePointer(ignoring: false, child: widget.child),
          ),
        ),
      ],
    );
  }
}

/// The Hero tag of an activation's recording, from its thumbnail to the
/// player.
String proofHeroTag(String activationId) => 'activation-proof-$activationId';

/// The recording's frame on ink: its first frame when it has a [source],
/// over the Exp/VideoPreview phone silhouette (88 x 170 with its 48 x 6 bar
/// in a 200 tall thumbnail) scaled to the space it gets, which keeps it
/// whole while it flies from the thumbnail to the player. The demo's
/// recordings have no source and keep the silhouette.
class ProofFrame extends StatelessWidget {
  const ProofFrame({super.key, this.source});

  final Uri? source;

  static const double _thumbnail = 200;

  @override
  Widget build(BuildContext context) {
    final source = this.source;
    if (source == null) return const _Silhouette();
    return IqRecordingPoster(source: source, placeholder: const _Silhouette());
  }
}

class _Silhouette extends StatelessWidget {
  const _Silhouette();

  @override
  Widget build(BuildContext context) {
    const thumbnail = ProofFrame._thumbnail;
    return ColoredBox(
      color: IqColors.brand,
      child: LayoutBuilder(
        builder: (context, box) {
          final s = box.maxHeight / thumbnail;
          return Center(
            child: Container(
              width: 88 * s,
              height: 170 * s,
              alignment: Alignment.topCenter,
              padding: EdgeInsets.only(top: 25 * s),
              decoration: BoxDecoration(
                color: IqColors.sidebarAccent,
                borderRadius: BorderRadius.circular(12 * s),
              ),
              child: Container(
                width: 48 * s,
                height: 6 * s,
                decoration: BoxDecoration(
                  color: IqColors.sidebarFg.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(3 * s),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// An activation as the B8 lists draw it: Exp/BriefCard, Feature for the
/// first card and Row for the rest, the reward, the time it takes (Feature
/// only) and the deadline, on the Urgent pill when it closes within a day.
/// A paid activation (My activations, Done) shows Done in place of the
/// deadline.
class ActivationCard extends StatelessWidget {
  const ActivationCard({
    super.key,
    required this.activation,
    required this.now,
    this.feature = false,
    this.onTap,
  });

  final Activation activation;
  final DateTime now;
  final bool feature;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final a = activation;
    return IqBriefCard(
      kind: feature ? IqBriefCardKind.feature : IqBriefCardKind.row,
      brand: a.business,
      title: a.title,
      cover: activationCoverArt(a),
      logo: activationLogoArt(a),
      meta: [
        IqMeta(kind: IqMetaKind.reward, label: cardReward(a, rewardChip(a))),
        if (feature) IqMeta(kind: IqMetaKind.time, label: minutesText(a)),
        if (a.credited)
          const IqMeta(kind: IqMetaKind.done, label: 'Paid to your wallet')
        else
          IqMeta(
            kind: closingSoon(a, now) ? IqMetaKind.urgent : IqMetaKind.deadline,
            label: deadlineText(a, now),
          ),
      ],
      onTap: onTap,
    );
  }
}

/// 165:7704: a Feature skeleton card (the 168 photo, three lines and three
/// pills) over two Row skeletons (the 72 square and three lines), each on
/// the BriefCard's line card.
class ActivationsLoading extends StatelessWidget {
  const ActivationsLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
      child: Semantics(
        label: 'Loading',
        child: SkeletonPulse(
          builder: (context, opacity) {
            Widget bar(double width, double height, {double? radius}) =>
                FadeTransition(
                  opacity: opacity,
                  child: Container(
                    width: width,
                    height: height,
                    decoration: BoxDecoration(
                      color: IqColors.panel,
                      borderRadius: BorderRadius.circular(radius ?? height / 2),
                    ),
                  ),
                );
            Widget row() => LineCard(
              inset: true,
              child: Padding(
                padding: const EdgeInsets.all(IqSpace.s4),
                child: Row(
                  children: [
                    bar(72, 72, radius: IqRadius.xl),
                    const SizedBox(width: IqSpace.s3),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        bar(110, 12),
                        const SizedBox(height: IqSpace.s2),
                        bar(200, 14),
                        const SizedBox(height: IqSpace.s2),
                        bar(130, 24),
                      ],
                    ),
                  ],
                ),
              ),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LineCard(
                  inset: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FadeTransition(
                        opacity: opacity,
                        child: Container(height: 168, color: IqColors.panel),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            bar(120, 12),
                            const SizedBox(height: 10),
                            bar(280, 16),
                            const SizedBox(height: 10),
                            bar(200, 16),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                bar(96, 26),
                                const SizedBox(width: IqSpace.s2),
                                bar(64, 26),
                                const SizedBox(width: IqSpace.s2),
                                bar(80, 26),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: IqSpace.s3),
                row(),
                const SizedBox(height: IqSpace.s3),
                row(),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The empty-state block of 165:7855 and 165:8008: an Exp/Figure (188 x
/// 200), 12, the title (Mob/Title), 12, the line, then the button 12 below.
class ActivationsEmpty extends StatelessWidget {
  const ActivationsEmpty({
    super.key,
    required this.figure,
    required this.title,
    this.body,
    this.action,
    this.onAction,
    this.top = IqSpace.s6,
  });

  final IqFigures figure;
  final String title;
  final String? body;
  final String? action;
  final VoidCallback? onAction;
  final double top;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    final body = this.body;
    return Padding(
      padding: EdgeInsets.fromLTRB(0, top, 0, IqSpace.s6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IqFigure(figure, width: 188.2353, arrive: true),
          const SizedBox(height: IqSpace.s3),
          Text(
            title,
            textAlign: TextAlign.center,
            style: IqText.title.copyWith(color: IqColors.fg),
          ),
          if (body != null) ...[
            const SizedBox(height: IqSpace.s3),
            Text(
              body,
              textAlign: TextAlign.center,
              style: IqText.body.copyWith(color: IqColors.fg2),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: IqSpace.s3),
            IqButton(label: action, showIcon: false, onTap: onAction),
          ],
        ],
      ),
    );
  }
}
