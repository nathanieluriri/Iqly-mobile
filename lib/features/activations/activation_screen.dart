import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/deadline.dart';
import '../../core/money.dart';
import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../core/transitions.dart';
import '../../data/activations_data.dart';
import '../../data/device.dart';
import '../../data/models.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/balance_hero.dart';
import '../../ui/banner.dart';
import '../../ui/button.dart';
import '../../ui/claim_stamp.dart';
import '../../ui/countdown.dart';
import '../../ui/pressable.dart';
import '../../ui/progress_thread.dart';
import '../../ui/section_title.dart';
import '../../ui/spots_stamp.dart';
import '../../ui/step_row.dart';
import '../../ui/timeline_row.dart';
import '../../ui/top_bar.dart';
import '../../ui/video_preview.dart';
import '../help/help_routes.dart';
import '../wallet/wallet_format.dart' show nairaParts;
import '../wallet/wallet_state.dart';
import 'activation_format.dart';
import 'activations_routes.dart';
import 'activations_state.dart';
import 'activations_widgets.dart';

enum _Layout { offer, steps, checking, credited }

_Layout _layoutOf(ActivationPhase phase) => switch (phase) {
  ActivationPhase.offer => _Layout.offer,
  ActivationPhase.started ||
  ActivationPhase.confirming ||
  ActivationPhase.notConfirmed => _Layout.steps,
  ActivationPhase.checking => _Layout.checking,
  ActivationPhase.credited => _Layout.credited,
};

/// One activation, one screen whose state follows the service:
/// B8 · Activation detail (141:4941, also B9 161:16280) before it starts;
/// just started (179:8001), in progress (141:5090) and B9 · step not
/// confirmed (154:6202) while steps wait; B9 · Proof · submitted (141:5549)
/// while proof is checked; Reward · credited (154:6312 after the business
/// confirms, 141:5693 after proof).
///
/// Start activation gives the commit haptic and the offer dissolves into
/// just started. The prototypes' 4 s advances arrive as live changes: a
/// confirmed step pops to Done and the next goes Active 120 ms later (its
/// Highlight wipes in). A step left unconfirmed for 24 hours turns the
/// screen to step not confirmed, with Upload proof of step 2. Being paid
/// dissolves to the reward: the PAID stamp lands at +120 with the success
/// haptic, the wallet rolls to its new balance at +400 and the timeline
/// arrives. Paid while a page covers the screen, nothing plays and no
/// haptic sounds (spec 2.7); coming back, the screen opens on the reward
/// and the stamp lands as it shows (spec 5.30), the wallet already at its
/// new balance. Tapping the waiting step or the Checking row asks for the
/// latest state, as those taps advance the prototypes.
///
/// Figma over this build: Open Kudi Box has no reaction; it opens the
/// business's link. Proof submitted is this screen once proof is in, so
/// its back goes to the list, as in Figma.
class ActivationScreen extends ConsumerStatefulWidget {
  const ActivationScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends ConsumerState<ActivationScreen> {
  int? _chained;
  Timer? _chain;
  Timer? _window;
  DateTime? _windowFor;
  bool _starting = false;
  bool _startFailed = false;
  bool _paidHere = false;
  bool _paidUnseen = false;
  bool _sentHere = false;

  @override
  void dispose() {
    _chain?.cancel();
    _window?.cancel();
    super.dispose();
  }

  void _onChange(Activation? before, Activation? after) {
    if (before == null || after == null) return;
    final now = ref.read(clockProvider)();
    final was = before.phaseAt(now);
    final phase = after.phaseAt(now);
    if (phase != was) {
      final seen = !covered(context);
      setState(() {
        if (phase == ActivationPhase.credited) {
          _paidHere = seen;
          _paidUnseen = !seen;
        }
        if (phase == ActivationPhase.checking) _sentHere = true;
      });
    }
    final next = after.waitingStep;
    if (after.confirmed > before.confirmed && next != null) {
      final beat = motion(context, IqDurations.chain);
      if (beat == Duration.zero) return;
      _chain?.cancel();
      setState(() => _chained = next);
      _chain = Timer(beat, () {
        if (mounted) setState(() => _chained = null);
      });
    }
  }

  /// Rebuilds when the waiting step runs out its window, so the screen
  /// turns to step not confirmed while it is open.
  void _watchWindow(Activation activation, DateTime now) {
    final since = activation.waitingSince;
    if (since == null ||
        activation.phaseAt(now) != ActivationPhase.confirming) {
      _window?.cancel();
      _window = null;
      _windowFor = null;
      return;
    }
    if (_windowFor == since) return;
    _window?.cancel();
    _windowFor = since;
    _window = Timer(
      since.add(ActivationRules.confirmWindow).difference(now),
      () {
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> _start() async {
    if (_starting) return;
    setState(() {
      _starting = true;
      _startFailed = false;
    });
    try {
      await ref.read(activationsProvider.notifier).start(widget.id);
    } on Object {
      if (!mounted) return;
      errorHaptic();
      setState(() {
        _starting = false;
        _startFailed = true;
      });
      return;
    }
    if (mounted) setState(() => _starting = false);
  }

  void _refresh() {
    ref.read(activationsProvider.notifier).refresh(widget.id).ignore();
  }

  void _open(Activation activation) =>
      ref.read(deviceServiceProvider).openUrl(activation.link);

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.activations, extra: NavDirection.back);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<Activation?>(activationProvider(widget.id), _onChange);
    final activation = ref.watch(activationProvider(widget.id));
    final now = ref.watch(clockProvider)();
    final Widget page;
    final _Layout? layout;
    if (activation == null) {
      layout = null;
      page = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IqTopBar(
            variant: IqTopBarVariant.page,
            title: 'Activation',
            onBack: _back,
          ),
        ],
      );
    } else {
      final phase = activation.phaseAt(now);
      _watchWindow(activation, now);
      layout = _layoutOf(phase);
      page = switch (layout) {
        _Layout.offer => _OfferPage(
          activation: activation,
          now: now,
          starting: _starting,
          failed: _startFailed,
          onStart: _start,
          onBack: _back,
        ),
        _Layout.steps => _StepsPage(
          activation: activation,
          phase: phase,
          now: now,
          chained: _chained,
          onBack: _back,
          onRefresh: _refresh,
          onOpen: () => _open(activation),
          onProof: () => context.push(proofPath(activation.id)),
        ),
        _Layout.checking => _CheckingPage(
          activation: activation,
          landed: _sentHere,
          onBack: _back,
          onRefresh: _refresh,
        ),
        _Layout.credited => _CreditedPage(
          activation: activation,
          moment: _paidHere,
          landed: _paidUnseen,
          onBack: _back,
        ),
      };
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: IqColors.bg,
        body: SafeArea(
          maintainBottomViewPadding: true,
          child: CenteredContent(
            child: StateDissolve(
              child: KeyedSubtree(key: ValueKey(layout), child: page),
            ),
          ),
        ),
      ),
    );
  }
}

const _gap = SizedBox(height: IqSpace.s4);

const _scrollPadding = EdgeInsets.fromLTRB(
  IqSpace.s4,
  0,
  IqSpace.s4,
  IqSpace.s6,
);

/// B8 · Activation detail (141:4941): the offer and how it pays, the steps
/// and the rules, Start activation in the bar.
class _OfferPage extends StatelessWidget {
  const _OfferPage({
    required this.activation,
    required this.now,
    required this.starting,
    required this.failed,
    required this.onStart,
    required this.onBack,
  });

  final Activation activation;
  final DateTime now;
  final bool starting;
  final bool failed;
  final VoidCallback onStart;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final a = activation;
    final steps = a.steps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IqTopBar(
          variant: IqTopBarVariant.page,
          title: 'Activation',
          onBack: onBack,
        ),
        Expanded(
          child: ListView(
            padding: _scrollPadding,
            children: [
              if (failed) ...[
                IqBanner(
                  kind: IqBannerKind.error,
                  title: 'Couldn’t start. Check your connection.',
                  action: 'Try again',
                  onAction: onStart,
                ),
                const SizedBox(height: IqSpace.s3),
              ],
              ActivationHeader(eyebrow: a.business, title: a.title),
              _gap,
              Align(
                alignment: Alignment.centerLeft,
                child: IqCountdown(
                  time: countdownText(activationLeft(a, now)),
                  tone: countdownTone(a, now),
                ),
              ),
              const SizedBox(height: IqSpace.s3),
              IqSpotsStamp(
                left: a.spotsLeft,
                total: a.spotsTotal,
                tone: IqSpotsStampTone.of(a.spotsLeft, a.spotsTotal),
                showOf: false,
              ),
              _gap,
              RewardLine(earn: earn(a), alignEnd: true),
              _gap,
              _Facts(activation: a),
              _gap,
              IqSectionTitle(
                showCount: true,
                title: 'What to do',
                count: '${steps.length}',
                showLink: false,
              ),
              _gap,
              for (final (i, step) in steps.indexed) ...[
                if (i > 0) _gap,
                IqStepRow(
                  number: '${i + 1}',
                  title: step.title,
                  body: step.howTo ?? step.hint,
                  divider: i < steps.length - 1,
                ),
              ],
              _gap,
              const _Rules(),
            ],
          ),
        ),
        ActionBar(
          children: [
            IqButton(
              label: 'Start activation',
              showIcon: false,
              width: double.infinity,
              loading: starting,
              disabled: a.full || a.closedAt(now),
              onTap: onStart,
            ),
          ],
        ),
      ],
    );
  }
}

/// HOW YOU GET PAID: Verification stacked over its value (the frame keeps
/// a two-line box for it), then Paid to and Paid when beside theirs.
class _Facts extends StatelessWidget {
  const _Facts({required this.activation});

  final Activation activation;

  @override
  Widget build(BuildContext context) {
    final label = IqText.small.copyWith(color: IqColors.fg3);
    final value = IqText.smallStrong.copyWith(color: IqColors.fg);
    const hairline = ColoredBox(
      color: IqColors.line,
      child: SizedBox(height: 1, width: double.infinity),
    );
    Widget side(String name, String text) => MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: IqSpace.s3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: label),
            const SizedBox(width: IqSpace.s3),
            Expanded(
              child: Text(text, textAlign: TextAlign.right, style: value),
            ),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Eyebrow('How you get paid'),
        MergeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: IqSpace.s3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Verification', style: label),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 36),
                  child: Text(
                    'By ${activation.business}, automatically',
                    style: value,
                  ),
                ),
              ],
            ),
          ),
        ),
        hairline,
        side('Paid to', 'Your iQLY wallet'),
        hairline,
        side(
          'Paid when',
          '${activation.business} confirms, usually within 24 hours',
        ),
      ],
    );
  }
}

class _Rules extends StatelessWidget {
  const _Rules();

  static const rules = [
    'One completion per person.',
    'Missed step? Proof within 48 hours.',
    'Can’t be confirmed? Ask iQLY for help.',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Rules'),
        for (final rule in rules) ...[
          const SizedBox(height: IqSpace.s1),
          Text(rule, style: IqText.small.copyWith(color: IqColors.fg2)),
        ],
      ],
    );
  }
}

/// Just started (179:8001), in progress (141:5090) and step not confirmed
/// (154:6202): the thread pinned under the top bar, the steps as they
/// stand, the reward, and the bar for the business's app (and the proof
/// once a step is past its window).
class _StepsPage extends StatelessWidget {
  const _StepsPage({
    required this.activation,
    required this.phase,
    required this.now,
    required this.chained,
    required this.onBack,
    required this.onRefresh,
    required this.onOpen,
    required this.onProof,
  });

  final Activation activation;
  final ActivationPhase phase;
  final DateTime now;
  final int? chained;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final VoidCallback onOpen;
  final VoidCallback onProof;

  bool get _stuck => phase == ActivationPhase.notConfirmed;

  Widget _step(int i) {
    final a = activation;
    final step = a.steps[i];
    final divider = i < a.steps.length - 1;
    final number = '${i + 1}';
    if (i < a.confirmed) {
      return IqStepRow(
        state: IqStepRowState.done,
        number: number,
        title: step.title,
        body:
            'Confirmed by ${a.business} · ${dayTime(a.progress!.confirmedAt[i])}',
        divider: divider,
      );
    }
    if (i == a.waitingStep && i != chained) {
      final row = IqStepRow(
        state: IqStepRowState.active,
        number: number,
        title: step.title,
        body: _stuck
            ? 'Not confirmed after a day'
            : 'Confirming, usually minutes',
        divider: divider,
      );
      if (_stuck) return row;
      return MergeSemantics(
        child: IqPressable(
          onTap: onRefresh,
          builder: (context, pressed) => PressDim(pressed: pressed, child: row),
        ),
      );
    }
    return IqStepRow(
      number: number,
      title: step.title,
      body: step.hint,
      divider: divider,
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = activation;
    final waiting = a.waitingStep;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IqTopBar(
          variant: IqTopBarVariant.page,
          title: 'Activation',
          onBack: onBack,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: IqSpace.s4,
            vertical: IqSpace.s2,
          ),
          child: IqProgressThread(
            status: _stuck
                ? 'Step ${waiting! + 1} not confirmed yet'
                : confirmedLine(a),
            count: _stuck ? waitingCount(a, now) : leftCount(a, now),
          ),
        ),
        Expanded(
          child: ListView(
            padding: _scrollPadding,
            children: [
              ActivationHeader(eyebrow: a.business, title: a.title),
              _gap,
              IqSectionTitle(
                showCount: true,
                title: 'What to do',
                count: '${a.steps.length}',
                showLink: false,
              ),
              _gap,
              for (var i = 0; i < a.steps.length; i++) ...[
                if (i > 0) _gap,
                _step(i),
              ],
              _gap,
              RewardLine(earn: earn(a)),
            ],
          ),
        ),
        ActionBar(
          children: [
            if (_stuck)
              IqButton(
                label: 'Upload proof of step ${waiting! + 1}',
                showIcon: false,
                width: double.infinity,
                onTap: onProof,
              ),
            IqButton(
              label: 'Open ${a.business}',
              kind: _stuck ? IqButtonKind.ghost : IqButtonKind.primary,
              showIcon: false,
              width: double.infinity,
              onTap: onOpen,
            ),
          ],
        ),
      ],
    );
  }
}

/// B9 · Proof · submitted (141:5549): CHECKING lands when the screen opens
/// on the change and its dot holds the pulse (the Current ring stays
/// still, PulseScope order); the recording without its remove sticker;
/// Ask for help goes to Help.
class _CheckingPage extends StatelessWidget {
  const _CheckingPage({
    required this.activation,
    required this.landed,
    required this.onBack,
    required this.onRefresh,
  });

  final Activation activation;
  final bool landed;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final a = activation;
    final proof = a.progress!.proof!;
    final video = proof.video;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IqTopBar(
          variant: IqTopBarVariant.page,
          title: 'Your proof',
          onBack: onBack,
        ),
        Expanded(
          child: ListView(
            padding: _scrollPadding,
            children: [
              ActivationHeader(
                above: Align(
                  alignment: Alignment.centerLeft,
                  child: IqClaimStamp(
                    kind: IqClaimStampKind.checking,
                    landAfter: landed ? Duration.zero : null,
                  ),
                ),
                eyebrow: 'Step ${proof.step + 1} · ${a.business}',
                title: a.title,
              ),
              _gap,
              const IqSectionTitle(
                title: 'Progress',
                showCount: false,
                showLink: false,
              ),
              _gap,
              IqTimelineRow(
                title: 'Proof received',
                meta: dayTime(proof.receivedAt),
              ),
              MergeSemantics(
                child: IqPressable(
                  onTap: onRefresh,
                  builder: (context, pressed) => PressDim(
                    pressed: pressed,
                    child: IqTimelineRow(
                      state: IqTimelineRowState.current,
                      title: 'Checking with ${a.business}',
                      meta: 'Usually within 24 hours',
                    ),
                  ),
                ),
              ),
              IqTimelineRow(
                state: IqTimelineRowState.upcoming,
                title: 'Paid to your wallet',
                meta: '${reward(a)} after confirmation',
                showLine: false,
              ),
              _gap,
              const Eyebrow('Your proof'),
              _gap,
              IqVideoPreview(
                name: video.name,
                meta:
                    '${videoLength(video.length)} · ${videoSize(video.bytes)}',
                showRemove: false,
                thumbnail: Hero(
                  tag: proofHeroTag(a.id),
                  child: const ProofFrame(),
                ),
                onPlay: () => context.push(proofPlayerPath(a.id)),
              ),
              _gap,
              const Eyebrow('Not credited yet?'),
              const SizedBox(height: IqSpace.s2),
              Text(
                'Support replies within 2 hours.',
                style: IqText.small.copyWith(color: IqColors.fg2),
              ),
              const SizedBox(height: IqSpace.s2),
              IqButton(
                label: 'Ask for help',
                kind: IqButtonKind.secondary,
                showIcon: false,
                width: double.infinity,
                onTap: () => context.push(helpPath(about: a.id)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Reward · credited (154:6312 when the business confirmed every step,
/// 141:5693 when proof was checked): the PAID stamp, the wallet with the
/// reward in it, the timeline, and the way on.
class _CreditedPage extends StatefulWidget {
  const _CreditedPage({
    required this.activation,
    required this.moment,
    required this.landed,
    required this.onBack,
  });

  final Activation activation;

  /// The payment landed while the screen was open: play the moment.
  final bool moment;

  /// The payment landed while a page covered the screen: the stamp lands
  /// as the screen shows, with nothing else.
  final bool landed;
  final VoidCallback onBack;

  @override
  State<_CreditedPage> createState() => _CreditedPageState();
}

class _CreditedPageState extends State<_CreditedPage> {
  Timer? _haptic;

  @override
  void initState() {
    super.initState();
    if (widget.moment) {
      _haptic = Timer(IqDurations.chain, IqHaptics.success.play);
    }
  }

  @override
  void dispose() {
    _haptic?.cancel();
    super.dispose();
  }

  void _findAnother() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.activations, extra: NavDirection.back);
    }
  }

  List<Widget> _timeline() {
    final a = widget.activation;
    final run = a.progress!;
    final proof = run.proof;
    final paid = IqTimelineRow(
      title: 'Paid to your wallet',
      meta: dayTime(run.paidAt!),
      showLine: false,
    );
    if (proof == null) {
      final n = a.steps.length;
      return [
        IqTimelineRow(
          title: 'Steps confirmed by ${a.business}',
          meta: '${dayTime(run.confirmedAt.last)} · $n of $n steps',
        ),
        paid,
      ];
    }
    return [
      IqTimelineRow(title: 'Proof received', meta: dayTime(proof.receivedAt)),
      IqTimelineRow(
        title: 'Checking with ${a.business}',
        meta: 'Confirmed ${dayTime(proof.checkedAt ?? run.paidAt!)}',
      ),
      paid,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.activation;
    final moment = widget.moment;
    final rows = _timeline();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IqTopBar(
          variant: IqTopBarVariant.page,
          title: 'Your reward',
          onBack: widget.onBack,
        ),
        Expanded(
          child: Stagger(
            play: moment,
            child: ListView(
              padding: _scrollPadding,
              children: [
                ActivationHeader(
                  above: Align(
                    alignment: Alignment.centerLeft,
                    child: IqClaimStamp(
                      kind: IqClaimStampKind.credited,
                      label: 'Paid ${reward(a)}',
                      landAfter: moment
                          ? IqDurations.chain
                          : widget.landed
                          ? Duration.zero
                          : null,
                    ),
                  ),
                  eyebrow: a.business,
                  title: a.title,
                ),
                _gap,
                const Eyebrow('Wallet'),
                _gap,
                _RewardWallet(activation: a, moment: moment),
                _gap,
                const Eyebrow('Progress'),
                _gap,
                for (final (i, row) in rows.indexed)
                  StaggerItem(
                    index: Stagger.moving - rows.length + i,
                    child: row,
                  ),
              ],
            ),
          ),
        ),
        ActionBar(
          children: [
            IqButton(
              label: 'View wallet',
              showIcon: false,
              width: double.infinity,
              onTap: () => context.go(Routes.wallet),
            ),
            IqButton(
              label: 'Find another activation',
              kind: IqButtonKind.ghost,
              showIcon: false,
              width: double.infinity,
              onTap: _findAnother,
            ),
          ],
        ),
      ],
    );
  }
}

/// The wallet as it stands, 146 tall with no Withdraw. During the moment
/// it shows the balance before the reward until +400, then the changed
/// digits roll (MOTION-SPEC §7.6, money rolls only on change). Reduced
/// motion: the new balance at once.
class _RewardWallet extends ConsumerStatefulWidget {
  const _RewardWallet({required this.activation, required this.moment});

  final Activation activation;
  final bool moment;

  /// The stamp lands at +120 for 240, then one beat: the roll at +400.
  static final Duration roll =
      IqDurations.chain + IqDurations.mark + IqDurations.stagger;

  @override
  ConsumerState<_RewardWallet> createState() => _RewardWalletState();
}

class _RewardWalletState extends ConsumerState<_RewardWallet> {
  bool _before = false;
  Timer? _roll;

  @override
  void initState() {
    super.initState();
    _before = widget.moment;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_before || _roll != null) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _before = false;
      return;
    }
    _roll = Timer(_RewardWallet.roll, () {
      if (mounted) setState(() => _before = false);
    });
  }

  @override
  void dispose() {
    _roll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(walletProvider).value;
    if (data == null) return const SizedBox(height: 146);
    final a = widget.activation;
    var totals = data.totals;
    final paidIn = data.ledger.any((l) => l.id == a.creditId);
    if (_before && paidIn) {
      totals = WalletTotals(
        totalEarnedKobo: totals.totalEarnedKobo - a.rewardKobo,
        pendingWithdrawalsKobo: totals.pendingWithdrawalsKobo,
        withdrawableKobo: totals.withdrawableKobo - a.rewardKobo,
      );
    }
    final (whole, decimals) = nairaParts(totals.withdrawableKobo);
    return IqBalanceHero(
      amount: whole,
      decimals: decimals,
      onHold: naira(totals.pendingWithdrawalsKobo),
      earned: naira(totals.totalEarnedKobo),
      holdLabel: 'On hold · ${data.onHoldCount} pending',
      showWithdraw: false,
      figureBuilder: (text, style) => RollingText(text, style: style),
    );
  }
}
