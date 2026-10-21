import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/deadline.dart';
import '../../core/motion.dart';
import '../../core/navigation.dart';
import '../../core/tablet_layout.dart';
import '../../core/responsive.dart';
import '../../core/session.dart';
import '../../core/transitions.dart';
import '../../data/outcomes_service.dart' show businessNoteShownProvider;
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/brief_card.dart';
import '../../ui/button.dart';
import '../../ui/icon.dart';
import '../../ui/list_row.dart';
import '../../ui/pressable.dart';
import '../../ui/section_title.dart';
import '../../ui/share_card.dart';
import '../../ui/skeleton.dart';
import '../../ui/toast.dart';
import '../../ui/top_bar.dart';
import '../discover/discover_widgets.dart';
import '../submissions/brief_art.dart';
import '../submissions/row_card.dart';
import '../submissions/submissions_routes.dart';
import '../submissions/submissions_state.dart';
import 'business_note.dart';
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
        if (context.mounted) context.openInstead(submissionPath(id));
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
        onRetry: () => ref
          ..invalidate(submissionItemProvider(id))
          ..invalidate(resultProvider(id)),
      );
    } else {
      body = const SizedBox.shrink(key: ValueKey('loading'));
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: IqColors.bg,
        body: SafeArea(
          maintainBottomViewPadding: true,
          child: CenteredContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IqTopBar(
                  variant: IqTopBarVariant.page,
                  title: '',
                  onBack: () => _leave(context),
                ),
                Expanded(
                  child: LoadingGate(
                    loading: data == null && !result.hasError,
                    skeleton: const _Skeleton(),
                    child: Dissolve(child: body),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A cold open (from a notification, say) waits on paper, then on these
/// lines (spec 2.6), never on a blank page.
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        Widget line(double share) => IqSkeleton(
          kind: IqSkeletonKind.line,
          width: (box.maxWidth - IqSpace.s8) * share,
        );
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            IqSpace.s4,
            IqSpace.s4,
            IqSpace.s4,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              line(0.45),
              const SizedBox(height: IqSpace.s6),
              line(1),
              const SizedBox(height: IqSpace.s2),
              line(0.8),
              const SizedBox(height: IqSpace.s2),
              line(0.6),
              const SizedBox(height: IqSpace.s6),
              const IqSkeleton(kind: IqSkeletonKind.row),
            ],
          ),
        );
      },
    );
  }
}

/// The result's action bar (12 above and below, 8 between buttons). The
/// B13 frames set a Ghost button to 44 high.
class ResultActions extends StatelessWidget {
  const ResultActions({super.key, required this.children});

  final List<Widget> children;

  static const double ghostHeight = 44;

  static Widget _sized(Widget child) =>
      child is IqButton && child.kind == IqButtonKind.ghost
      ? SizedBox(height: ghostHeight, child: child)
      : child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: IqSpace.s4,
        vertical: IqSpace.s3,
      ),
      child: IqToastFloor(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, child) in children.indexed) ...[
              if (i > 0) const SizedBox(height: IqSpace.s2),
              _sized(child),
            ],
          ],
        ),
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
    return Hero(
      tag: heroTag(data.item.id),
      curve: IqCurves.easeInOut,
      createRectTween: (begin, end) => RectTween(begin: begin, end: end),
      // The flight is drawn in the navigator's overlay, outside every page's
      // Material, where text would take the framework's fallback style (a
      // yellow double underline).
      flightShuttleBuilder: (context, animation, direction, from, to) =>
          Material(
            type: MaterialType.transparency,
            child: (to.widget as Hero).child,
          ),
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
    final split = TabletInSplit.maybeOf(context);
    final board = Leaderboard.of(data) != null;
    final note = ref.watch(businessNoteShownProvider)
        ? data.outcome?.note ?? data.item.submission.note
        : null;
    void openBoard() => context.open(leaderboardPath(id));
    final card = WinnerCard(
      data: data,
      markerReveal: _marker,
      accentReveal: _accent,
    );
    final label = [
      data.shareEyebrow,
      data.item.submission.title,
      data.amount,
    ].join(', ');
    final actions = ResultActions(
      children: [
        IqButton(
          label: 'Share your win',
          showIcon: false,
          width: double.infinity,
          onTap: () async {
            final copied = await context.push<bool>(sharePath(id));
            if (copied == true && context.mounted) {
              IqToast.show(context, 'Link copied');
            }
          },
        ),
        IqButton(
          label: 'View wallet',
          kind: IqButtonKind.ghost,
          showIcon: false,
          width: double.infinity,
          onTap: () => context.go(Routes.wallet),
        ),
      ],
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
                    child: board
                        ? IqPressable(
                            onTap: openBoard,
                            semanticLabel: label,
                            builder: (context, pressed) => AnimatedScale(
                              scale: pressed ? IqScale.cardPress : 1,
                              duration: pressMotion(context, pressed),
                              curve: IqCurves.easeOut,
                              child: ExcludeSemantics(child: card),
                            ),
                          )
                        : Semantics(
                            label: label,
                            child: ExcludeSemantics(child: card),
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
                if (board && !(split?.boardBeside ?? false)) ...[
                  const SizedBox(height: IqSpace.s3),
                  Appear(
                    delay: IqDurations.swap,
                    child: RowCard(
                      child: IqListRow(
                        label: 'See the leaderboard',
                        icon: IqIcons.trophy,
                        showDescription: false,
                        divider: false,
                        onTap: openBoard,
                      ),
                    ),
                  ),
                ],
                if (note != null) ...[
                  const SizedBox(height: IqSpace.s3),
                  Appear(
                    delay: IqDurations.swap,
                    child: const IqSectionTitle(
                      title: 'A note from the business',
                      showCount: false,
                      showLink: false,
                    ),
                  ),
                  const SizedBox(height: IqSpace.s3),
                  Appear(
                    delay: IqDurations.swap,
                    child: BusinessNoteView(
                      note: note,
                      brief: data.item.brief,
                      now: ref.watch(clockProvider)(),
                    ),
                  ),
                ],
                if (split != null) ...[
                  const SizedBox(height: IqSpace.s3),
                  actions,
                ],
              ],
            ),
          ),
        ),
        if (split == null) actions,
      ],
    );
  }
}

/// B13 · Result · Not selected (193:9681), calm: the parts settle in with
/// the push and the business's note bubble arrives at +200 (MOTION-SPEC
/// §5.33); no haptic. The note is a proposal behind Flags.businessNote. No
/// answer shows here (20 Oct): View your submission pushes the person's own
/// Submission detail (1639:125902). See what won opens the leaderboard, the
/// For you ticket its brief, and Find your next brief the For you feed.
///
/// Figma: the eyebrow is the entry's title ("ONE COUNTER FOR QUICK JOBS");
/// the "Not selected" Highlight in the status row is hidden.
class NotSelectedView extends ConsumerWidget {
  const NotSelectedView({super.key, required this.data});

  final ResultData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final note = ref.watch(businessNoteShownProvider)
        ? data.outcome?.note ?? data.item.submission.note
        : null;
    final board = Leaderboard.of(data) != null;
    final brief = data.item.brief;
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
                      [
                        brief?.businessName ?? 'Private business',
                        data.item.submission.title,
                      ].join(' · '),
                      style: IqText.smallStrong.copyWith(color: IqColors.fg2),
                    ),
                  ),
                  settle(
                    Text(
                      'Not selected this time',
                      style: IqText.display.copyWith(color: IqColors.fg),
                    ),
                  ),
                  settle(
                    RowCard(
                      child: IqListRow(
                        label: 'View your submission',
                        showDescription: false,
                        icon: IqIcons.document,
                        divider: false,
                        onTap: () => context.open(submissionPath(data.item.id)),
                      ),
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
                    settle(
                      BusinessNoteView(note: note, brief: brief, now: now),
                    ),
                  ],
                  if (board)
                    settle(
                      RowCard(
                        child: IqListRow(
                          label: 'See what won',
                          icon: IqIcons.trophy,
                          showDescription: false,
                          divider: false,
                          onTap: () =>
                              context.open(leaderboardPath(data.item.id)),
                        ),
                      ),
                    ),
                  if (data.next.isNotEmpty) ...[
                    settle(
                      const IqSectionTitle(
                        title: 'Briefs',
                        showCount: false,
                        showLink: false,
                      ),
                    ),
                    for (final next in data.next)
                      settle(
                        IqBriefCard(
                          brand: next.businessName ?? 'Private business',
                          title: next.title,
                          cover: briefCover(next),
                          logo: briefLogo(next),
                          meta: featureBriefMeta(next, now),
                          closingSoon: closingSoonOutline(next, now),
                          onTap: () =>
                              context.open(Routes.brief(next.id), extra: next),
                        ),
                      ),
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
