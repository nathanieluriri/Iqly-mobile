import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';
import 'tilt.dart';

/// Opens a player for a recording's [Uri]: a file, an Android content uri
/// or an http link. Tests swap it for a fake.
typedef RecordingOpener = VideoPlayerController Function(Uri source);

VideoPlayerController openRecording(Uri source) => switch (source.scheme) {
  'http' || 'https' => VideoPlayerController.networkUrl(source),
  'content' => VideoPlayerController.contentUri(source),
  _ => VideoPlayerController.file(File(source.toFilePath())),
};

/// Recordings that play in the app. There is no Figma frame for the player:
/// it keeps the Exp/VideoPreview look (ink, the tilted accent sticker) and
/// adds a thread to scrub, the time and a mute switch. The brush set has no
/// pause or sound icons, so those two use Material's rounded glyphs.
abstract final class Recordings {
  static RecordingOpener open = openRecording;

  static final _posters = <Uri, _Poster>{};

  /// A paused player on the first frame, shared by every poster of [source].
  static VideoPlayerController _takePoster(Uri source) {
    final poster = _posters.putIfAbsent(source, () {
      final controller = open(source);
      return _Poster(controller, controller.initialize());
    });
    poster.users++;
    return poster.controller;
  }

  static void _dropPoster(Uri source) {
    final poster = _posters[source];
    if (poster == null || --poster.users > 0) return;
    _posters.remove(source);
    unawaited(poster.ready.whenComplete(poster.controller.dispose));
  }

  @visibleForTesting
  static int get posters => _posters.length;
}

class _Poster {
  _Poster(this.controller, Future<void> ready)
    : ready = ready.catchError((Object _) {});

  final VideoPlayerController controller;
  final Future<void> ready;
  int users = 0;
}

/// Runs [load] once the route that holds [context] has finished arriving,
/// so a recording never decodes under a push or a Hero flight. A route's
/// animation is only wired up after its first frame, so it is read then.
void _whenSettled(BuildContext context, VoidCallback load) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.isCompleted) {
      load();
      return;
    }
    void settled(AnimationStatus status) {
      if (status != AnimationStatus.completed) return;
      animation.removeStatusListener(settled);
      load();
    }

    animation.addStatusListener(settled);
  });
}

/// The video filling its box like a cover photo.
class _Cover extends StatelessWidget {
  const _Cover(this.controller, {this.fit = BoxFit.cover});

  final VideoPlayerController controller;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final size = controller.value.size;
    return ClipRect(
      child: FittedBox(
        fit: fit,
        child: SizedBox(
          width: size.width > 0 ? size.width : 9,
          height: size.height > 0 ? size.height : 16,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}

/// The recording's first frame, cropped to fill its box, over
/// [placeholder] until it loads (or for good when it cannot be read).
class IqRecordingPoster extends StatefulWidget {
  const IqRecordingPoster({
    super.key,
    required this.source,
    required this.placeholder,
  });

  final Uri source;
  final Widget placeholder;

  @override
  State<IqRecordingPoster> createState() => _IqRecordingPosterState();
}

class _IqRecordingPosterState extends State<IqRecordingPoster> {
  Uri? _held;
  VideoPlayerController? _controller;
  bool _asked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_asked) return;
    _asked = true;
    _whenSettled(context, _load);
  }

  @override
  void didUpdateWidget(IqRecordingPoster oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source && _held != null) {
      _release();
      _load();
    }
  }

  void _load() {
    if (!mounted) return;
    final source = widget.source;
    _held = source;
    final controller = Recordings._takePoster(source);
    controller.addListener(_changed);
    setState(() => _controller = controller);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _release() {
    _controller?.removeListener(_changed);
    final held = _held;
    if (held != null) Recordings._dropPoster(held);
    _held = null;
    _controller = null;
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;
    return Stack(
      fit: StackFit.expand,
      children: [widget.placeholder, if (ready) _Cover(controller)],
    );
  }
}

/// The recording playing in place: [placeholder] until it loads, then the
/// paused first frame with the play sticker. A tap plays or pauses; under
/// it, the thread scrubs, the time counts and the sound mutes. It loads
/// once its page has arrived and pauses when the page is covered, left or
/// the app goes to the background.
class IqRecordingPlayer extends StatefulWidget {
  const IqRecordingPlayer({
    super.key,
    required this.source,
    this.placeholder = const SizedBox.shrink(),
  });

  final Uri source;
  final Widget placeholder;

  @override
  State<IqRecordingPlayer> createState() => _IqRecordingPlayerState();
}

class _IqRecordingPlayerState extends State<IqRecordingPlayer>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _asked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ModalRoute.of(context)?.isCurrent == false) _pause();
    if (_asked) return;
    _asked = true;
    _whenSettled(context, _load);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause();
  }

  Future<void> _load() async {
    if (!mounted) return;
    final controller = Recordings.open(widget.source);
    _controller = controller;
    controller.addListener(_changed);
    try {
      await controller.initialize();
    } catch (_) {
      return;
    }
    if (!mounted || _controller != controller) return;
    setState(() => _ready = true);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _pause() {
    final controller = _controller;
    if (_ready && controller != null && controller.value.isPlaying) {
      unawaited(controller.pause());
    }
  }

  void _toggle() {
    final controller = _controller!;
    final value = controller.value;
    if (value.isPlaying) {
      unawaited(controller.pause());
      return;
    }
    if (value.duration > Duration.zero && value.position >= value.duration) {
      unawaited(controller.seekTo(Duration.zero));
    }
    unawaited(controller.play());
  }

  void _mute() {
    final controller = _controller!;
    unawaited(controller.setVolume(controller.value.volume > 0 ? 0 : 1));
  }

  @override
  void deactivate() {
    _pause();
    super.deactivate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final controller = _controller;
    controller?.removeListener(_changed);
    unawaited(controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (!_ready || controller == null) return widget.placeholder;
    final value = controller.value;
    return Material(
      color: IqColors.brand,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: IqPressable(
              tactile: false,
              onTap: _toggle,
              semanticLabel: value.isPlaying ? 'Pause' : 'Play',
              builder: (context, pressed) => Stack(
                fit: StackFit.expand,
                children: [
                  _Cover(controller, fit: BoxFit.contain),
                  AnimatedOpacity(
                    opacity: value.isPlaying ? 0 : 1,
                    duration: motion(context, IqDurations.ink, fade: true),
                    curve: IqCurves.easeOut,
                    child: Center(
                      child: AnimatedScale(
                        scale: pressed ? IqScale.playPress : 1,
                        duration: pressMotion(context, pressed),
                        curve: IqCurves.easeOut,
                        child: const IqTilt(
                          degrees: 4,
                          child: _Sticker(
                            child: IqIcon(
                              IqIcons.play,
                              size: 24,
                              color: IqColors.brand,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _Controls(
            value: value,
            onToggle: _toggle,
            onMute: _mute,
            onSeek: (to) => unawaited(controller.seekTo(to)),
          ),
        ],
      ),
    );
  }
}

class _Sticker extends StatelessWidget {
  const _Sticker({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: 56,
    height: 56,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: IqColors.accent,
      shape: BoxShape.circle,
    ),
    child: child,
  );
}

/// "0:07".
String recordingTime(Duration at) =>
    '${at.inMinutes}:${(at.inSeconds % 60).toString().padLeft(2, '0')}';

class _Controls extends StatelessWidget {
  const _Controls({
    required this.value,
    required this.onToggle,
    required this.onMute,
    required this.onSeek,
  });

  final VideoPlayerValue value;
  final VoidCallback onToggle;
  final VoidCallback onMute;
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context) {
    final total = value.duration.inMilliseconds;
    final at = value.position.inMilliseconds.clamp(0, total);
    final muted = value.volume == 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(IqSpace.s1, 0, IqSpace.s1, IqSpace.s1),
      child: Row(
        children: [
          _Button(
            label: value.isPlaying ? 'Pause' : 'Play',
            onTap: onToggle,
            child: value.isPlaying
                ? const Icon(
                    Icons.pause_rounded,
                    size: 24,
                    color: IqColors.primaryFg,
                  )
                : const IqIcon(
                    IqIcons.play,
                    size: 20,
                    color: IqColors.primaryFg,
                  ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                activeTrackColor: IqColors.accent,
                inactiveTrackColor: IqColors.sidebarAccent,
                thumbColor: IqColors.accent,
                overlayColor: IqColors.accent.withValues(alpha: 0.2),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                value: total == 0 ? 0 : at / total,
                onChanged: total == 0
                    ? null
                    : (share) => onSeek(value.duration * share),
                semanticFormatterCallback: (_) =>
                    '${recordingTime(value.position)} of '
                    '${recordingTime(value.duration)}',
              ),
            ),
          ),
          Text(
            '${recordingTime(value.position)} / '
            '${recordingTime(value.duration)}',
            style: IqText.mono.copyWith(color: IqColors.sidebarFg),
          ),
          _Button(
            label: muted ? 'Sound on' : 'Mute',
            onTap: onMute,
            child: Icon(
              muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              size: 22,
              color: IqColors.primaryFg,
            ),
          ),
        ],
      ),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({
    required this.label,
    required this.onTap,
    required this.child,
  });

  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => IqPressable(
    onTap: onTap,
    semanticLabel: label,
    builder: (context, pressed) => SizedBox(
      width: 44,
      height: 44,
      child: Center(
        child: PressDim(pressed: pressed, child: child),
      ),
    ),
  );
}
