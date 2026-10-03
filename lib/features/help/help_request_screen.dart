import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../data/help_data.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/button.dart';
import '../../ui/confirm_sheet.dart';
import '../../ui/field.dart';
import '../../ui/proof_tile.dart';
import '../../ui/top_bar.dart';
import '../../ui/video_preview.dart';
import '../discover/discover_routes.dart';
import 'help_routes.dart';
import 'help_state.dart';

/// B10 · Help request (141:5818), opened from the proof-submitted screen
/// (B9). What happened goes in the one Field, several lines, up to 1,000
/// characters with a live count; a recording is optional and goes up
/// before it can be sent. Send to support opens the thread in its place,
/// so back from the thread returns to the activation.
///
/// Where the build parts from the frame: the message box is Exp/Field (the
/// one text entry component) where Figma draws a plain frame, so focus
/// shows the accent brush and the label turns primary; the count is the
/// real one (the frame says 112 for an 85 character message); the remove
/// sticker follows the Exp/VideoPreview master (brand, white cross) where
/// the frame's older instance is white with a red cross.
class HelpRequestScreen extends ConsumerStatefulWidget {
  const HelpRequestScreen({super.key, this.subject});

  /// What the request is about; the Kudi Box activation in the demo.
  final String? subject;

  static const int maxLength = 1000;

  @override
  ConsumerState<HelpRequestScreen> createState() => _HelpRequestScreenState();
}

class _HelpRequestScreenState extends ConsumerState<HelpRequestScreen> {
  static final _thousands = NumberFormat('#,##0', 'en');

  final _message = TextEditingController();
  int _shakes = 0;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    final ticket = await ref
        .read(helpDraftProvider.notifier)
        .send(widget.subject ?? DemoHelp.subject);
    if (!mounted) return;
    if (ticket == null) {
      setState(() => _shakes++);
      errorHaptic();
      return;
    }
    IqHaptics.success.play();
    context.pushReplacement(
      helpThreadPath(ticket.id),
      extra: HelpThreadEntry.sent,
    );
  }

  Future<void> _remove() async {
    final remove = await showIqConfirmSheet(
      context,
      body: 'You will need to upload it again to send it.',
    );
    if (remove && mounted) {
      ref.read(helpDraftProvider.notifier).removeRecording();
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(helpDraftProvider);
    final count = _thousands.format(draft.message.characters.length);
    final limit = _thousands.format(HelpRequestScreen.maxLength);

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
                  title: 'Ask for help',
                  onBack: () => leave(context),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      IqSpace.s4,
                      0,
                      IqSpace.s4,
                      IqSpace.s4,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Shake(
                          trigger: _shakes,
                          child: _SendFailed(shown: draft.failed),
                        ),
                        Text(
                          'Support replies within 2 hours.',
                          style: IqText.body.copyWith(color: IqColors.fg2),
                        ),
                        const SizedBox(height: IqSpace.s4),
                        IqField(
                          label: 'What happened?',
                          value: '',
                          controller: _message,
                          minLines: 2,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(
                              HelpRequestScreen.maxLength,
                            ),
                          ],
                          onChanged: ref.read(helpDraftProvider.notifier).write,
                        ),
                        const SizedBox(height: IqSpace.s2),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: RollingText(
                            '$count/$limit characters',
                            style: IqText.small.copyWith(color: IqColors.fg3),
                          ),
                        ),
                        const SizedBox(height: IqSpace.s6),
                        Text(
                          'Recording (optional) · up to 60 s'.toUpperCase(),
                          style: IqText.mono.copyWith(color: IqColors.fg3),
                        ),
                        const SizedBox(height: IqSpace.s4),
                        _Recording(
                          draft: draft,
                          onAdd: ref
                              .read(helpDraftProvider.notifier)
                              .addRecording,
                          onRemove: _remove,
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: IqSpace.s4,
                    vertical: IqSpace.s3,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      IqButton(
                        label: 'Send to support',
                        showIcon: false,
                        width: double.infinity,
                        disabled: !draft.canSend && !draft.sending,
                        loading: draft.sending,
                        onTap: _send,
                      ),
                      const SizedBox(height: IqSpace.s2),
                      Text(
                        'We reply here and by notification.',
                        style: IqText.small.copyWith(color: IqColors.fg3),
                      ),
                    ],
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

/// The optional recording: an Exp/ProofTile to add one, the Exp/VideoPreview
/// while it goes up and once it is ready. The tile morphs into the preview
/// (320 ms, MOTION-SPEC §4.4); a removed preview tilts 3 degrees and fades
/// (200 ms) as the tile comes back. Reduced motion: a crossfade.
class _Recording extends StatelessWidget {
  const _Recording({
    required this.draft,
    required this.onAdd,
    required this.onRemove,
  });

  final HelpDraft draft;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  static const _tile = ValueKey('tile');
  static const _preview = ValueKey('preview');

  @override
  Widget build(BuildContext context) {
    final upload = draft.upload;
    final recording = draft.recording;
    final Widget shown;
    if (upload != null) {
      shown = IqVideoPreview(
        key: _preview,
        state: IqVideoPreviewState.uploading,
        name: upload.file.name,
        progress: upload.progress,
        meta:
            'Uploading… ${(upload.progress * 100).round()}% of '
            '${upload.file.sizeLabel}',
      );
    } else if (recording != null) {
      shown = IqVideoPreview(
        key: _preview,
        name: recording.name,
        duration: recording.lengthLabel,
        meta: '${recording.sizeLabel} · uploaded, ready to send',
        onRemove: onRemove,
      );
    } else {
      shown = IqProofTile(key: _tile, onTap: onAdd);
    }
    final reduced = MediaQuery.disableAnimationsOf(context);
    final switcher = AnimatedSwitcher(
      duration: motion(context, IqDurations.morph, fade: true),
      reverseDuration: motion(context, IqDurations.swap, fade: true),
      switchInCurve: IqCurves.easeOut,
      switchOutCurve: IqCurves.easeOut,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) {
        final removed = child.key == _preview && shown.key == _tile;
        return FadeTransition(
          opacity: animation,
          child: removed && !reduced
              ? RotationTransition(
                  turns: animation.drive(Tween(begin: 3 / 360, end: 0)),
                  child: child,
                )
              : child,
        );
      },
      child: shown,
    );
    // AnimatedSize cannot run at zero duration, so reduced motion goes
    // without it.
    if (reduced) return switcher;
    return AnimatedSize(
      duration: IqDurations.morph,
      curve: IqCurves.easeInOut,
      alignment: Alignment.topCenter,
      child: switcher,
    );
  }
}

/// The error banner over the request when sending did not go through: it
/// opens its slot as it slides down (240 ms) and closes it (180 ms) once
/// the person edits or sends again. Reduced motion: it fades in place.
class _SendFailed extends StatelessWidget {
  const _SendFailed({required this.shown});

  final bool shown;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: motion(context, IqDurations.mark, fade: true),
      reverseDuration: motion(context, IqDurations.ink, fade: true),
      switchInCurve: IqCurves.easeOut,
      switchOutCurve: IqCurves.easeOut,
      transitionBuilder: (child, animation) => reduced
          ? FadeTransition(opacity: animation, child: child)
          : SizeTransition(
              sizeFactor: animation,
              alignment: Alignment.topCenter,
              child: FadeTransition(opacity: animation, child: child),
            ),
      child: shown
          ? const Padding(
              key: ValueKey(true),
              padding: EdgeInsets.only(bottom: IqSpace.s3),
              child: IqBanner(
                kind: IqBannerKind.error,
                title: 'Couldn’t send. Check your connection.',
                showAction: false,
              ),
            )
          : const SizedBox(key: ValueKey(false), width: double.infinity),
    );
  }
}
