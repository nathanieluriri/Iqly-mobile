import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/deadline.dart';
import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../core/transitions.dart';
import '../../data/activations_data.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/illustration.dart';
import '../../ui/list_row.dart';
import '../../ui/top_bar.dart';
import '../discover/discover_routes.dart' show leave;
import 'activation_format.dart';
import 'activations_routes.dart';
import 'activations_state.dart';
import 'activations_widgets.dart';

/// B8 · Activations (141:4597, repeated as B9 161:16268) with its loading
/// (165:7704), empty (165:7855) and failed to load (165:8008) states. A sub
/// page, pushed from Discover's Activations row or from More.
///
/// The open activations, closing soonest first: the first as a Feature
/// card, the rest as Rows, then My activations once one is under way.
/// Loading shows paper for 300 ms, then the skeleton for at least 600; the
/// content dissolves in and its cards arrive 40 ms apart. Try again
/// reloads; a retry that fails again gives the error haptic.
class ActivationsScreen extends ConsumerStatefulWidget {
  const ActivationsScreen({super.key});

  @override
  ConsumerState<ActivationsScreen> createState() => _ActivationsScreenState();
}

class _ActivationsScreenState extends ConsumerState<ActivationsScreen> {
  bool _skeleton = false;
  bool _minimumMet = true;
  bool _retrying = false;
  Timer? _delay;
  Timer? _minimum;

  static bool _loading(AsyncValue<List<Activation>> state) =>
      !(state.hasValue && !state.hasError) &&
      !(state.hasError && !state.isLoading);

  @override
  void initState() {
    super.initState();
    if (_loading(ref.read(activationsProvider))) _armGate();
  }

  void _armGate() {
    _delay?.cancel();
    _minimum?.cancel();
    _skeleton = false;
    _minimumMet = true;
    _delay = Timer(IqDurations.skeletonDelay, () {
      if (!mounted || !_loading(ref.read(activationsProvider))) return;
      setState(() {
        _skeleton = true;
        _minimumMet = false;
      });
      _minimum = Timer(IqDurations.skeletonMin, () {
        if (mounted) setState(() => _minimumMet = true);
      });
    });
  }

  void _retry() {
    setState(() => _retrying = true);
    ref.read(activationsProvider.notifier).retry();
  }

  @override
  void dispose() {
    _delay?.cancel();
    _minimum?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(activationsProvider, (previous, next) {
      if (_loading(next) && !(previous != null && _loading(previous))) {
        _armGate();
      }
      if (_retrying && !next.isLoading) {
        if (next.hasError) errorHaptic();
        setState(() => _retrying = false);
      }
    });
    final state = ref.watch(activationsProvider);
    final now = ref.watch(clockProvider)();
    final held = _skeleton && !_minimumMet;
    final Widget body;
    if (_loading(state) || held) {
      body = _skeleton
          ? const ActivationsLoading(key: ValueKey('loading'))
          : const SizedBox.shrink(key: ValueKey('paper'));
    } else if (state.hasError) {
      body = _Failed(key: const ValueKey('failed'), onRetry: _retry);
    } else {
      final all = state.requireValue;
      final open = [
        for (final a in all)
          if (!a.credited && !a.closedAt(now)) a,
      ]..sort((a, b) => a.closesAt.compareTo(b.closesAt));
      body = open.isEmpty
          ? const _Empty(key: ValueKey('empty'))
          : _List(key: const ValueKey('list'), all: all, open: open, now: now);
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
                  title: 'Activations',
                  onBack: () => leave(context),
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

class _List extends StatelessWidget {
  const _List({
    super.key,
    required this.all,
    required this.open,
    required this.now,
  });

  final List<Activation> all;
  final List<Activation> open;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final lead = leadActivation(all);
    return Stagger(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          IqSpace.s4,
          0,
          IqSpace.s4,
          IqSpace.s4,
        ),
        children: [
          for (final (i, a) in open.indexed) ...[
            if (i > 0) const SizedBox(height: IqSpace.s3),
            StaggerItem(
              index: i,
              child: ActivationCard(
                key: ValueKey(a.id),
                activation: a,
                now: now,
                feature: i == 0,
                onTap: () => context.push(activationPath(a.id)),
              ),
            ),
          ],
          if (lead != null) ...[
            const SizedBox(height: IqSpace.s3),
            StaggerItem(
              index: open.length,
              child: _Grouped(
                child: IqListRow(
                  label: 'My activations',
                  description: myActivationsLine(lead),
                  divider: false,
                  onTap: () => context.push(myActivationsTarget(all)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The 1 pt line card, radius 16, the frame's "group" puts the row in.
class _Grouped extends StatelessWidget {
  const _Grouped({required this.child});

  final Widget child;

  static const double radius = 16;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(1),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: IqColors.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: IqColors.line),
      ),
      child: child,
    );
  }
}

/// 165:7855: the Shrug, centred in the space under the top bar.
class _Empty extends StatelessWidget {
  const _Empty({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: Center(
            child: ActivationsEmpty(
              figure: IqFigures.shrug,
              title: 'No activations right now',
              body: 'Check back soon.',
              action: 'Browse briefs',
              onAction: () => context.go(Routes.home, extra: NavDirection.back),
            ),
          ),
        ),
      ),
    );
  }
}

/// 165:8008: the Error banner, then the Thinker 12 below it.
class _Failed extends StatelessWidget {
  const _Failed({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IqBanner(
            kind: IqBannerKind.error,
            title: "Couldn't load. Check your connection.",
            action: 'Try again',
            onAction: onRetry,
          ),
          const SizedBox(height: IqSpace.s3),
          const ActivationsEmpty(
            figure: IqFigures.thinker,
            title: "Couldn't load activations",
            body: 'Check your data or Wi-Fi and try again.',
            top: 32,
          ),
        ],
      ),
    );
  }
}
