import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/deadline.dart';
import '../../core/flags.dart';
import '../../core/money.dart';
import '../../core/motion.dart';
import '../../core/navigation.dart';
import '../../core/responsive.dart';
import '../../core/transitions.dart';
import '../../data/activations_data.dart';
import '../../data/api_client.dart';
import '../../data/help_service.dart' show supportShownProvider;
import '../../data/device.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/brief_hero.dart';
import '../../ui/button.dart';
import '../../ui/empty_state.dart';
import '../../ui/illustration.dart';
import '../../ui/meta.dart';
import '../../ui/pressable.dart';
import '../../ui/progress_thread.dart';
import '../../ui/section_title.dart';
import '../../ui/step_row.dart';
import '../../ui/timeline_row.dart';
import '../../ui/toast.dart';
import '../../ui/top_bar.dart';
import '../../ui/video_preview.dart';
import '../help/help_routes.dart';
import '../more/more_widgets.dart' show CodeBox;
import '../profile/profile_routes.dart';
import '../profile/your_details_screen.dart' show DetailField;
import '../settings/restore_account_screen.dart' show showClosingAccount;
import 'activation_format.dart';
import 'activations_routes.dart';
import 'activations_state.dart';
import 'activations_widgets.dart';

enum _Layout { offer, steps, proof, credited }

/// Why Start cannot go, as a refused Start said it.
enum _Unstartable { paused, ended, refused }

_Layout _layoutOf(ActivationPhase phase) => switch (phase) {
  ActivationPhase.offer || ActivationPhase.expired => _Layout.offer,
  ActivationPhase.started ||
  ActivationPhase.confirming ||
  ActivationPhase.notConfirmed ||
  ActivationPhase.recording => _Layout.steps,
  ActivationPhase.checking || ActivationPhase.notAccepted => _Layout.proof,
  ActivationPhase.credited => _Layout.credited,
};

/// One activation, one sub page whose state follows the service:
/// B8 · Activation detail (141:4941, also B9 161:16280) before it starts
/// and expired (485:38428) once it closed; just started (179:8001), in
/// progress (141:5090) and B9 · step not confirmed (154:6202) while steps
/// wait; B9 · Proof · submitted (141:5549) and not accepted (485:38715)
/// once proof is in; Reward · credited (154:6312 after the business
/// confirms, 141:5693 after proof).
///
/// Start activation gives the commit haptic and the offer dissolves into
/// just started. A confirmed step pops to Done and the next goes Active
/// 120 ms later. A step left unconfirmed for 24 hours turns the screen to
/// step not confirmed. Being paid dissolves to the reward with the success
/// haptic; paid while a page covers the screen, it is already there when
/// that page leaves. Tapping the waiting step or the Checking row asks for
/// the latest state.
///
/// The rules of 19 Oct (no frame draws them): in proof mode the steps page
/// marks the step to do and record next, with Upload proof of it, from the
/// start; once its proof is accepted the next one is. In postback mode the
/// run's code sits under the title with Copy (owner decision D2), drawn as
/// B20 draws the invite code. A per-step activation reads "Up to" on its
/// offer and each paying step its amount, "Paid" once paid (Round 18).
/// While steps are under way the person can ask for help about the run.
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
  String? _startFailed;

  /// What a refused Start said for good, should reading the activation
  /// again not say it: Start stays off rather than refused on every tap.
  _Unstartable? _unstartable;
  bool _paidHere = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Why the activation could not be shown, once asking has settled.
  ActivationMissing? _missing;

  /// Reads the activation behind what shows; one opened from a link or a
  /// notification that the list did not hold lands, or says why not.
  Future<void> _load() async {
    final missing = await ref
        .read(activationsProvider.notifier)
        .load(widget.id);
    if (mounted) setState(() => _missing = missing);
  }

  void _loadAgain() {
    setState(() => _missing = null);
    _load();
  }

  @override
  void dispose() {
    _chain?.cancel();
    _window?.cancel();
    super.dispose();
  }

  void _onChange(Activation? before, Activation? after) {
    if (after != null &&
        !identical(before, after) &&
        !after.paused &&
        _unstartable == _Unstartable.paused) {
      setState(() => _unstartable = null);
    }
    if (before == null || after == null) return;
    final now = ref.read(clockProvider)();
    if (after.phaseAt(now) == ActivationPhase.credited &&
        before.phaseAt(now) != ActivationPhase.credited) {
      setState(() => _paidHere = !covered(context));
    }
    final next = after.confirmationMode == ConfirmationMode.proof
        ? after.proofStep
        : after.waitingStep;
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
    final phase = activation.phaseAt(now);
    if (since == null ||
        (phase != ActivationPhase.confirming &&
            phase != ActivationPhase.started)) {
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

  /// No answer, a throttle or a fault keeps Try again. A refusal says
  /// "Couldn't start." and reads the activation again, so a full, paused or
  /// ended one shows as it is and Start stays off; under 18 opens Date of
  /// birth and a closing account goes to Restore, as a send does.
  Future<void> _start() async {
    if (_starting) return;
    setState(() {
      _starting = true;
      _startFailed = null;
    });
    final notifier = ref.read(activationsProvider.notifier);
    const retry = "Couldn't start. Check your connection.";
    try {
      await notifier.start(widget.id);
    } on ApiRefused catch (refusal) {
      if (!mounted) return;
      errorHaptic();
      if (unanswered(refusal)) {
        setState(() {
          _starting = false;
          _startFailed = retry;
        });
        return;
      }
      final closing = refusal.code == 'ACCOUNT_CLOSING' && Flags.deleteAccount;
      final paused = refusal.code == 'ACTIVATION_PAUSED';
      setState(() {
        _starting = false;
        _startFailed = closing || paused ? null : "Couldn't start.";
        _unstartable = switch (refusal.code) {
          'ACTIVATION_PAUSED' => _Unstartable.paused,
          'ACTIVATION_CLOSED' || 'ACTIVATION_NOT_FOUND' => _Unstartable.ended,
          'ACTIVATION_FULL' ||
          'ACTIVATION_OWN_BUSINESS' => _Unstartable.refused,
          _ => _unstartable,
        };
      });
      if (closing) return showClosingAccount(context, ref);
      if (refusal.code == 'UNDER_AGE') {
        await context.open<void>(editDetailPath(DetailField.dateOfBirth));
        return;
      }
      await notifier.refreshOneQuietly(widget.id);
      return;
    } on Object {
      if (!mounted) return;
      errorHaptic();
      setState(() {
        _starting = false;
        _startFailed = retry;
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

  void _recordAgain() {
    ref.read(proofDraftProvider(widget.id).notifier).clear();
    context.open(proofPath(widget.id));
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
      page = _Page(
        title: 'Activation',
        onBack: _back,
        body: switch (_missing) {
          ActivationMissing.gone => IqEmptyFill(
            child: IqEmptyState(
              figure: IqFigures.shrug,
              title: 'This activation has ended',
              action: 'Find another activation',
              onAction: () =>
                  context.go(Routes.activations, extra: NavDirection.back),
            ),
          ),
          ActivationMissing.unreachable => Padding(
            padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
            child: Align(
              alignment: Alignment.topCenter,
              child: IqBanner(
                kind: IqBannerKind.error,
                title: "Couldn't load. Check your connection.",
                action: 'Try again',
                onAction: _loadAgain,
              ),
            ),
          ),
          null => const SizedBox(),
        },
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
          failure: _startFailed,
          unstartable: _unstartable,
          onStart: _start,
          onBack: _back,
        ),
        _Layout.steps => _StepsPage(
          activation: activation,
          phase: phase,
          now: now,
          chained: _chained,
          support: ref.watch(supportShownProvider),
          onBack: _back,
          onRefresh: _refresh,
          onOpen: () => _open(activation),
          onProof: () => context.open(proofPath(activation.id)),
          onHelp: () => context.open(helpPath(about: activation.id)),
        ),
        _Layout.proof => _ProofPage(
          activation: activation,
          now: now,
          support: ref.watch(supportShownProvider),
          onBack: _back,
          onRefresh: _refresh,
          onRecordAgain: _recordAgain,
        ),
        _Layout.credited => _CreditedPage(
          activation: activation,
          moment: _paidHere,
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

/// The sub page frame: the Page top bar, the body, the action bar.
class _Page extends StatelessWidget {
  const _Page({
    required this.title,
    required this.onBack,
    required this.body,
    this.status,
    this.actions = const [],
    this.divider = false,
  });

  final String title;
  final VoidCallback onBack;
  final Widget body;
  final Widget? status;
  final List<Widget> actions;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IqTopBar(variant: IqTopBarVariant.page, title: title, onBack: onBack),
        ?status,
        Expanded(child: body),
        if (actions.isNotEmpty) ActionBar(divider: divider, children: actions),
      ],
    );
  }
}

const _padding = EdgeInsets.fromLTRB(IqSpace.s4, 0, IqSpace.s4, IqSpace.s6);

/// The business beside its name and "Activation". A name from the API can
/// run long, so it gives way with an ellipsis.
class _BrandRow extends StatelessWidget {
  const _BrandRow({required this.activation, this.logo = true});

  final Activation activation;
  final bool logo;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Row(
        children: [
          if (logo) ...[
            ClipOval(child: activationLogoArt(activation, size: 36)),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Text(
              activation.business,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: IqText.smallStrong.copyWith(color: IqColors.fg),
            ),
          ),
          const SizedBox(width: 10),
          Text('Activation', style: IqText.small.copyWith(color: IqColors.fg3)),
        ],
      ),
    );
  }
}

List<Widget> _gapped(List<Widget> children, double gap) => [
  for (final (i, child) in children.indexed) ...[
    if (i > 0) SizedBox(height: gap),
    child,
  ],
];

/// B8 · Activation detail (141:4941) and expired (485:38428): the
/// business's photo with its logo, the offer, how it pays and the steps,
/// Start activation in the bar (disabled once it has ended).
class _OfferPage extends StatelessWidget {
  const _OfferPage({
    required this.activation,
    required this.now,
    required this.starting,
    required this.failure,
    required this.onStart,
    required this.onBack,
    this.unstartable,
  });

  final Activation activation;
  final DateTime now;
  final bool starting;

  /// The banner over the offer when Start did not go through.
  final String? failure;
  final VoidCallback onStart;
  final VoidCallback onBack;
  final _Unstartable? unstartable;

  @override
  Widget build(BuildContext context) {
    final a = activation;
    final ended = a.closedAt(now) || unstartable == _Unstartable.ended;
    final paused = !ended && (a.paused || unstartable == _Unstartable.paused);
    return _Page(
      title: 'Activation',
      onBack: onBack,
      divider: true,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Hero(
            child: IqBriefHero(
              cover: activationCoverArt(a),
              logo: activationLogoArt(a),
              showDots: false,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              IqSpace.s4,
              5,
              IqSpace.s4,
              IqSpace.s6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _gapped([
                Padding(
                  padding: const EdgeInsets.only(left: 66),
                  child: _BrandRow(activation: a, logo: false),
                ),
                if (failure case final title?)
                  IqBanner(
                    kind: IqBannerKind.error,
                    title: title,
                    action: 'Try again',
                    showAction: title.endsWith('connection.'),
                    onAction: onStart,
                  ),
                Text(
                  a.title,
                  style: IqText.headline.copyWith(color: IqColors.fg),
                ),
                Wrap(
                  spacing: IqSpace.s1p5,
                  runSpacing: IqSpace.s1p5,
                  children: [
                    IqMeta(kind: IqMetaKind.reward, label: offerReward(a)),
                    IqMeta(kind: IqMetaKind.time, label: minutesText(a)),
                    IqMeta(
                      kind: closingSoon(a, now)
                          ? IqMetaKind.urgent
                          : IqMetaKind.deadline,
                      label: deadlineText(a, now),
                    ),
                  ],
                ),
                Text(
                  'Paid to your iQLY wallet once ${a.business} confirms, '
                  'usually within 24 hours.',
                  style: IqText.body.copyWith(color: IqColors.fg),
                ),
                const IqSectionTitle(title: 'What to do', showLink: false),
                for (final (i, step) in a.steps.indexed)
                  IqStepRow(
                    number: '${i + 1}',
                    title: step.title,
                    body: step.howTo ?? step.hint,
                    divider: i < a.steps.length - 1,
                    showReward: showsStepReward(a, i),
                    reward: stepRewardText(a, i),
                  ),
              ], 14),
            ),
          ),
        ],
      ),
      actions: [
        IqButton(
          label: ended
              ? 'This activation has ended'
              : paused
              ? 'This activation is paused'
              : 'Start activation',
          showIcon: false,
          width: double.infinity,
          loading: starting,
          disabled:
              ended || paused || a.full || unstartable == _Unstartable.refused,
          onTap: onStart,
        ),
      ],
    );
  }
}

/// The 232 hero of the frames. Exp/BriefHero is fixed at 280 with its logo
/// 28 below the photo, so the screen shows it from its foot and the top 48
/// of the photo stays out of view, which lands the logo where Figma puts it.
class _Hero extends StatelessWidget {
  const _Hero({required this.child});

  final Widget child;

  static const double height = 232;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ClipRect(
        clipper: const _CutTop(),
        child: OverflowBox(
          alignment: Alignment.bottomCenter,
          minHeight: IqBriefHero.defaultHeight,
          maxHeight: IqBriefHero.defaultHeight,
          child: child,
        ),
      ),
    );
  }
}

class _CutTop extends CustomClipper<Rect> {
  const _CutTop();

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, 0, size.width, size.height + IqBriefHero.defaultHeight);

  @override
  bool shouldReclip(_CutTop oldClipper) => false;
}

/// The business's logo, name and the title, as the step and proof frames
/// head their content (8 above and below, 8 between).
class _Header extends StatelessWidget {
  const _Header({required this.activation, this.above});

  final Activation activation;
  final Widget? above;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: IqSpace.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          above ?? _BrandRow(activation: activation),
          const SizedBox(height: IqSpace.s2),
          Text(
            activation.title,
            style: IqText.title.copyWith(color: IqColors.fg),
          ),
        ],
      ),
    );
  }
}

/// Just started (179:8001), in progress (141:5090) and step not confirmed
/// (154:6202): the thread pinned under the top bar, the steps as they
/// stand, the reward, and the bar for the business's app (and the proof
/// once a step is past its window, or from the start in proof mode).
class _StepsPage extends StatelessWidget {
  const _StepsPage({
    required this.activation,
    required this.phase,
    required this.now,
    required this.chained,
    required this.support,
    required this.onBack,
    required this.onRefresh,
    required this.onOpen,
    required this.onProof,
    required this.onHelp,
  });

  final Activation activation;
  final ActivationPhase phase;
  final DateTime now;
  final int? chained;

  /// Whether this launch has support to ask, so Ask for help shows.
  final bool support;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final VoidCallback onOpen;
  final VoidCallback onProof;
  final VoidCallback onHelp;

  bool get _stuck => phase == ActivationPhase.notConfirmed;

  bool get _recording => phase == ActivationPhase.recording;

  /// The step that is the person's or the business's now. Just started,
  /// none is: the first step waits to be done.
  int? get _activeStep => _recording
      ? activation.proofStep
      : phase == ActivationPhase.started
      ? null
      : activation.waitingStep;

  Widget _step(int i) {
    final a = activation;
    final step = a.steps[i];
    final divider = i < a.steps.length - 1;
    final number = '${i + 1}';
    final showReward = showsStepReward(a, i);
    final reward = stepRewardText(a, i);
    if (i < a.confirmed) {
      return IqStepRow(
        state: IqStepRowState.done,
        number: number,
        title: step.title,
        body:
            'Confirmed by ${a.business} · ${dayTime(a.progress!.confirmedAt[i])}',
        divider: divider,
        showReward: showReward,
        reward: reward,
      );
    }
    if (i == _activeStep && i != chained) {
      final row = IqStepRow(
        state: IqStepRowState.active,
        number: number,
        title: step.title,
        body: _recording
            ? step.hint
            : _stuck
            ? 'Not confirmed after a day'
            : '${a.business} is checking. Usually a few minutes.',
        divider: divider,
        showReward: showReward,
        reward: reward,
      );
      if (_stuck || _recording) return row;
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
      showReward: showReward,
      reward: reward,
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = activation;
    final waiting = a.waitingStep;
    final proving = _stuck || _recording;
    final code = a.confirmationMode == ConfirmationMode.postback
        ? a.progress?.refCode
        : null;
    return _Page(
      title: 'Activation',
      onBack: onBack,
      status: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: IqSpace.s4,
          vertical: IqSpace.s2,
        ),
        child: IqProgressThread(
          status: _stuck
              ? 'Step ${waiting! + 1} not confirmed yet'
              : progressLine(a),
          count: _stuck ? waitingCount(a, now) : deadlineText(a, now),
        ),
      ),
      body: ListView(
        padding: _padding,
        children: _gapped([
          _Header(activation: a),
          if (code != null) _RunCode(code: code),
          const IqSectionTitle(title: 'What to do', showLink: false),
          for (var i = 0; i < a.steps.length; i++) _step(i),
          MergeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.perStep ? 'Earn up to ${reward(a)}' : 'Earn ${reward(a)}',
                  style: IqText.bodyStrong.copyWith(color: IqColors.brand),
                ),
                const SizedBox(width: IqSpace.s2),
                Flexible(
                  child: Text(
                    a.perStep
                        ? 'paid step by step'
                        : 'when all ${a.steps.length} steps are confirmed',
                    style: IqText.small.copyWith(color: IqColors.fg2),
                  ),
                ),
              ],
            ),
          ),
          if (support) _AskForHelp(onTap: onHelp),
        ], IqSpace.s4),
      ),
      actions: [
        if (proving)
          IqButton(
            label: 'Upload proof of step ${a.proofStep! + 1}',
            showIcon: false,
            width: double.infinity,
            onTap: onProof,
          ),
        IqButton(
          label: 'Open ${a.business}',
          kind: proving ? IqButtonKind.ghost : IqButtonKind.primary,
          showIcon: false,
          width: double.infinity,
          onTap: onOpen,
        ),
      ],
    );
  }
}

/// Postback mode: the run's code, for a business's app that asks for it
/// (one opened from the App Store gets no link), with Copy.
class _RunCode extends StatefulWidget {
  const _RunCode({required this.code});

  final String code;

  @override
  State<_RunCode> createState() => _RunCodeState();
}

class _RunCodeState extends State<_RunCode> {
  static const _copiedFor = Duration(seconds: 2);

  bool _copied = false;
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    IqHaptics.success.play();
    if (!mounted) return;
    IqToast.show(context, 'Code copied');
    setState(() => _copied = true);
    _reset?.cancel();
    _reset = Timer(_copiedFor, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) =>
      CodeBox(code: widget.code, copied: _copied, onCopy: _copy);
}

/// A run under way asks for help about itself: the help request, which
/// goes to the business behind it on an API that routes it there.
class _AskForHelp extends StatelessWidget {
  const _AskForHelp({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Stuck on a step?',
          style: IqText.bodyStrong.copyWith(color: IqColors.fg3),
        ),
        const SizedBox(height: IqSpace.s2),
        IqButton(
          label: 'Ask for help',
          kind: IqButtonKind.secondary,
          showIcon: false,
          width: double.infinity,
          onTap: onTap,
        ),
      ],
    );
  }
}

/// B9 · Proof · submitted (141:5549) and not accepted (485:38715): what the
/// proof is waiting on, the recording without its remove sticker, and the
/// way to support. Not accepted puts the business's reason on the Error
/// banner with Record again, which opens a fresh Upload proof.
class _ProofPage extends StatelessWidget {
  const _ProofPage({
    required this.activation,
    required this.now,
    required this.support,
    required this.onBack,
    required this.onRefresh,
    required this.onRecordAgain,
  });

  final Activation activation;
  final DateTime now;

  /// Whether this launch has support to ask: "Not credited yet?" and Ask
  /// for help show only then.
  final bool support;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final VoidCallback onRecordAgain;

  @override
  Widget build(BuildContext context) {
    final a = activation;
    final proof = a.progress!.proof!;
    final video = proof.video;
    final refused = proof.notAccepted;
    final label = IqText.bodyStrong.copyWith(color: IqColors.fg3);
    final ended = refused != null && !a.canProveAt(now);
    final pays = a.paysFor(proof.step);
    return _Page(
      title: 'Your proof',
      onBack: onBack,
      actions: [
        if (ended)
          const IqButton(
            label: 'This activation has ended',
            showIcon: false,
            width: double.infinity,
            disabled: true,
          ),
      ],
      body: ListView(
        padding: _padding,
        children: _gapped([
          if (refused != null)
            IqBanner(
              kind: IqBannerKind.error,
              title: 'Proof not accepted. $refused',
              action: 'Record again',
              showAction: !ended,
              onAction: onRecordAgain,
            ),
          _Header(
            activation: a,
            above: IqMeta(
              kind: IqMetaKind.time,
              label: 'Checking with ${a.business}',
            ),
          ),
          const IqSectionTitle(title: 'Progress', showLink: false),
          Column(
            children: [
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
                      showLine: pays > 0,
                    ),
                  ),
                ),
              ),
              if (pays > 0)
                IqTimelineRow(
                  state: IqTimelineRowState.upcoming,
                  title: 'Paid to your wallet',
                  meta: '${naira(pays)} after confirmation',
                  showLine: false,
                ),
            ],
          ),
          Text('Your proof', style: label),
          if (support)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Not credited yet?', style: label),
                const SizedBox(height: IqSpace.s2),
                Text(
                  'Support usually replies within an hour on weekdays, within '
                  'a day at weekends.',
                  style: IqText.small.copyWith(color: IqColors.fg2),
                ),
                const SizedBox(height: IqSpace.s2),
                IqButton(
                  label: 'Ask for help',
                  showIcon: false,
                  width: double.infinity,
                  onTap: () => context.open(helpPath(about: a.id)),
                ),
              ],
            ),
          IqVideoPreview(
            name: video.name,
            duration: video.length == null ? '' : videoLength(video.length!),
            meta: videoFacts(video),
            showRemove: false,
            thumbnail: ProofFrame(source: video.source),
            heroTag: proofHeroTag(a.id),
            onPlay: () => context.open(proofPlayerPath(a.id)),
          ),
        ], IqSpace.s4),
      ),
    );
  }
}

/// Reward · credited (154:6312 when the business confirmed every step,
/// 141:5693 when proof was checked): the Cheer, the reward in the wallet,
/// the timeline, and the way on. Paid while the screen was open, the
/// success haptic plays as the figure arrives.
class _CreditedPage extends StatefulWidget {
  const _CreditedPage({
    required this.activation,
    required this.moment,
    required this.onBack,
  });

  final Activation activation;
  final bool moment;
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
    return _Page(
      title: 'Your reward',
      onBack: widget.onBack,
      body: ListView(
        padding: _padding,
        children: _gapped([
          const Center(
            child: IqFigure(IqFigures.cheer, width: 188.2353, arrive: true),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: IqSpace.s2),
            child: Column(
              children: [
                Text(
                  '${naira(a.rewardKobo)} is yours',
                  textAlign: TextAlign.center,
                  style: IqText.display.copyWith(color: IqColors.fg),
                ),
                const SizedBox(height: IqSpace.s2),
                Text(
                  '${a.business} confirmed all ${a.steps.length} steps. '
                  "It's in your wallet.",
                  textAlign: TextAlign.center,
                  style: IqText.body.copyWith(color: IqColors.fg2),
                ),
              ],
            ),
          ),
          Column(children: _timeline()),
        ], IqSpace.s4),
      ),
      actions: [
        IqButton(
          label: 'View wallet',
          kind: IqButtonKind.ghost,
          showIcon: false,
          width: double.infinity,
          onTap: () => context.go(Routes.wallet),
        ),
        IqButton(
          label: 'Find another activation',
          showIcon: false,
          width: double.infinity,
          onTap: _findAnother,
        ),
      ],
    );
  }
}
