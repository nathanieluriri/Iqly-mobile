import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../data/models.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/button.dart';
import '../../ui/skeleton.dart';
import '../../ui/vector.dart';
import 'app_shell.dart';
import 'discover_state.dart';
import 'discover_widgets.dart';
import 'feed_slivers.dart';

/// B12 · Saved briefs (250:12333), offline (250:12609) and empty
/// (250:12880). The saved copies live on the device, so the list still
/// opens when the feed cannot load.
///
/// Motion (spec 6.28, 3.7, 5.12): a lens over Discover's chrome, so the
/// route itself does not move; the saved tickets arrive on the first open
/// of the session and fade in (200 ms) after that. The Offline banner
/// arrives under the chips. An unsaved ticket folds away 300 ms after the
/// tap; when the last one goes, the empty state arrives after it: the 96 pt
/// bookmark rises 16, the title and line appear at +80 and +120.
class SavedBriefsScreen extends ConsumerStatefulWidget {
  const SavedBriefsScreen({super.key});

  @override
  ConsumerState<SavedBriefsScreen> createState() => _SavedBriefsScreenState();
}

class _SavedBriefsScreenState extends ConsumerState<SavedBriefsScreen>
    with SingleTickerProviderStateMixin {
  final _arrivals = ArrivalsController();
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: IqDurations.swap,
    value: 1,
  );
  late final Animation<double> _fadeIn = _fade.drive(
    CurveTween(curve: IqCurves.easeOut),
  );
  late final bool _first = ref.read(arrivedListsProvider).add('saved');
  List<Brief>? _rows;
  final _leaving = <String, Timer>{};
  final _folding = <String>{};

  @override
  void initState() {
    super.initState();
    _rows = ref.read(savedBriefsProvider).value;
    if (_first) {
      if (_rows != null) _arrivals.play();
    } else {
      _fade.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_fade.isDismissed) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _fade.value = 1;
      } else {
        _fade.forward();
      }
    }
  }

  @override
  void dispose() {
    for (final timer in _leaving.values) {
      timer.cancel();
    }
    _fade.dispose();
    super.dispose();
  }

  /// Keeps an unsaved ticket in its place for 300 ms, folds it away over
  /// 200 and only then lets it go; saving it again in that time keeps it.
  void _sync(List<Brief>? saved) {
    if (saved == null) return;
    final ids = {for (final b in saved) b.id};
    for (final id in ids) {
      _leaving.remove(id)?.cancel();
      _folding.remove(id);
    }
    final rows = _rows;
    if (rows == null || MediaQuery.disableAnimationsOf(context)) {
      setState(() => _rows = saved);
      return;
    }
    final next = [...saved];
    for (final (i, brief) in rows.indexed) {
      if (ids.contains(brief.id)) continue;
      next.insert(math.min(i, next.length), brief);
      _leave(brief.id);
    }
    setState(() => _rows = next);
  }

  void _leave(String id) {
    if (_leaving.containsKey(id)) return;
    _leaving[id] = Timer(IqDurations.unsave, () {
      if (!mounted) return;
      setState(() => _folding.add(id));
      _leaving[id] = Timer(IqDurations.swap, () {
        if (!mounted) return;
        setState(() {
          _leaving.remove(id);
          _folding.remove(id);
          _rows = [..._rows!]..removeWhere((b) => b.id == id);
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(savedBriefsProvider, (previous, next) => _sync(next.value));
    final saved = ref.watch(savedBriefsProvider);
    final offline = ref.watch(discoverFeedProvider).hasError;
    final rows = _rows ?? saved.value;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: IqColors.bg,
      body: SafeArea(
        bottom: false,
        child: CenteredContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DiscoverTopBar(),
              Expanded(
                child: Arrivals(
                  controller: _arrivals,
                  child: CustomScrollView(
                    slivers: [
                      const PinnedFeedChips(selected: FeedChip.saved),
                      SliverToBoxAdapter(
                        key: const ValueKey('offline'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: IqSpace.s4,
                          ),
                          child: IqBanner(
                            kind: IqBannerKind.offline,
                            title: 'Offline. Saved briefs still load.',
                            showAction: false,
                            visible: offline && (rows?.isNotEmpty ?? false),
                            margin: const EdgeInsets.only(bottom: IqSpace.s3),
                          ),
                        ),
                      ),
                      LoadingGate.builder(
                        key: const ValueKey('gate'),
                        loading: rows == null,
                        onOpen: (after) {
                          if (_first) _arrivals.play(after: after);
                        },
                        builder: (context, phase, skeletonOpacity) =>
                            _body(phase, skeletonOpacity, rows),
                      ),
                      SliverToBoxAdapter(
                        key: const ValueKey('inset'),
                        child: SizedBox(height: AppShell.contentInset(context)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(
    GatePhase phase,
    Animation<double> skeletonOpacity,
    List<Brief>? rows,
  ) {
    final skeletons = gapped([
      for (var i = 0; i < 2; i++)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: IqSpace.s4),
          child: IqSkeleton(),
        ),
    ]);
    return switch (phase) {
      GatePhase.waiting => const SliverToBoxAdapter(),
      GatePhase.skeleton => SliverList.list(children: skeletons),
      GatePhase.handover || GatePhase.content => SliverMainAxisGroup(
        slivers: [
          if (phase == GatePhase.handover)
            SliverOverlay(
              key: const ValueKey('skeleton-out'),
              child: FadeTransition(
                opacity: skeletonOpacity,
                child: Column(children: skeletons),
              ),
            ),
          SliverFadeTransition(
            key: const ValueKey('saved'),
            opacity: _fadeIn,
            sliver: rows == null || rows.isEmpty
                ? const SliverToBoxAdapter(child: _Empty())
                : SliverList.list(
                    children: [
                      for (final brief in rows)
                        ArriveItem(
                          key: ValueKey(brief.id),
                          child: Collapse(
                            open: !_folding.contains(brief.id),
                            child: Padding(
                              padding: const EdgeInsets.only(
                                bottom: IqSpace.s3,
                              ),
                              child: Center(child: BriefTicket(brief: brief)),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    };
  }
}

class _Empty extends ConsumerWidget {
  const _Empty();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(
            height: 144,
            child: Center(child: Arrive.illustration(child: _Bookmark96())),
          ),
          const SizedBox(height: IqSpace.s3),
          Appear(
            delay: IqDurations.stagger * 2,
            child: Text(
              'Nothing saved yet',
              style: IqText.display.copyWith(color: IqColors.fg),
            ),
          ),
          const SizedBox(height: IqSpace.s3),
          Appear(
            delay: IqDurations.stagger * 3,
            child: Text(
              'Tap the bookmark on any brief.',
              style: IqText.body.copyWith(color: IqColors.fg2),
            ),
          ),
          const SizedBox(height: IqSpace.s3),
          IqButton(
            label: 'Browse briefs',
            showIcon: false,
            width: double.infinity,
            onTap: () => browseForYou(context, ref),
          ),
        ],
      ),
    );
  }
}

/// Exp/Icon/bookmark at 96 x 96 (250:13080), drawn from the node's own
/// export: its vector keeps a 2 px stroke at this size, where the 24 pt
/// icon scaled up would draw it four times as thick.
class _Bookmark96 extends StatelessWidget {
  const _Bookmark96();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 96,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -1,
            top: -1,
            width: 42,
            height: 66,
            child: IqVector(
              'assets/vectors/saved-briefs-bookmark.svg',
              color: IqColors.fg,
            ),
          ),
        ],
      ),
    );
  }
}
