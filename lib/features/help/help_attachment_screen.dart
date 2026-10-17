import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation.dart';
import '../../core/responsive.dart';
import '../../data/api_client.dart';
import '../../core/session.dart';
import '../../data/help_data.dart';
import '../../data/signed_in_files.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/recording_player.dart';
import '../../ui/top_bar.dart';
import '../../ui/video_preview.dart';
import '../more/more_widgets.dart' show goBack;

/// The session token's headers for a file the person sent to support.
final helpFileHeadersProvider = FutureProvider.autoDispose<Map<String, String>>(
  (ref) async => await ref.watch(apiClientProvider)?.fileHeaders() ?? const {},
);

/// Opens [file] from its thread.
Future<void> openHelpAttachment(BuildContext context, HelpAttachment file) =>
    context.open('${GoRouterState.of(context).uri.path}/file', extra: file);

/// A file sent in a help thread, read with the session token: a picture to
/// pinch and zoom, a recording or a voice note downloaded to the account's
/// folder ([SignedInFiles]) and played from there in the app's player
/// (IqRecordingPlayer), since iOS will not stream it. No Figma frame draws
/// it: the page keeps the proof player's layout under the file's name.
class HelpAttachmentScreen extends ConsumerWidget {
  const HelpAttachmentScreen({super.key, required this.file});

  final HelpAttachment? file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = this.file;
    final api = ref.watch(apiClientProvider);
    final url = file?.url;
    final headers = ref.watch(helpFileHeadersProvider).value;
    final source = url == null || api == null
        ? null
        : api.authorized(url.toString());
    Widget body = const SizedBox.shrink();
    if (file != null && source != null && headers != null) {
      body = ClipRRect(
        borderRadius: BorderRadius.circular(IqRadius.xl2),
        child: file.kind == HelpAttachmentKind.image
            ? ColoredBox(
                color: IqColors.panel,
                child: InteractiveViewer(
                  maxScale: 4,
                  child: Center(
                    child: Image.network(
                      source.toString(),
                      headers: headers,
                      fit: BoxFit.contain,
                      errorBuilder: (context, _, _) => const Align(
                        alignment: Alignment.topCenter,
                        child: IqBanner(
                          kind: IqBannerKind.error,
                          title: 'Couldn’t load. Check your connection.',
                          showAction: false,
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : _Recording(file: file, url: source.toString()),
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

/// Downloads the recording, its progress on the Exp/VideoPreview strip,
/// then plays it from disk; a download that fails offers Try again.
class _Recording extends ConsumerStatefulWidget {
  const _Recording({required this.file, required this.url});

  final HelpAttachment file;
  final String url;

  @override
  ConsumerState<_Recording> createState() => _RecordingState();
}

class _RecordingState extends ConsumerState<_Recording> {
  double _progress = 0;
  File? _downloaded;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _download();
  }

  Future<void> _download() async {
    final files = ref.read(signedInFilesProvider);
    final id = widget.file.id;
    if (files == null || id == null) return;
    setState(() {
      _failed = false;
      _progress = 0;
    });
    try {
      final file = await files.fetch(
        userId: ref.read(sessionProvider).userId ?? '',
        id: id,
        url: widget.url,
        name: widget.file.name,
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
      if (mounted) setState(() => _downloaded = file);
    } on Exception {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final downloaded = _downloaded;
    if (downloaded != null) {
      return IqRecordingPlayer(
        source: Uri.file(downloaded.path),
        placeholder: const ColoredBox(color: IqColors.brand),
      );
    }
    if (_failed) {
      return Align(
        alignment: Alignment.topCenter,
        child: IqBanner(
          kind: IqBannerKind.error,
          title: 'Couldn’t load. Check your connection.',
          action: 'Try again',
          onAction: _download,
        ),
      );
    }
    return Align(
      alignment: Alignment.topCenter,
      child: IqVideoPreview(
        state: IqVideoPreviewState.uploading,
        name: widget.file.name,
        progress: _progress,
        showRemove: false,
        meta:
            'Downloading… ${(_progress * 100).round()}% of '
            '${widget.file.sizeLabel}',
      ),
    );
  }
}
