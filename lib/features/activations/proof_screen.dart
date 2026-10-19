import 'dart:math' as math;

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
import '../../data/activations_data.dart';
import '../../data/api_client.dart';
import '../../data/media_service.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/button.dart';
import '../../ui/confirm_sheet.dart';
import '../../ui/field.dart';
import '../../ui/proof_tile.dart';
import '../../ui/top_bar.dart';
import '../../ui/video_preview.dart';
import '../settings/restore_account_screen.dart' show showClosingAccount;
import 'activation_format.dart';
import 'activations_routes.dart';
import 'activations_state.dart';
import 'activations_widgets.dart';

/// B9 · Upload proof: empty (141:5210), ready (141:5372), remove
/// recording? (141:5492), upload failed (485:38534), video too long
/// (485:38622) and photo permission (485:38820), with the kit's uploading
/// state between them.
///
/// The empty tile breathes and holds the screen's pulse. The first pick
/// asks for photo access on the frame's sheet (Don't Allow leaves the tile
/// as it was); then the phone's picker opens. A pick morphs the tile into
/// the polaroid (320 ms ease-in-out): the thread fills as it uploads and
/// the play sticker pops when it is ready. A recording over 60 seconds (or
/// 50 MB) is refused before it uploads: the polaroid shows Failed with the
/// banner under it, and Retry picks again. Remove asks first; Remove
/// recording tilts the polaroid as it fades and the tile comes back. Send
/// proof is disabled until a recording is in; tapped before it is ready,
/// the slot shakes with the error haptic. Once sent, the success haptic and
/// back to the activation, which now reads Your proof.
///
/// The line over the slot promises what confirming the step pays: the
/// reward on a per-run activation, as the frames say, and the step's own
/// amount on a per-step one (nothing when the step pays nothing).
///
/// Figma over this build: 141:5492 shows the phone field's placeholder as
/// "e.g. 0801 234 5678"; the build keeps "0801 234 5678" of the other
/// frames. The textarea frame is drawn with Exp/Field, the one text entry
/// component.
class ProofScreen extends ConsumerStatefulWidget {
  const ProofScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<ProofScreen> createState() => _ProofScreenState();
}

class _ProofScreenState extends ConsumerState<ProofScreen> {
  late final _phone = TextEditingController(
    text: ref.read(proofDraftProvider(widget.id)).phone,
  );
  late final _note = TextEditingController(
    text: ref.read(proofDraftProvider(widget.id)).note,
  );
  int _shakes = 0;
  bool _sending = false;

  /// A send refused because the run can take no proof any more.
  bool _ended = false;

  static const _retry = "Couldn't send. Check your connection.";

  /// The banner over the form when the proof did not go: no connection
  /// keeps Try again; a refusal keeps the first sentence.
  String? _failed;

  /// 141:5492 and 485:38820 dim the screen with ink at 50%.
  static final _scrim = IqColors.fg.withValues(alpha: IqOpacity.sheetScrim);

  ProofDraftNotifier get _draft =>
      ref.read(proofDraftProvider(widget.id).notifier);

  @override
  void dispose() {
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  /// The frame's photos prompt before the first pick, then the picker.
  Future<void> _pick() async {
    final media = ref.read(mediaServiceProvider);
    if (media.access != MediaAccess.allowed) {
      final allow = await showIqConfirmSheet(
        context,
        title: '“iQLY” Would Like to Access Your Photos',
        body:
            'To add your screen recording. You can change this later in '
            'Settings.',
        confirmLabel: 'Allow Full Access',
        cancelLabel: 'Don’t Allow',
        confirmKind: IqButtonKind.primary,
        scrim: _scrim,
      );
      media.answer(allow: allow);
      if (!allow || !mounted) return;
    }
    await _draft.pick();
  }

  /// A refused recording cannot be retried: Retry picks another.
  void _again(ProofDraft draft) {
    if (draft.stage == ProofStage.refused) {
      _pick();
    } else {
      _draft.retry();
    }
  }

  Future<void> _remove() async {
    final remove = await showIqConfirmSheet(
      context,
      title: 'Remove this recording?',
      body: 'You’ll need to upload it again.',
      scrim: _scrim,
    );
    if (remove && mounted) _draft.remove();
  }

  Future<void> _send(Activation activation, ProofDraft draft) async {
    final step = activation.proofStep;
    final video = draft.video;
    final uploadId = draft.uploadId;
    if (draft.stage != ProofStage.ready ||
        step == null ||
        video == null ||
        uploadId == null) {
      setState(() => _shakes++);
      errorHaptic();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _failed = null;
    });
    final activations = ref.read(activationsProvider.notifier);
    try {
      await activations.sendProof(
        activation.id,
        step: step,
        uploadId: uploadId,
        video: video,
        phone: _phone.text.trim(),
        note: _note.text.trim(),
      );
    } on ApiRefused catch (refusal) {
      if (!mounted) return;
      errorHaptic();
      if (unanswered(refusal)) {
        setState(() {
          _sending = false;
          _failed = _retry;
        });
        return;
      }
      final code = refusal.code;
      final closing = code == 'ACCOUNT_CLOSING' && Flags.deleteAccount;
      final ended = activationRunEnded(code);
      setState(() {
        _sending = false;
        _ended = ended;
        _failed = closing || ended ? null : "Couldn't send.";
      });
      if (closing) return showClosingAccount(context, ref);
      if (code == 'ACTIVATION_UPLOAD_NOT_FOUND') return _draft.lost();
      await activations.refreshOneQuietly(activation.id);
      if (!mounted) return;
      // Paid meanwhile, not due yet, or a proof already waits: the
      // activation's own page says where it stands, where sending again
      // could only be refused.
      final paid = ref.read(activationProvider(activation.id))?.credited;
      if (paid == true ||
          code == 'ACTIVATION_PROOF_NOT_DUE' ||
          code == 'ACTIVATION_PROOF_PENDING') {
        _toActivation();
      }
      return;
    } on Object {
      if (!mounted) return;
      errorHaptic();
      setState(() {
        _sending = false;
        _failed = _retry;
      });
      return;
    }
    if (!mounted) return;
    IqHaptics.success.play();
    _draft.clear();
    context.pop();
  }

  bool _leaving = false;

  void _toActivation() {
    if (_leaving || !mounted) return;
    _leaving = true;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(activationPath(widget.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(proofDraftProvider(widget.id), (previous, next) {
      if (next.stage == ProofStage.refused &&
          previous?.stage != ProofStage.refused) {
        errorHaptic();
        if (next.refusal == ProofRefusal.closing && Flags.deleteAccount) {
          showClosingAccount(context, ref);
        }
      }
    });
    final activation = ref.watch(activationProvider(widget.id));
    final draft = ref.watch(proofDraftProvider(widget.id));
    final now = ref.watch(clockProvider)();
    // Paid while recording: back to the activation, which shows the reward.
    final paid = activation?.credited ?? false;
    if (paid && !_sending) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _toActivation());
    }
    // Closed or never started: no proof can go, so nothing offers to
    // record or send one.
    final ended =
        activation != null &&
        !paid &&
        (_ended ||
            draft.refusal == ProofRefusal.ended ||
            draft.refusal == ProofRefusal.paid ||
            !activation.canProveAt(now));
    final index = activation?.proofStep ?? activation?.confirmed ?? 0;
    final step = index + 1;
    final pays = activation?.paysFor(index) ?? 0;
    final refused = draft.stage == ProofStage.refused ? draft.video : null;
    final refusal = refused == null ? null : _refusal(refused, draft.refusal);

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
                  title: 'Upload proof',
                  onBack: () => context.canPop()
                      ? context.pop()
                      : context.go(activationPath(widget.id)),
                ),
                Expanded(
                  child: activation == null || ended || paid
                      ? const SizedBox.shrink()
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(
                            IqSpace.s4,
                            0,
                            IqSpace.s4,
                            IqSpace.s4,
                          ),
                          children: [
                            if (_failed case final failed?) ...[
                              IqBanner(
                                kind: IqBannerKind.error,
                                title: failed,
                                action: 'Try again',
                                showAction: failed.endsWith('connection.'),
                                onAction: () => _send(activation, draft),
                              ),
                              const SizedBox(height: IqSpace.s4),
                            ],
                            Text(
                              pays > 0
                                  ? 'Record step $step. ${activation.business} '
                                        'confirms it, then we pay '
                                        '${rewardPool(pays)}.'
                                  : 'Record step $step. ${activation.business} '
                                        'confirms it.',
                              style: IqText.body.copyWith(color: IqColors.fg2),
                            ),
                            const SizedBox(height: IqSpace.s4),
                            Text(
                              'Proof of step $step · up to '
                              '${ActivationRules.proofLength.inSeconds} seconds',
                              style: IqText.label.copyWith(color: IqColors.fg2),
                            ),
                            const SizedBox(height: IqSpace.s4),
                            Shake(
                              trigger: _shakes,
                              child: _ProofSlot(
                                draft: draft,
                                heroTag: proofHeroTag(activation.id),
                                onPick: _pick,
                                onRetry: () => _again(draft),
                                onRemove: _remove,
                                onPlay: () => context.open(
                                  proofPlayerPath(activation.id),
                                ),
                              ),
                            ),
                            if (refusal != null) ...[
                              const SizedBox(height: IqSpace.s4),
                              IqBanner(
                                kind: IqBannerKind.error,
                                title: refusal,
                                showAction: false,
                              ),
                            ],
                            const SizedBox(height: IqSpace.s4),
                            IqField(
                              label:
                                  '${activation.business} account phone '
                                  'number (optional)',
                              value: '0801 234 5678',
                              controller: _phone,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9+ ]'),
                                ),
                              ],
                              autofillHints: const [
                                AutofillHints.telephoneNumber,
                              ],
                              onChanged: _draft.setPhone,
                            ),
                            const SizedBox(height: IqSpace.s4),
                            IqField(
                              label: 'Anything we should know? (optional)',
                              value: 'e.g. I used a different phone number',
                              controller: _note,
                              textInputAction: TextInputAction.done,
                              onChanged: _draft.setNote,
                            ),
                          ],
                        ),
                ),
                if (paid)
                  const SizedBox.shrink()
                else if (ended)
                  const ActionBar(
                    children: [
                      IqButton(
                        label: 'This activation has ended',
                        showIcon: false,
                        width: double.infinity,
                        disabled: true,
                      ),
                    ],
                  )
                else
                  ActionBar(
                    children: [
                      IqButton(
                        label: 'Send proof',
                        showIcon: false,
                        width: double.infinity,
                        loading: _sending,
                        disabled: !draft.hasVideo,
                        onTap: activation == null
                            ? null
                            : () => _send(activation, draft),
                      ),
                      Text(
                        'By sending, you confirm you did these steps yourself.',
                        style: IqText.small.copyWith(color: IqColors.fg3),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 485:38622: "Your video is 1:42. Keep it under 60 seconds and end on the
  /// Verification page." A recording over 50 MB gets the same line with its
  /// size (no frame draws it), and one of a kind the API does not take none.
  static String? _refusal(ProofVideo video, ProofRefusal? why) {
    if (why == ProofRefusal.kind) return null;
    final length = video.length;
    if ((why ?? ProofRefusal.of(video)) == ProofRefusal.length &&
        length != null) {
      return 'Your video is ${videoLength(length)}. Keep it under '
          '${ActivationRules.proofLength.inSeconds} seconds and end on the '
          'Verification page.';
    }
    return 'Your video is ${videoSize(video.bytes)}. Keep it under '
        '${videoSize(ActivationRules.proofBytes)} and end on the '
        'Verification page.';
  }
}

/// Where the recording goes: the ProofTile until one is picked, then the
/// polaroid. Picking morphs one into the other (AnimatedSize 320 ease-in-out
/// with the contents crossfading); removing tilts the polaroid 3° as it
/// fades over 200, then the tile appears (fade and rise 8, 220). Reduced
/// motion: a 150 ms crossfade, nothing moves.
class _ProofSlot extends StatelessWidget {
  const _ProofSlot({
    required this.draft,
    required this.heroTag,
    required this.onPick,
    required this.onRetry,
    required this.onRemove,
    required this.onPlay,
  });

  final ProofDraft draft;
  final String heroTag;
  final VoidCallback onPick;
  final VoidCallback onRetry;
  final VoidCallback onRemove;
  final VoidCallback onPlay;

  static const _removed = IqDurations.swap;
  static const _tileBack = IqDurations.appear;

  /// Figma 168:1071: "polaroid tilts 3° and fades out".
  static const _tilt = 3 * math.pi / 180;

  /// The tile waits for the polaroid to go, then fades in.
  static final _tileIn = Interval(
    _removed.inMicroseconds / (_removed + _tileBack).inMicroseconds,
    1,
    curve: IqCurves.easeOut,
  );

  Widget _preview() {
    final video = draft.video!;
    final size = videoSize(video.bytes);
    final (state, meta) = switch (draft.stage) {
      ProofStage.ready => (
        IqVideoPreviewState.ready,
        '$size · uploaded, ready to send',
      ),
      ProofStage.failed ||
      ProofStage.refused => (IqVideoPreviewState.failed, null),
      _ => (
        IqVideoPreviewState.uploading,
        'Uploading… ${(draft.progress * 100).round()}% of $size',
      ),
    };
    final length = video.length;
    return IqVideoPreview(
      key: const ValueKey('preview'),
      state: state,
      name: video.name,
      duration: length == null ? '' : videoLength(length),
      meta: meta,
      progress: draft.progress,
      thumbnail: ProofFrame(source: video.source),
      heroTag: heroTag,
      onPlay: onPlay,
      onRemove: onRemove,
      onRetry: onRetry,
    );
  }

  Widget _tile() => IqProofTile(
    key: const ValueKey('tile'),
    hint:
        "Up to 60 s. End on the Verified screen. Don't show your BVN, PIN or "
        'card number.',
    onTap: onPick,
  );

  @override
  Widget build(BuildContext context) {
    final preview = draft.hasVideo;
    final child = preview ? _preview() : _tile();
    if (MediaQuery.disableAnimationsOf(context)) {
      return StateDissolve(fit: StackFit.passthrough, child: child);
    }
    return AnimatedSize(
      duration: IqDurations.morph,
      curve: IqCurves.easeInOut,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: preview ? IqDurations.morph : _removed + _tileBack,
        reverseDuration: preview ? _removed : IqDurations.morph,
        switchInCurve: preview ? IqCurves.easeOut : _tileIn,
        switchOutCurve: IqCurves.easeOut,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          fit: StackFit.passthrough,
          children: [...previous, ?current],
        ),
        transitionBuilder: _move,
        child: child,
      ),
    );
  }

  /// The polaroid tilts as it fades out; the tile rises as it fades in.
  static Widget _move(Widget child, Animation<double> animation) {
    final preview = child.key == const ValueKey('preview');
    return FadeTransition(
      opacity: animation,
      child: AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) {
          final shown = animation.value;
          final status = animation.status;
          return preview
              ? Transform.rotate(
                  angle: status == AnimationStatus.reverse
                      ? _tilt * (1 - shown)
                      : 0,
                  child: child,
                )
              : Transform.translate(
                  offset: Offset(
                    0,
                    status == AnimationStatus.forward
                        ? IqTravel.rise * (1 - shown)
                        : 0,
                  ),
                  child: child,
                );
        },
      ),
    );
  }
}
