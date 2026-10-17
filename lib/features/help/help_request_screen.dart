import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/flags.dart';
import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../core/transitions.dart';
import '../../data/activations_data.dart';
import '../../data/help_data.dart';
import '../../data/help_service.dart';
import '../../data/support_files.dart' show SupportSource;
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/button.dart';
import '../../ui/confirm_sheet.dart';
import '../../ui/field.dart';
import '../../ui/icon.dart';
import '../../ui/list_row.dart';
import '../../ui/proof_tile.dart';
import '../../ui/top_bar.dart';
import '../../ui/video_preview.dart';
import '../activations/activations_state.dart';
import '../activations/activations_widgets.dart';
import '../discover/discover_routes.dart';
import '../more/more_widgets.dart' show RowGroup;
import '../settings/restore_account_screen.dart';
import 'help_routes.dart';
import 'help_state.dart';

/// B10 · Help request (141:5818), opened from the proof-submitted screen
/// (B9) about that activation, which names the thread ("Kudi Box
/// activation" in the frame). What happened goes in the one Field, several
/// lines, up to 1,000 characters with a live count; a recording is
/// optional and goes up before it can be sent. Send to support opens the
/// thread in its place, so back from the thread returns to the activation.
///
/// Where the build parts from the frame: the message box is Exp/Field (the
/// one text entry component) where Figma draws a plain frame, so focus
/// shows the accent brush and the label turns primary; the count is the
/// real one (the frame says 112 for an 85 character message); the remove
/// sticker follows the Exp/VideoPreview master (brand, white cross) where
/// the frame's older instance is white with a red cross.
class HelpRequestScreen extends ConsumerStatefulWidget {
  const HelpRequestScreen({super.key, this.about});

  /// The id of the activation the request is about.
  final String? about;

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

  Future<void> _send(Activation? activation) async {
    FocusScope.of(context).unfocus();
    final ticket = await ref
        .read(helpDraftProvider.notifier)
        .send(helpSubject(activation), activation: activation);
    if (!mounted) return;
    if (ticket == null) {
      setState(() => _shakes++);
      errorHaptic();
      if (ref.read(helpDraftProvider).failure == HelpFailure.closing &&
          Flags.deleteAccount) {
        await showClosingAccount(context, ref);
      }
      return;
    }
    IqHaptics.success.play();
    context.pushReplacement(
      helpThreadPath(ticket.id),
      extra: HelpThreadEntry.sent,
    );
  }

  /// A preview picks the frame's recording; on the API the person picks a
  /// picture or a recording from their photos, or a voice note.
  Future<void> _add(Activation? activation) async {
    final notifier = ref.read(helpDraftProvider.notifier);
    if (!ref.read(supportLiveProvider)) {
      notifier.addRecording(about: activation?.business);
      return;
    }
    final source = await _chooseSource(context);
    if (source == null || !mounted) return;
    notifier.addRecording(about: activation?.business, source: source);
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
    final about = widget.about;
    final activation = about == null
        ? null
        : ref.watch(activationProvider(about));
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
                          child: _SendFailed(
                            shown: draft.failed,
                            title: helpFailureText(draft.failure),
                          ),
                        ),
                        Text(
                          DemoHelp.replyLine,
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
                          'Recording (optional) · up to 60 s',
                          style: IqText.label.copyWith(color: IqColors.fg2),
                        ),
                        const SizedBox(height: IqSpace.s4),
                        _Recording(
                          draft: draft,
                          onAdd: () => _add(activation),
                          onRemove: _remove,
                          onRetry: ref
                              .read(helpDraftProvider.notifier)
                              .retryUpload,
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
                        onTap: () => _send(activation),
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
    required this.onRetry,
  });

  final HelpDraft draft;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  static const _tile = ValueKey('tile');
  static const _preview = ValueKey('preview');

  @override
  Widget build(BuildContext context) {
    final upload = draft.upload;
    final recording = draft.recording;
    final unsent = draft.unsent;
    final refused = draft.refused;
    final Widget shown;
    if (unsent != null && upload == null) {
      shown = IqVideoPreview(
        key: _preview,
        state: IqVideoPreviewState.failed,
        name: unsent.name,
        onRetry: onRetry,
        onRemove: onRemove,
      );
    } else if (upload != null) {
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
        duration: recording.lengthLabel ?? '',
        meta: '${recording.sizeLabel} · uploaded, ready to send',
        thumbnail: recording.source == null
            ? null
            : ProofFrame(source: recording.source),
        onRemove: onRemove,
      );
    } else if (refused != null) {
      final words = helpRefusalWords(refused, draft.refusedKind);
      shown = IqProofTile(
        key: _tile,
        state: IqProofTileState.error,
        title: words.title,
        hint: words.title == null ? null : words.hint,
        onTap: onAdd,
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
  const _SendFailed({required this.shown, required this.title});

  final bool shown;
  final String title;

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
          ? Padding(
              key: const ValueKey(true),
              padding: const EdgeInsets.only(bottom: IqSpace.s3),
              child: IqBanner(
                kind: IqBannerKind.error,
                title: title,
                showAction: false,
              ),
            )
          : const SizedBox(key: ValueKey(false), width: double.infinity),
    );
  }
}

/// Photos or a voice note for a help request. No frame draws the choice,
/// so it is the app's own sheet of two rows, as Use a photo's is.
Future<SupportSource?> _chooseSource(BuildContext context) {
  return showIqSheet<SupportSource>(
    context,
    scrim: IqScrim.picker,
    (context) => Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: const BoxDecoration(
          color: IqColors.bg,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(IqConfirmSheet.radius),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          IqSpace.s4,
          IqSpace.s6,
          IqSpace.s4,
          IqSpace.s4 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: RowGroup(
          outlined: true,
          children: [
            IqListRow(
              label: 'Choose from your photos',
              showDescription: false,
              icon: IqIcons.background,
              onTap: () => Navigator.of(context).pop(SupportSource.photos),
            ),
            IqListRow(
              label: 'Choose a voice note',
              showDescription: false,
              icon: IqIcons.headset,
              divider: false,
              onTap: () => Navigator.of(context).pop(SupportSource.voiceNote),
            ),
          ],
        ),
      ),
    ),
  );
}
