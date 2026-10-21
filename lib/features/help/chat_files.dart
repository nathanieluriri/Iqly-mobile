import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../data/help_data.dart';
import '../../data/signed_in_files.dart';
import '../../data/support_files.dart' show supportDocumentTypes;
import '../../theme/theme.dart';
import '../../ui/chat_media.dart';
import '../../ui/icon.dart';
import '../../ui/recording_player.dart';
import '../../ui/toast.dart';
import 'chat_state.dart';

final _bytes = Expando<Future<Uint8List>>();

/// [image] decoded just big enough to cover [size] (physical pixels)
/// whatever its shape, as BoxFit.cover draws it: a decode by width alone
/// leaves a wide picture too short for its frame, and blurry.
class CoverImage extends ImageProvider<CoverImageKey> {
  const CoverImage(this.image, this.size);

  final ImageProvider<Object> image;
  final Size size;

  /// A picture for a [width] by [height] frame on this screen.
  static CoverImage of(
    BuildContext context,
    ImageProvider<Object> image, {
    required double width,
    required double height,
  }) {
    final ratio = MediaQuery.devicePixelRatioOf(context);
    return CoverImage(image, Size(width * ratio, height * ratio));
  }

  @override
  Future<CoverImageKey> obtainKey(ImageConfiguration configuration) {
    Completer<CoverImageKey>? completer;
    SynchronousFuture<CoverImageKey>? result;
    image.obtainKey(configuration).then((key) {
      final cover = CoverImageKey(key, size);
      if (completer == null) {
        result = SynchronousFuture(cover);
      } else {
        completer.complete(cover);
      }
    });
    final now = result;
    if (now != null) return now;
    completer = Completer<CoverImageKey>();
    return completer.future;
  }

  @override
  ImageStreamCompleter loadImage(
    CoverImageKey key,
    ImageDecoderCallback decode,
  ) {
    Future<ui.Codec> cover(
      ui.ImmutableBuffer buffer, {
      ui.TargetImageSizeCallback? getTargetSize,
    }) => decode(
      buffer,
      getTargetSize: (width, height) => coverSize(size, width, height),
    );
    return image.loadImage(key.image, cover);
  }

  /// The smallest size of a [width] by [height] picture that covers [box],
  /// never larger than the picture.
  static ui.TargetImageSize coverSize(Size box, int width, int height) {
    final scale = math.max(box.width / width, box.height / height);
    if (scale >= 1) return const ui.TargetImageSize();
    return ui.TargetImageSize(
      width: (width * scale).ceil(),
      height: (height * scale).ceil(),
    );
  }
}

@immutable
class CoverImageKey {
  const CoverImageKey(this.image, this.size);

  final Object image;
  final Size size;

  @override
  bool operator ==(Object other) =>
      other is CoverImageKey && other.image == image && other.size == size;

  @override
  int get hashCode => Object.hash(image, size);
}

/// A file the person picked on this phone: drawn from there, never from
/// the API, while it goes up and once it is sent.
bool isLocalFile(HelpAttachment file) =>
    file.source != null || file.read != null;

/// The picked picture [file] for a [width] by [height] frame: from its
/// path, else from its bytes.
Widget? localPicture(
  BuildContext context,
  HelpAttachment file, {
  required double width,
  required double height,
  BoxFit fit = BoxFit.cover,
}) {
  ImageProvider<Object> sized(ImageProvider<Object> image) =>
      CoverImage.of(context, image, width: width, height: height);
  final source = file.source;
  if (source != null && source.scheme == 'file') {
    return Image(
      image: sized(FileImage(File(source.toFilePath()))),
      fit: fit,
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
      return Image(
        image: sized(MemoryImage(data)),
        fit: fit,
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
        localPicture(
          context,
          file,
          width: width,
          height: IqChatMedia.frameHeight,
        ),
        state: uploading == null
            ? IqChatMediaState.ready
            : IqChatMediaState.loading,
        progress: uploading,
      );
    }
    final of = HelpFileRef.of(file);
    if (of == null) return media(null);
    final got = ref.watch(helpFileProvider(of));
    return switch (got.status) {
      HelpFileStatus.ready => media(
        Image(
          image: CoverImage.of(
            context,
            FileImage(got.file!),
            width: width,
            height: IqChatMedia.frameHeight,
          ),
          fit: BoxFit.cover,
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

/// A document in its bubble: its name and facts ("PDF · 64 KB"). A tap
/// brings it down once with the session token, its progress in the facts,
/// then hands it to the phone's save dialog, as a submission's PDF is; one
/// picked on this phone is saved from there.
class ChatDocument extends ConsumerStatefulWidget {
  const ChatDocument({
    super.key,
    required this.file,
    required this.tone,
    required this.facts,
  });

  final HelpAttachment file;
  final IqChatMediaTone tone;
  final String facts;

  @override
  ConsumerState<ChatDocument> createState() => _ChatDocumentState();
}

class _ChatDocumentState extends ConsumerState<ChatDocument> {
  bool _wanted = false;

  HelpFileRef? get _of =>
      widget.file.source == null ? HelpFileRef.of(widget.file) : null;

  Future<void> _save(File file) async {
    _wanted = false;
    final name = widget.file.name;
    final dot = name.lastIndexOf('.');
    final mime =
        supportDocumentTypes[dot < 0
            ? ''
            : name.substring(dot + 1).toLowerCase()] ??
        widget.file.mime ??
        'application/octet-stream';
    final saved = await ref
        .read(fileSaverProvider)
        .save(file, name: name, mime: mime);
    if (!mounted) return;
    switch (saved) {
      case FileSave.saved:
        IqToast.show(context, 'Document saved');
      case FileSave.failed:
        IqToast.show(
          context,
          'Document not saved. Try again.',
          kind: IqToastKind.error,
        );
      case FileSave.cancelled:
        break;
    }
  }

  Future<void> _tap() async {
    final source = widget.file.source;
    if (source != null && source.scheme == 'file') {
      return _save(File(source.toFilePath()));
    }
    final of = _of;
    if (of == null) return;
    final got = ref.read(helpFileProvider(of));
    final kept = got.file;
    if (got.status == HelpFileStatus.ready && kept != null) return _save(kept);
    setState(() => _wanted = true);
    await ref.read(helpFileProvider(of).notifier).fetch();
  }

  @override
  Widget build(BuildContext context) {
    final of = _of;
    final got = of == null ? null : ref.watch(helpFileProvider(of));
    final kept = got?.file;
    if (_wanted && got?.status == HelpFileStatus.ready && kept != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _wanted) _save(kept);
      });
    }
    final loading = _wanted && got?.status == HelpFileStatus.loading;
    final failed = _wanted && got?.status == HelpFileStatus.failed;
    final progress = got?.progress;
    final local = widget.file.source?.scheme == 'file';
    return IqChatMedia(
      kind: IqChatMediaKind.file,
      tone: widget.tone,
      width: 282,
      name: widget.file.name,
      fileIcon: IqIcons.document,
      meta: failed
          ? 'Couldn’t download. Tap to try again.'
          : loading
          ? 'Downloading… ${((progress ?? 0) * 100).round()}%'
          : widget.facts,
      onTap: of == null && !local ? null : _tap,
      semanticLabel: widget.file.name,
    );
  }
}

/// A voice note in its bubble, played in place with the app's player (the
/// sound of video_player): from the phone when it was recorded or picked
/// here, else brought down once on its first play. One plays at a time.
/// The bars fill as it plays and the time counts up, then it goes back to
/// its start and its length. [uploading] while it goes up.
class ChatVoiceNote extends ConsumerStatefulWidget {
  const ChatVoiceNote({
    super.key,
    required this.file,
    required this.tone,
    this.uploading,
  });

  final HelpAttachment file;
  final IqChatMediaTone tone;
  final double? uploading;

  /// Pauses the note playing, if one is: recording starts with it.
  static void pauseAll() => _ChatVoiceNoteState._playing?._player?.pause();

  @override
  ConsumerState<ChatVoiceNote> createState() => _ChatVoiceNoteState();
}

class _ChatVoiceNoteState extends ConsumerState<ChatVoiceNote> {
  static _ChatVoiceNoteState? _playing;

  VideoPlayerController? _player;

  /// Play once the file is on the phone.
  bool _wanted = false;
  bool _failed = false;

  HelpFileRef? get _of =>
      widget.file.source == null ? HelpFileRef.of(widget.file) : null;

  @override
  void dispose() {
    if (identical(_playing, this)) _playing = null;
    _release();
    super.dispose();
  }

  void _release() {
    final player = _player;
    _player = null;
    player?.removeListener(_changed);
    player?.dispose();
  }

  void _changed() {
    final player = _player;
    if (!mounted || player == null) return;
    final value = player.value;
    if (value.isInitialized &&
        !value.isPlaying &&
        value.duration > Duration.zero &&
        value.position >= value.duration) {
      player.seekTo(Duration.zero);
    }
    setState(() {});
  }

  void _takeOver() {
    final other = _playing;
    if (other != null && !identical(other, this)) other._player?.pause();
    _playing = this;
  }

  Future<void> _toggle() async {
    final player = _player;
    if (player != null) {
      if (player.value.isPlaying) {
        await player.pause();
      } else if (player.value.isInitialized) {
        _takeOver();
        await player.play();
      }
      return;
    }
    final source = widget.file.source;
    if (source != null) return _open(source);
    final of = _of;
    if (of == null) return;
    setState(() {
      _wanted = true;
      _failed = false;
    });
    await ref.read(helpFileProvider(of).notifier).fetch();
  }

  Future<void> _open(Uri source) async {
    _wanted = false;
    final player = Recordings.open(source);
    setState(() {
      _failed = false;
      _player = player..addListener(_changed);
    });
    try {
      await player.initialize();
    } on Object {
      if (!mounted || !identical(_player, player)) return;
      _release();
      setState(() => _failed = true);
      return;
    }
    if (!mounted || !identical(_player, player)) return;
    _takeOver();
    await player.play();
  }

  @override
  Widget build(BuildContext context) {
    final file = widget.file;
    final of = _of;
    final got = of == null ? null : ref.watch(helpFileProvider(of));
    final kept = got?.file;
    if (_wanted && got?.status == HelpFileStatus.ready && kept != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _wanted && _player == null) _open(Uri.file(kept.path));
      });
    }
    final value = _player?.value;
    final ready = value != null && value.isInitialized;
    final length = ready && value.duration > Duration.zero
        ? value.duration
        : file.length;
    final position = ready ? value.position : Duration.zero;
    final playing = ready && value.isPlaying;
    final loading =
        widget.uploading != null ||
        (_player != null && !ready) ||
        (_wanted && got?.status != HelpFileStatus.failed);
    final failed = _failed || (_wanted && got?.status == HelpFileStatus.failed);
    final total = length?.inMilliseconds ?? 0;
    final fraction = total == 0
        ? 0.0
        : (position.inMilliseconds / total).clamp(0.0, 1.0);
    final shown = playing || position > Duration.zero ? position : length;
    return IqChatMedia(
      kind: IqChatMediaKind.voice,
      tone: widget.tone,
      state: failed
          ? IqChatMediaState.failed
          : loading
          ? IqChatMediaState.loading
          : IqChatMediaState.ready,
      playing: playing,
      played: (IqChatMedia.bars.length * fraction).round(),
      duration: shown == null ? '' : helpLength(shown),
      onTap: widget.uploading == null ? _toggle : null,
      onRetry: _toggle,
      semanticLabel: playing ? 'Pause' : 'Play voice note',
    );
  }
}
