import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/help_data.dart';
import '../../theme/theme.dart';
import '../../ui/chat_media.dart';
import '../../ui/recording_player.dart';
import 'chat_state.dart';

final _bytes = Expando<Future<Uint8List>>();

/// A file the person picked on this phone: drawn from there, never from
/// the API, while it goes up and once it is sent.
bool isLocalFile(HelpAttachment file) =>
    file.source != null || file.read != null;

/// The picked picture [file] at [width] logical pixels, decoded at the
/// screen's density: from its path, else from its bytes.
Widget? localPicture(
  BuildContext context,
  HelpAttachment file, {
  required double width,
  BoxFit fit = BoxFit.cover,
}) {
  final cache = (width * MediaQuery.devicePixelRatioOf(context)).round();
  final source = file.source;
  if (source != null && source.scheme == 'file') {
    return Image.file(
      File(source.toFilePath()),
      fit: fit,
      cacheWidth: cache,
      gaplessPlayback: true,
      errorBuilder: _blank,
    );
  }
  final read = file.read;
  if (read == null) return null;
  final bytes = _bytes[file] ??= read().then(Uint8List.fromList);
  return FutureBuilder<Uint8List>(
    future: bytes,
    builder: (context, got) {
      final data = got.data;
      if (data == null) return const SizedBox.shrink();
      return Image.memory(
        data,
        fit: fit,
        cacheWidth: cache,
        gaplessPlayback: true,
        errorBuilder: _blank,
      );
    },
  );
}

Widget _blank(BuildContext context, Object error, StackTrace? stack) =>
    const ColoredBox(color: IqColors.secondary);

/// A thread's picture in its bubble: the app's sample in the preview, the
/// phone's copy for one the person picked here, or the API's, brought down
/// once with a disc that fills as it comes ([helpFileProvider]) and Try
/// again when it does not. [uploading] is how far a picture on its way up
/// is.
class ChatPicture extends ConsumerWidget {
  const ChatPicture({
    super.key,
    required this.file,
    required this.tone,
    required this.width,
    this.uploading,
    this.onTap,
  });

  final HelpAttachment file;
  final IqChatMediaTone tone;
  final double width;
  final double? uploading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    IqChatMedia media(
      Widget? image, {
      IqChatMediaState state = IqChatMediaState.ready,
      double? progress,
      VoidCallback? onRetry,
    }) => IqChatMedia(
      kind: IqChatMediaKind.image,
      tone: tone,
      width: width,
      image: image,
      state: state,
      progress: progress,
      onTap: onTap,
      onRetry: onRetry,
      semanticLabel: file.name,
    );
    final preview = file.preview;
    if (preview != null) {
      return media(Image.asset(preview, fit: BoxFit.cover));
    }
    if (isLocalFile(file)) {
      final uploading = this.uploading;
      return media(
        localPicture(context, file, width: width),
        state: uploading == null
            ? IqChatMediaState.ready
            : IqChatMediaState.loading,
        progress: uploading,
      );
    }
    final of = HelpFileRef.of(file);
    if (of == null) return media(null);
    final got = ref.watch(helpFileProvider(of));
    final cache = (width * MediaQuery.devicePixelRatioOf(context)).round();
    return switch (got.status) {
      HelpFileStatus.ready => media(
        Image.file(
          got.file!,
          fit: BoxFit.cover,
          cacheWidth: cache,
          gaplessPlayback: true,
          errorBuilder: _blank,
        ),
      ),
      HelpFileStatus.failed => media(
        null,
        state: IqChatMediaState.failed,
        onRetry: () => ref.read(helpFileProvider(of).notifier).fetch(),
      ),
      HelpFileStatus.idle || HelpFileStatus.loading => media(
        null,
        state: IqChatMediaState.loading,
        progress: got.progress,
      ),
    };
  }
}

/// Where a recording plays from on this phone: where it was picked, or the
/// copy already brought down; null until it is.
Uri? playableHere(WidgetRef ref, HelpAttachment file) {
  final source = file.source;
  if (source != null) return source;
  final of = HelpFileRef.of(file);
  if (of == null) return null;
  final got = ref.watch(helpFileProvider(of));
  final kept = got.file;
  return got.status == HelpFileStatus.ready && kept != null
      ? Uri.file(kept.path)
      : null;
}

/// A thread's video in its bubble: its first frame once the phone has the
/// file (picked here, or opened before), else the ink frame, with the play
/// disc and its length; [uploading] while it goes up.
class ChatVideo extends ConsumerWidget {
  const ChatVideo({
    super.key,
    required this.file,
    required this.tone,
    required this.width,
    this.uploading,
    this.onTap,
  });

  final HelpAttachment file;
  final IqChatMediaTone tone;
  final double width;
  final double? uploading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = playableHere(ref, file);
    final uploading = this.uploading;
    return IqChatMedia(
      kind: IqChatMediaKind.video,
      tone: tone,
      width: width,
      state: uploading == null
          ? IqChatMediaState.ready
          : IqChatMediaState.loading,
      progress: uploading,
      image: source == null
          ? null
          : IqRecordingPoster(
              source: source,
              placeholder: const ColoredBox(color: IqColors.brandDark),
            ),
      duration: file.lengthLabel ?? '',
      onTap: onTap,
      semanticLabel: file.name,
    );
  }
}
