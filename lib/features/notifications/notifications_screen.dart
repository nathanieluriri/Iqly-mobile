import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/button.dart';
import '../../ui/illustration.dart';
import '../../ui/notification.dart';
import '../../ui/section_title.dart';
import '../../ui/skeleton.dart';
import '../../ui/top_bar.dart';
import '../discover/discover_routes.dart';
import '../wallet/wallet_motion.dart' show LoadingGate;
import 'notifications_state.dart';

/// B6 · Notifications (39:24) and its empty state (39:180), opened from the
/// bell on Discover, Wallet, Profile and My submissions. Deadlines and spots
/// read brief data, the result and the payouts the ledger and withdrawals;
/// seeing the feed clears the bell on every tab. Opening a row marks it
/// read, and back on the feed its dot shrinks away.
///
/// Motion (MOTION-SPEC §7.5): the rows arrive the first time the feed shows
/// in a session, each title's highlighter wiping 120 ms into its row's
/// beat; the empty bell arrives and swings once. Loading shows skeleton rows
/// after 300 ms; a failed load shows the error banner and Try again.
///
/// Where the build parts from the frame, on purpose: the feed runs newest
/// first (the frame lists today's rows 2h, 1h, 5h); the first and last rows
/// take the titles their layers are named for, as the frame repeats other
/// rows' text: "₦5,000.00 payout failed", and "₦10,000.00 requested" as
/// "₦10,000.00 withdrawal requested" is wider than the one-line
/// highlighter; deadlines read the brief's time left as Discover does
/// ("Closes in 6h", "Closes in 1 day") with the business before the brief
/// title.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _seen = false;

  void _markSeen() {
    if (_seen) return;
    _seen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(notificationsProvider.notifier).markSeen();
    });
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(notificationFeedProvider);
    final data = feed.hasValue && !feed.hasError ? feed.value : null;
    final failed = data == null && feed.hasError && !feed.isLoading;
    if (data != null) _markSeen();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: IqColors.bg,
        body: SafeArea(
          child: CenteredContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IqTopBar(
                  variant: IqTopBarVariant.page,
                  title: 'Notifications',
                  onBack: () => leave(context),
                ),
                Expanded(
                  child: LoadingGate(
                    loading: data == null && !failed,
                    skeleton: const _Skeleton(),
                    child: failed
                        ? _Failed(
                            onRetry: () => ref
                                .read(notificationsProvider.notifier)
                                .retry(),
                          )
                        : data == null
                        ? const SizedBox.shrink()
                        : data.isEmpty
                        ? const _Empty()
                        : _Feed(feed: data),
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

class _Feed extends ConsumerStatefulWidget {
  const _Feed({required this.feed});

  final NotificationFeed feed;

  @override
  ConsumerState<_Feed> createState() => _FeedState();
}

class _FeedState extends ConsumerState<_Feed> {
  late final bool _arrive = !ref.read(notificationsArrivedProvider);

  @override
  void initState() {
    super.initState();
    if (_arrive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(notificationsArrivedProvider.notifier).arrived();
      });
    }
  }

  Future<void> _open(NotificationItem item) async {
    final feed = ref.read(notificationsProvider.notifier);
    final link = item.link;
    if (link == null) {
      await feed.markRead(item.note.id);
      return;
    }
    if (link.tab) {
      feed.markRead(item.note.id);
      context.go(link.location);
      return;
    }
    await context.push(link.location);
    if (mounted) await feed.markRead(item.note.id);
  }

  @override
  Widget build(BuildContext context) {
    var slot = 0;
    Widget title(String text) => StaggerItem(
      index: slot++,
      child: IqSectionTitle(title: text, showCount: false, showLink: false),
    );
    Iterable<Widget> rows(List<NotificationItem> items) sync* {
      for (final (i, item) in items.indexed) {
        final index = slot++;
        yield StaggerItem(
          index: index,
          child: MergeSemantics(
            child: IqNotification(
              key: ValueKey(item.note.id),
              kind: item.kind,
              headline: item.title,
              detail: item.detail,
              resultDetail: item.detail,
              payoutDetail: item.detail,
              when: item.when,
              unread: item.note.unread,
              divider: i < items.length - 1,
              highlightDelay: _arrive && index < Stagger.moving
                  ? IqDurations.stagger * index + IqDurations.chain
                  : Duration.zero,
              onTap: () => _open(item),
            ),
          ),
        );
      }
    }

    final feed = widget.feed;
    return Stagger(
      play: _arrive,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          IqSpace.s4,
          0,
          IqSpace.s4,
          IqSpace.s4,
        ),
        children: [
          if (feed.today.isNotEmpty) ...[title('Today'), ...rows(feed.today)],
          if (feed.earlier.isNotEmpty) ...[
            title('Earlier'),
            ...rows(feed.earlier),
          ],
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
      children: [
        for (var i = 0; i < 4; i++) ...[
          if (i > 0) const SizedBox(height: IqSpace.s3),
          const IqSkeleton(kind: IqSkeletonKind.row),
        ],
      ],
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
      children: [
        IqBanner(
          kind: IqBannerKind.error,
          title: 'Couldn’t load. Check your connection.',
          action: 'Try again',
          onAction: onRetry,
        ),
        const SizedBox(height: IqSpace.s6),
        Text(
          'Nothing to show yet',
          textAlign: TextAlign.center,
          style: IqText.cardTitle.copyWith(color: IqColors.fg),
        ),
        const SizedBox(height: IqSpace.s2),
        Text(
          'They will show here once they load.',
          textAlign: TextAlign.center,
          style: IqText.body.copyWith(color: IqColors.fg2),
        ),
      ],
    );
  }
}

/// 39:180: the Bell illustration, "Nothing yet" and its line centred over
/// the Browse briefs bar. The bell's ink rises 16 and fades in over 320 ms,
/// its orange strokes wipe in from +160 and it swings once from +200 (0 to
/// -10, +8, -4 and back over 480 ms, pivot at its top); the title and line
/// appear at +80 and +120 (MOTION-SPEC §5.29, §6.9). Reduced motion:
/// everything fades in together, nothing moves.
class _Empty extends StatefulWidget {
  const _Empty();

  @override
  State<_Empty> createState() => _EmptyState();
}

class _EmptyState extends State<_Empty> with SingleTickerProviderStateMixin {
  static const _swingAt = IqDurations.swap;
  static final _swingLength = IqDurations.mark * 2;
  static final _length = _swingAt + _swingLength;
  static const _swingDegrees = [0.0, -10.0, 8.0, -4.0, 0.0];

  late final AnimationController _clock = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
  );
  late final Animation<double> _ink = _span(Duration.zero, IqDurations.morph);
  late final Animation<double> _accent = _span(
    IqDurations.tick,
    IqDurations.mark,
  );
  late final Animation<double> _title = _span(
    IqDurations.stagger * 2,
    IqDurations.appear,
  );
  late final Animation<double> _body = _span(
    IqDurations.chain,
    IqDurations.appear,
  );
  late final Animation<double> _fade = _clock.drive(
    CurveTween(curve: IqCurves.easeOut),
  );
  late final Animation<double> _swing = _clock.drive(
    CurveTween(
      curve: Interval(
        _swingAt.inMicroseconds / _length.inMicroseconds,
        1,
        curve: IqCurves.easeOut,
      ),
    ),
  );
  bool _reduced = false;
  bool _started = false;

  Animation<double> _span(Duration from, Duration length) {
    final total = _length.inMicroseconds;
    return _clock.drive(
      CurveTween(
        curve: Interval(
          from.inMicroseconds / total,
          (from + length).inMicroseconds / total,
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
    _clock.duration = _reduced ? IqDurations.crossfade : _length;
    _clock.forward();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  double _swingAngle(double t) {
    final segments = _swingDegrees.length - 1;
    final at = t * segments;
    final i = math.min(at.floor(), segments - 1);
    final degrees =
        _swingDegrees[i] + (_swingDegrees[i + 1] - _swingDegrees[i]) * (at - i);
    return degrees * math.pi / 180;
  }

  @override
  Widget build(BuildContext context) {
    final reduced = _reduced;
    final fade = _fade;
    Widget rise(Animation<double> t, double travel, Widget child) => reduced
        ? FadeTransition(opacity: fade, child: child)
        : FadeTransition(
            opacity: t,
            child: AnimatedBuilder(
              animation: t,
              child: child,
              builder: (context, child) => Transform.translate(
                offset: Offset(0, travel * (1 - t.value)),
                child: child,
              ),
            ),
          );

    final bell = SizedBox(
      width: IqIllustration.designWidth,
      height: IqIllustration.designHeight,
      child: AnimatedBuilder(
        animation: _swing,
        builder: (context, child) => Transform.rotate(
          angle: reduced ? 0 : _swingAngle(_swing.value),
          alignment: Alignment.topCenter,
          child: child,
        ),
        child: Stack(
          children: [
            rise(_ink, IqTravel.riseHero, const _BellLayer(IqColors.brand)),
            if (reduced)
              FadeTransition(
                opacity: fade,
                child: const _BellLayer(IqColors.accent),
              )
            else
              AnimatedBuilder(
                animation: _accent,
                builder: (context, child) =>
                    ClipRect(clipper: _Sweep(_accent.value), child: child),
                child: const _BellLayer(IqColors.accent),
              ),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: bell),
                  const SizedBox(height: IqSpace.s4),
                  rise(
                    _title,
                    IqTravel.rise,
                    Text(
                      'Nothing yet',
                      textAlign: TextAlign.center,
                      style: IqText.title.copyWith(color: IqColors.fg),
                    ),
                  ),
                  const SizedBox(height: IqSpace.s4),
                  rise(
                    _body,
                    IqTravel.rise,
                    Text(
                      'Deadlines, results and payouts land here.',
                      textAlign: TextAlign.center,
                      style: IqText.body.copyWith(color: IqColors.fg2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: IqSpace.s4,
            vertical: IqSpace.s3,
          ),
          child: IqButton(
            label: 'Browse briefs',
            kind: IqButtonKind.secondary,
            width: double.infinity,
            onTap: () => context.go(Routes.home),
          ),
        ),
      ],
    );
  }
}

/// One colour layer of Exp/Illustration Kind=Bell: its paths carry no ids
/// of their own, so the ink and the orange strokes part by colour.
class _BellLayer extends StatelessWidget {
  const _BellLayer(this.keep);

  final Color keep;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      IqIllustrations.bell.asset,
      width: IqIllustration.designWidth,
      height: IqIllustration.designHeight,
      excludeFromSemantics: true,
      colorMapper: _KeepColor(keep),
    );
  }
}

class _KeepColor extends ColorMapper {
  const _KeepColor(this.keep);

  final Color keep;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) => color.toARGB32() == keep.toARGB32() ? color : Colors.transparent;

  @override
  bool operator ==(Object other) => other is _KeepColor && other.keep == keep;

  @override
  int get hashCode => keep.hashCode;
}

class _Sweep extends CustomClipper<Rect> {
  const _Sweep(this.reveal);

  final double reveal;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, -size.height, size.width * reveal, size.height * 3);

  @override
  bool shouldReclip(_Sweep old) => old.reveal != reveal;
}
