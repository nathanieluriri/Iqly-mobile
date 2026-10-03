import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../data/activations_data.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/button.dart';
import '../../ui/confirm_sheet.dart';
import '../../ui/field.dart';
import '../../ui/proof_tile.dart';
import '../../ui/top_bar.dart';
import '../../ui/video_preview.dart';
import 'activation_format.dart';
import 'activations_routes.dart';
import 'activations_state.dart';
import 'activations_widgets.dart';

/// B9 · Proof · empty (141:5210), ready (141:5372) and remove recording?
/// (141:5492), with the kit's states between them: uploading and upload
/// failed (Exp/VideoPreview), and a recording over 60 s (Exp/ProofTile
/// Error, with the error haptic).
///
/// The empty tile breathes and holds the screen's pulse. A pick flashes
/// the tile accent-soft, then the tile morphs into the polaroid (320 ms
/// ease-in-out, contents crossfading, MOTION-SPEC §4.4): the thread fills
/// as it uploads and the play sticker pops when it is ready; play opens the
/// player with the frame flying in. Remove asks first on the frame's
/// brand-dark scrim; Remove recording tilts the polaroid 3° as it fades
/// (200) while the sheet drops, then the tile appears (220). Send proof is
/// Secondary until a recording is ready (tapped early, the tile shakes with
/// the error haptic), then Primary; once sent, the success haptic and back
/// to the activation, which now reads Your proof. Reduced motion: the tile
/// and the polaroid crossfade in place (150), nothing tilts or rises.
///
/// Figma over this build: 141:5492 labels the first field "Kudi Box
/// reference (optional)"; the build keeps the phone number of the empty
/// and ready frames. The textarea frame is drawn with Exp/Field, the one
/// text entry component.
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
  bool _failed = false;

  /// 141:5492 dims the screen with brand-dark at 50%, not the brand of the
  /// other sheets.
  static final _scrim = IqColors.brandDark.withValues(
    alpha: IqOpacity.sheetScrim,
  );

  ProofDraftNotifier get _draft =>
      ref.read(proofDraftProvider(widget.id).notifier);

  @override
  void dispose() {
    _phone.dispose();
    _note.dispose();
    super.dispose();
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
    final step = activation.waitingStep;
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
      _failed = false;
    });
    try {
      await ref
          .read(activationsProvider.notifier)
          .sendProof(
            activation.id,
            step: step,
            uploadId: uploadId,
            video: video,
            phone: _phone.text.trim(),
            note: _note.text.trim(),
          );
    } on Object {
      if (!mounted) return;
      errorHaptic();
      setState(() {
        _sending = false;
        _failed = true;
      });
      return;
    }
    if (!mounted) return;
    IqHaptics.success.play();
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(proofDraftProvider(widget.id), (previous, next) {
      if (next.stage == ProofStage.tooLong &&
          previous?.stage != ProofStage.tooLong) {
        errorHaptic();
      }
    });
    final activation = ref.watch(activationProvider(widget.id));
    final draft = ref.watch(proofDraftProvider(widget.id));
    final step = (activation?.waitingStep ?? activation?.confirmed ?? 0) + 1;
    final ready = draft.stage == ProofStage.ready;
    final busy =
        draft.stage == ProofStage.uploading || draft.stage == ProofStage.failed;

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
                  child: activation == null
                      ? const SizedBox.shrink()
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(
                            IqSpace.s4,
                            0,
                            IqSpace.s4,
                            IqSpace.s4,
                          ),
                          children: [
                            if (_failed) ...[
                              IqBanner(
                                kind: IqBannerKind.error,
                                title: 'Couldn’t send. Check your connection.',
                                action: 'Try again',
                                onAction: () => _send(activation, draft),
                              ),
                              const SizedBox(height: IqSpace.s3),
                            ],
                            Text(
                              'Record step $step. iQLY checks it, then pays '
                              '${reward(activation)}.',
                              style: IqText.body.copyWith(color: IqColors.fg2),
                            ),
                            const SizedBox(height: IqSpace.s4),
                            Eyebrow(
                              'Proof of step $step · up to '
                              '${ActivationRules.proofLength.inSeconds} seconds',
                            ),
                            const SizedBox(height: IqSpace.s4),
                            Shake(
                              trigger: _shakes,
                              child: _ProofSlot(
                                draft: draft,
                                heroTag: proofHeroTag(activation.id),
                                onPick: _draft.pick,
                                onRetry: _draft.retry,
                                onRemove: _remove,
                                onPlay: () => context.push(
                                  proofPlayerPath(activation.id),
                                ),
                              ),
                            ),
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
                ActionBar(
                  children: [
                    IqButton(
                      label: 'Send proof',
                      kind: ready
                          ? IqButtonKind.primary
                          : IqButtonKind.secondary,
                      showIcon: false,
                      width: double.infinity,
                      loading: _sending,
                      onTap: activation == null || busy
                          ? null
                          : () => _send(activation, draft),
                    ),
                    Text(
                      'You did these steps yourself.',
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
      ProofStage.failed => (IqVideoPreviewState.failed, null),
      _ => (
        IqVideoPreviewState.uploading,
        'Uploading… ${(draft.progress * 100).round()}% of $size',
      ),
    };
    return IqVideoPreview(
      key: const ValueKey('preview'),
      state: state,
      name: video.name,
      meta: meta,
      progress: draft.progress,
      thumbnail: Hero(tag: heroTag, child: const ProofFrame()),
      onPlay: onPlay,
      onRemove: onRemove,
      onRetry: onRetry,
    );
  }

  Widget _tile() => IqProofTile(
    key: const ValueKey('tile'),
    state: draft.stage == ProofStage.tooLong
        ? IqProofTileState.error
        : IqProofTileState.empty,
    hint: draft.stage == ProofStage.tooLong
        ? null
        : 'Up to 60 s. Show the result.',
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
