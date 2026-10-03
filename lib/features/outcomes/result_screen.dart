import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/brief_labels.dart';
import '../../core/deadline.dart';
import '../../core/flags.dart';
import '../../core/money.dart';
import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../core/session.dart';
import '../../core/transitions.dart';
import '../../data/models.dart';
import '../../data/outcomes_data.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/button.dart';
import '../../ui/icon.dart';
import '../../ui/list_row.dart';
import '../../ui/pressable.dart';
import '../../ui/section_title.dart';
import '../../ui/share_card.dart';
import '../../ui/ticket_card.dart';
import '../../ui/top_bar.dart';
import '../discover/discover_widgets.dart';
import '../submissions/submissions_routes.dart';
import '../submissions/submissions_state.dart';
import 'outcomes_routes.dart';
import 'outcomes_state.dart';

/// Row B13, "Your result" from My submissions: B13 · Result · Winner
/// (193:9573) or B13 · Result · Not selected (193:9681). A row still under
/// review opens its submission instead.
class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key, required this.id});

  final String id;

  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.submissions, extra: NavDirection.back);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(submissionItemProvider(id), (_, next) {
      if (next.value?.underReview != true) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.replace(submissionPath(id));
      });
    });
    final result = ref.watch(resultProvider(id));
    final data = result.value;
    final Widget body;
    if (data != null) {
      body = data.winner
          ? WinnerView(key: const ValueKey('winner'), data: data)
          : NotSelectedView(key: const ValueKey('notSelected'), data: data);
    } else if (result.hasError && !result.isLoading) {
      body = _Failed(
        key: const ValueKey('failed'),
        onRetry: () => ref.invalidate(resultProvider(id)),
      );
    } else {
      body = const SizedBox.shrink(key: ValueKey('loading'));
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: IqColors.bg,
        body: SafeArea(
          child: CenteredContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IqTopBar(
                  variant: IqTopBarVariant.page,
                  title: 'Your result',
                  onBack: () => _leave(context),
                ),
                Expanded(child: Dissolve(child: body)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The result's action bar (12 above and below, 8 between buttons).
class ResultActions extends StatelessWidget {
  const ResultActions({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: IqSpace.s4,
        vertical: IqSpace.s3,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0) const SizedBox(height: IqSpace.s2),
            child,
          ],
        ],
      ),
    );
  }
}

/// The Exp/ShareCard shared by the Winner and the share sheet, at [width]
/// (the 0.62 preview scales the 358 card down).
class WinnerCard extends StatelessWidget {
  const WinnerCard({
    super.key,
    required this.data,
    this.width = IqShareCard.width,
    this.cardKey,
    this.markerReveal,
    this.accentReveal,
  });

  final ResultData data;
  final double width;
  final GlobalKey? cardKey;
  final Animation<double>? markerReveal;
  final Animation<double>? accentReveal;

  static String heroTag(String id) => 'share-card-$id';

  @override
  Widget build(BuildContext context) {
    final brief = data.item.brief;
    return HeroMode(
      enabled: !MediaQuery.disableAnimationsOf(context),
      child: Hero(
        tag: heroTag(data.item.id),
        child: SizedBox(
          width: width,
          child: FittedBox(
            fit: BoxFit.fitWidth,
            alignment: Alignment.topCenter,
            child: IqShareCard(
              key: cardKey,
              brand: data.shareEyebrow,
              title: data.item.submission.title,
              amount: data.amount,
              brief: brief?.title ?? '',
              name: data.name,
              markerReveal: markerReveal,
              accentReveal: accentReveal,
            ),
          ),
        ),
      ),
    );
  }
}

/// B13 · Result · Winner (193:9573), the celebration (MOTION-SPEC §5.33):
/// "You did it." appears, the share card fades in rising 24 from +120
/// (320 ease-out), the marker under the amount wipes from +440 with the
/// success haptic (the first time this result shows on the device), the
/// trophy's sweep from +560; See the leaderboard appears at +200 and the
/// buttons are there from the first frame. Reduced motion: fades only, the
/// haptic still plays. The card and the row open the leaderboard; Share
/// your win flies the card into the share sheet.
class WinnerView extends ConsumerStatefulWidget {
  const WinnerView({super.key, required this.data});

  final ResultData data;

  @override
  ConsumerState<WinnerView> createState() => _WinnerViewState();
}

class _WinnerViewState extends ConsumerState<WinnerView>
    with SingleTickerProviderStateMixin {
  static const _cardAt = IqDurations.chain;
  static const _cardFor = IqDurations.morph;
  static final _markerAt = _cardAt + _cardFor;
  static final _accentAt = _markerAt + IqDurations.chain;
  static final _length = _accentAt + IqDurations.mark;

  late final AnimationController _clock = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
  );
  Animation<double> _card = kAlwaysCompleteAnimation;
  Animation<double>? _marker;
  Animation<double>? _accent;
  bool _reduced = false;
  bool _started = false;
  bool _celebrate = false;

  Animation<double> _span(Duration at, Duration length) {
    final total = _length.inMicroseconds;
    return _clock.drive(
      CurveTween(
        curve: Interval(
          at.inMicroseconds / total,
          (at + length).inMicroseconds / total,
          curve: IqCurves.easeOut,
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduced = MediaQuery.disableAnimationsOf(context);
    _celebrate = firstCelebration(
      ref.read(sharedPreferencesProvider),
      widget.data.item.id,
    );
    if (_reduced) {
      _clock.duration = IqDurations.crossfade;
      _card = _clock.drive(CurveTween(curve: IqCurves.easeOut));
      if (_celebrate) IqHaptics.success.play();
    } else {
      _clock.duration = _length;
      _card = _span(_cardAt, _cardFor);
      _marker = _span(_markerAt, IqDurations.mark);
      _accent = _span(_accentAt, IqDurations.mark);
      if (_celebrate) _clock.addListener(_hapticAtMarker);
    }
    _clock.forward();
  }

  void _hapticAtMarker() {
    if (_clock.value * _length.inMicroseconds < _markerAt.inMicroseconds) {
      return;
    }
    _clock.removeListener(_hapticAtMarker);
    IqHaptics.success.play();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final id = data.item.id;
    final board = Leaderboard.of(data) != null;
    void openBoard() => context.push(leaderboardPath(id));
    final card = WinnerCard(
      data: data,
      markerReveal: _marker,
      accentReveal: _accent,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(IqSpace.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Appear(
                  child: Text(
                    'You did it.',
                    style: IqText.display.copyWith(color: IqColors.fg),
                  ),
                ),
                const SizedBox(height: IqSpace.s3),
                Center(
                  child: AnimatedBuilder(
                    animation: _card,
                    child: IqPressable(
                      onTap: board ? openBoard : null,
                      semanticLabel: [
                        data.shareEyebrow,
                        data.item.submission.title,
                        data.amount,
                      ].join(', '),
                      builder: (context, pressed) => AnimatedScale(
                        scale: pressed ? IqScale.cardPress : 1,
                        duration: pressMotion(context, pressed),
                        curve: IqCurves.easeOut,
                        child: ExcludeSemantics(child: card),
                      ),
                    ),
                    builder: (context, child) => Opacity(
                      opacity: _card.value,
                      child: Transform.translate(
                        offset: Offset(
                          0,
                          _reduced ? 0 : IqTravel.screen * (1 - _card.value),
                        ),
                        child: child,
                      ),
                    ),
                  ),
                ),
                if (board) ...[
                  const SizedBox(height: IqSpace.s3),
                  Appear(
                    delay: IqDurations.swap,
                    child: IqListRow(
                      label: 'See the leaderboard',
                      icon: IqIcons.trophy,
                      showDescription: false,
                      divider: false,
                      onTap: openBoard,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        ResultActions(
          children: [
            IqButton(
              label: 'Share your win',
              showIcon: false,
              width: double.infinity,
              onTap: () => context.push(sharePath(id)),
            ),
            IqButton(
              label: 'View wallet',
              kind: IqButtonKind.ghost,
              showIcon: false,
              width: double.infinity,
              onTap: () => context.go(Routes.wallet),
            ),
          ],
        ),
      ],
    );
  }
}

/// B13 · Result · Not selected (193:9681), calm: the parts settle in with
/// the push and the business's note bubble arrives at +200 (MOTION-SPEC
/// §5.33); no haptic. The note is a proposal behind Flags.businessNote. See
/// what won opens the leaderboard, the For you ticket its brief, and Find
/// your next brief the For you feed.
///
/// Figma: the eyebrow is the entry's title ("ONE COUNTER FOR QUICK JOBS");
/// the "Not selected" Highlight in the status row is hidden.
class NotSelectedView extends ConsumerWidget {
  const NotSelectedView({super.key, required this.data});

  final ResultData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final note = Flags.businessNote ? data.outcome?.note : null;
    final placing = data.placing;
    final next = data.next;
    final board = Leaderboard.of(data) != null;
    final now = ref.watch(clockProvider)();
    var slot = 0;
    Widget settle(Widget child) => StaggerItem(index: slot++, child: child);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stagger(
            move: StaggerMove.settle,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(IqSpace.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _gapped([
                  settle(
                    Text(
                      data.item.submission.title.toUpperCase(),
                      style: IqText.mono.copyWith(color: IqColors.fg2),
                    ),
                  ),
                  settle(
                    Text(
                      'Not this time',
                      style: IqText.display.copyWith(color: IqColors.fg),
                    ),
                  ),
                  if (placing != null)
                    settle(
                      Text(
                        placing,
                        style: IqText.small.copyWith(color: IqColors.fg3),
                      ),
                    ),
                  if (note != null) ...[
                    settle(
                      const IqSectionTitle(
                        title: 'A note from the business',
                        showCount: false,
                        showLink: false,
                      ),
                    ),
                    settle(_Note(note: note, now: now)),
                  ],
                  if (board)
                    settle(
                      IqListRow(
                        label: 'See what won',
                        icon: IqIcons.trophy,
                        showDescription: false,
                        divider: false,
                        onTap: () =>
                            context.push(leaderboardPath(data.item.id)),
                      ),
                    ),
                  if (next != null) ...[
                    settle(
                      const IqSectionTitle(
                        title: 'For you',
                        showCount: false,
                        showLink: false,
                      ),
                    ),
                    settle(_NextBrief(brief: next, now: now)),
                  ],
                ]),
              ),
            ),
          ),
        ),
        ResultActions(
          children: [
            IqButton(
              label: 'Find your next brief',
              showIcon: false,
              width: double.infinity,
              onTap: () => browseForYou(context, ref),
            ),
          ],
        ),
      ],
    );
  }

  static List<Widget> _gapped(List<Widget> items) => [
    for (final (i, item) in items.indexed) ...[
      if (i > 0) const SizedBox(height: IqSpace.s3),
      item,
    ],
  ];
}

/// The business's note: who, the bubble and when (193:9681 brand-note).
class _Note extends StatelessWidget {
  const _Note({required this.note, required this.now});

  final BusinessNote note;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MergeSemantics(
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: IqColors.tintStrong,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: ExcludeSemantics(
                  child: Text(
                    note.business.substring(0, 1),
                    style: IqText.label.copyWith(color: IqColors.brand),
                  ),
                ),
              ),
              const SizedBox(width: IqSpace.s2),
              Flexible(
                child: Text(
                  note.business,
                  style: IqText.smallStrong.copyWith(color: IqColors.fg),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: IqSpace.s2p5),
        _BubbleArrives(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: IqSpace.s3,
            ),
            decoration: BoxDecoration(
              color: IqColors.card,
              border: Border.all(color: IqColors.line),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              note.body,
              style: IqText.body.copyWith(color: IqColors.fg),
            ),
          ),
        ),
        const SizedBox(height: IqSpace.s2p5),
        Text(
          noteTime(note.sentAt, now),
          style: IqText.mono.copyWith(color: IqColors.fg3),
        ),
      ],
    );
  }
}

/// The note bubble arrives like a support ChatBubble (MOTION-SPEC §5.30,
/// §5.33): from +200 it fades in and grows from .96 at its top left corner,
/// 220 ms ease-out. Reduced motion: it fades in over 150.
class _BubbleArrives extends StatefulWidget {
  const _BubbleArrives({required this.child});

  final Widget child;

  @override
  State<_BubbleArrives> createState() => _BubbleArrivesState();
}

class _BubbleArrivesState extends State<_BubbleArrives>
    with SingleTickerProviderStateMixin {
  static const _at = IqDurations.swap;

  late final AnimationController _clock = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
  );
  Animation<double> _t = kAlwaysCompleteAnimation;
  bool _reduced = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced) {
      _clock.duration = IqDurations.crossfade;
      _t = _clock.drive(CurveTween(curve: IqCurves.easeOut));
    } else {
      final total = _at + IqDurations.appear;
      _clock.duration = total;
      _t = _clock.drive(
        CurveTween(
          curve: Interval(
            _at.inMicroseconds / total.inMicroseconds,
            1,
            curve: IqCurves.easeOut,
          ),
        ),
      );
    }
    _clock.forward();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.scale(
          scale: _reduced ? 1 : IqScale.soft + (1 - IqScale.soft) * _t.value,
          alignment: Alignment.topLeft,
          child: child,
        ),
      ),
    );
  }
}

/// The For you brief as a List Exp/TicketCard, no bookmark (193:9681).
class _NextBrief extends StatelessWidget {
  const _NextBrief({required this.brief, required this.now});

  final Brief brief;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final left = timeLeft(brief.deadline, now);
    final closed = !brief.isLive;
    return Align(
      alignment: Alignment.centerLeft,
      child: IqTicketCard(
        kind: IqTicketCardKind.list,
        title: brief.title,
        meta: ticketMeta(brief),
        initial: businessInitial(brief),
        reward: rewardPool(brief.rewardPoolKobo),
        rule: brief.winnerRule ?? '',
        showRule: false,
        spots: spotsLeftLabel(brief),
        showSpotsMarker: brief.spotsLeft != null,
        urgency: closesIn(left, closed: closed),
        urgencyTone: urgencyTone(left, closed: closed),
        onTap: () => context.push(Routes.brief(brief.id)),
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
      child: Align(
        alignment: Alignment.topCenter,
        child: IqBanner(
          kind: IqBannerKind.error,
          title: 'Couldn’t load. Check your connection.',
          action: 'Try again',
          onAction: onRetry,
        ),
      ),
    );
  }
}
