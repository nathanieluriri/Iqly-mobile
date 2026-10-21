import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation.dart';
import '../../core/responsive.dart';
import '../../data/help_data.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/chat_media.dart';
import '../../ui/recording_player.dart';
import '../../ui/top_bar.dart';
import '../../ui/video_preview.dart';
import '../more/more_widgets.dart' show goBack;
import 'chat_files.dart';
import 'chat_state.dart';

/// Opens [file] from its thread.
Future<void> openHelpAttachment(BuildContext context, HelpAttachment file) =>
    context.open('${GoRouterState.of(context).uri.path}/file', extra: file);

/// A file sent in a help thread, read with the session token: a picture to
/// pinch and zoom, a recording or a voice note downloaded to the account's
/// folder ([SignedInFiles]) and played from there in the app's player
/// (IqRecordingPlayer), since iOS will not stream it. The thread's bubble
/// and this page share the download ([helpFileProvider]): a picture shows
/// its progress, Try again when it did not come, and opens at once once it
/// has; a file the person picked on this phone opens from there. No Figma
/// frame draws it: the page keeps the proof player's layout under the
/// file's name.
class HelpAttachmentScreen extends ConsumerWidget {
  const HelpAttachmentScreen({super.key, required this.file});

  final HelpAttachment? file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = this.file;
    Widget body = const SizedBox.shrink();
    if (file != null) {
      body = ClipRRect(
        borderRadius: BorderRadius.circular(IqRadius.xl2),
        child: file.kind == HelpAttachmentKind.image
            ? ColoredBox(
                color: IqColors.panel,
                child: _Picture(file: file),
              )
            : _Recording(file: file),
      );
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
                  title: file?.name ?? '',
                  onBack: () => goBack(context),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      IqSpace.s4,
                      0,
                      IqSpace.s4,
                      IqSpace.s4,
                    ),
                    child: body,
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

/// The picture to pinch and zoom, once it is on the phone.
class _Picture extends ConsumerWidget {
  const _Picture({required this.file});

  final HelpAttachment file;

  Widget _zoom(Widget image) =>
      InteractiveViewer(maxScale: 4, child: Center(child: image));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = file.preview;
    if (preview != null) {
      return _zoom(Image.asset(preview, fit: BoxFit.contain));
    }
    final width = MediaQuery.sizeOf(context).width;
    if (isLocalFile(file)) {
      return _zoom(
        localPicture(context, file, width: width, fit: BoxFit.contain) ??
            const SizedBox.shrink(),
      );
    }
    final of = HelpFileRef.of(file);
    final got = of == null
        ? const HelpFileState(status: HelpFileStatus.failed)
        : ref.watch(helpFileProvider(of));
    return switch (got.status) {
      HelpFileStatus.ready => _zoom(
        Image.file(
          got.file!,
          fit: BoxFit.contain,
          cacheWidth: (width * MediaQuery.devicePixelRatioOf(context) * 2)
              .round(),
          errorBuilder: (context, _, _) => const _Failed(),
        ),
      ),
      HelpFileStatus.failed => _Failed(
        onRetry: of == null
            ? null
            : () => ref.read(helpFileProvider(of).notifier).fetch(),
      ),
      HelpFileStatus.idle || HelpFileStatus.loading => Center(
        child: IqChatMedia(
          kind: IqChatMediaKind.image,
          state: IqChatMediaState.loading,
          progress: got.progress,
          image: const ColoredBox(color: IqColors.panel),
        ),
      ),
    };
  }
}

class _Failed extends StatelessWidget {
  const _Failed({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      IqBanner(
        kind: IqBannerKind.error,
        title: 'Couldn’t load. Check your connection.',
        action: 'Try again',
        showAction: onRetry != null,
        onAction: onRetry,
      ),
    ],
  );
}

/// The recording from the phone when it was picked here, else downloaded
/// once, its progress on the Exp/VideoPreview strip, then played from
/// disk; a download that fails offers Try again.
class _Recording extends ConsumerStatefulWidget {
  const _Recording({required this.file});

  final HelpAttachment file;

  @override
  ConsumerState<_Recording> createState() => _RecordingState();
}

class _RecordingState extends ConsumerState<_Recording> {
  HelpFileRef? get _of =>
      widget.file.source == null ? HelpFileRef.of(widget.file) : null;

  @override
  void initState() {
    super.initState();
    final of = _of;
    if (of != null) {
      Future.microtask(() {
        if (mounted) ref.read(helpFileProvider(of).notifier).fetch();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.file.source;
    if (source != null) {
      return IqRecordingPlayer(
        source: source,
        placeholder: const ColoredBox(color: IqColors.brand),
      );
    }
    final of = _of;
    if (of == null) return const _Failed();
    final got = ref.watch(helpFileProvider(of));
    final file = got.file;
    if (got.status == HelpFileStatus.ready && file != null) {
      return IqRecordingPlayer(
        source: Uri.file(file.path),
        placeholder: const ColoredBox(color: IqColors.brand),
      );
    }
    if (got.status == HelpFileStatus.failed) {
      return _Failed(
        onRetry: () =>
            unawaited(ref.read(helpFileProvider(of).notifier).fetch()),
      );
    }
    final progress = got.progress ?? 0;
    return Align(
      alignment: Alignment.topCenter,
      child: IqVideoPreview(
        state: IqVideoPreviewState.uploading,
        name: widget.file.name,
        progress: progress,
        showRemove: false,
        meta:
            'Downloading… ${(progress * 100).round()}% of '
            '${widget.file.sizeLabel}',
      ),
    );
  }
}
