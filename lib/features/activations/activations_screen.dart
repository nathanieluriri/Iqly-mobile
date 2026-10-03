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
import '../../theme/theme.dart';
import '../../ui/activation_ticket.dart';
import '../../ui/banner.dart';
import '../../ui/icon.dart';
import '../../ui/list_row.dart';
import '../wallet/wallet_arrives.dart';
import '../../ui/spots_stamp.dart';
import '../../ui/top_bar.dart';
import '../discover/discover_routes.dart' show leave;
import '../submissions/submission_widgets.dart' show SkeletonCard;
import 'activation_format.dart';
import 'activations_routes.dart';
import 'activations_state.dart';
import 'activations_widgets.dart';

/// B8 · Activations (141:4597), which B9 · Activations (161:16268) repeats,
/// with its loading (165:7704), empty (165:7855) and failed to load
/// (165:8008) states. Discover's Activations row opens it.
///
/// Loading shows paper for 300 ms, then the three skeleton cards for at
/// least 600 (MOTION-SPEC §2.6); the content dissolves in and its tickets
/// arrive 40 ms apart, fading and rising 12 (Figma 168:1062). The Hot
/// ticket's countdown holds the screen's pulse. Try again reloads (row
/// note: "Try again → loading"); a retry that fails again gives the error
/// haptic.
///
/// Figma over this build: the frame shows Kudi Box as a List ticket with
/// Start while My activations says it is under way; a started activation
/// shows as the kit's Started ticket (Continue) here. Activations already
/// paid leave the list (one completion per person). "SHORT TASKS FROM
/// BRANDS" reads BUSINESSES, as the vocabulary rule asks.
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

  /// Paper first; the skeleton only if loading outlasts 300 ms, and then
  /// for at least 600.
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
          ? const _Loading(key: ValueKey('loading'))
          : const SizedBox.shrink(key: ValueKey('paper'));
    } else if (state.hasError) {
      body = _Failed(key: const ValueKey('failed'), onRetry: _retry);
    } else {
      final open = [
        for (final a in state.requireValue)
          if (!a.credited) a,
      ];
      body = open.isEmpty
          ? const _Empty(key: ValueKey('empty'))
          : _List(key: const ValueKey('list'), open: open, now: now);
    }

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
  const _List({super.key, required this.open, required this.now});

  final List<Activation> open;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final heroes = [
      for (final a in open)
        if (ticketKind(a, now) == IqActivationTicketKind.hero) a,
    ];
    final rest = [
      for (final a in open)
        if (ticketKind(a, now) != IqActivationTicketKind.hero) a,
    ];
    final mine = open.where((a) => a.inFlight).firstOrNull;
    var slot = 0;
    const gap = SizedBox(height: IqSpace.s3);

    Widget ticket(Activation activation) {
      final kind = ticketKind(activation, now);
      void open() => context.push(activationPath(activation.id));
      return IqActivationTicket(
        key: ValueKey(activation.id),
        kind: kind,
        brand: activation.business,
        title: activation.title,
        steps: kind == IqActivationTicketKind.started
            ? startedLine(activation)
            : stepsLine(activation),
        reward: earn(activation),
        time: countdownText(activationLeft(activation, now)),
        countdownTone: countdownTone(activation, now),
        spotsLeft: activation.spotsLeft,
        spotsTotal: activation.spotsTotal,
        spotsTone: IqSpotsStampTone.of(
          activation.spotsLeft,
          activation.spotsTotal,
        ),
        showOf: false,
        enterDelay: IqDurations.stagger * slot++,
        onTap: open,
        onAction: open,
      );
    }

    return Stagger(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          IqSpace.s4,
          0,
          IqSpace.s4,
          IqSpace.s4,
        ),
        children: [
          StaggerItem(
            index: slot++,
            child: const Eyebrow('Short tasks from businesses'),
          ),
          if (heroes.isNotEmpty) ...[
            gap,
            StaggerItem(
              index: slot++,
              child: Eyebrow('Closing soon · ${heroes.length}'),
            ),
            for (final a in heroes) ...[gap, ticket(a)],
          ],
          gap,
          StaggerItem(
            index: slot++,
            child: Eyebrow('All activations · ${open.length}'),
          ),
          for (final a in rest) ...[gap, ticket(a)],
          if (mine != null) ...[
            gap,
            StaggerItem(
              index: slot++,
              child: IqListRow(
                label: 'My activations',
                description: myActivationsLine(mine),
                icon: IqIcons.profile,
                divider: false,
                onTap: () => context.push(activationPath(mine.id)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 165:7704: LOADING… over three standalone Figma Skeleton cards, 240 tall.
class _Loading extends StatelessWidget {
  const _Loading({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Eyebrow('Loading…'),
          for (var i = 0; i < 3; i++) ...[
            const SizedBox(height: IqSpace.s3),
            const SkeletonCard(height: 240),
          ],
        ],
      ),
    );
  }
}

/// 165:7855: the Wallet illustration, no button.
class _Empty extends StatelessWidget {
  const _Empty({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        IqSpace.s4,
        IqSpace.s6,
        IqSpace.s4,
        IqSpace.s6,
      ),
      child: Column(
        children: [
          const WalletArrives(),
          const SizedBox(height: IqSpace.s2),
          Text(
            'No activations right now',
            textAlign: TextAlign.center,
            style: IqText.cardTitle.copyWith(color: IqColors.fg),
          ),
          const SizedBox(height: IqSpace.s2),
          Text(
            'Check back soon.',
            textAlign: TextAlign.center,
            style: IqText.body.copyWith(color: IqColors.fg2),
          ),
        ],
      ),
    );
  }
}

/// 165:8008: the Error banner, then the empty block 12 below it.
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
            title: 'Couldn’t load. Check your connection.',
            action: 'Try again',
            onAction: onRetry,
          ),
          const SizedBox(height: IqSpace.s3 + IqSpace.s6),
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
      ),
    );
  }
}
