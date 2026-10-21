import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

import 'help_data.dart';

/// A voice note recorded on the phone: where it is, how long and how big.
class VoiceNote {
  const VoiceNote({
    required this.path,
    required this.length,
    required this.bytes,
  });

  final String path;
  final Duration length;
  final int bytes;

  /// Under this, a hold was a tap: nothing is sent.
  static const shortest = Duration(seconds: 1);

  /// The note as a file for support (M4A), drawn from the phone while it
  /// goes up and once it is sent.
  HelpAttachment toAttachment() => HelpAttachment(
    name: 'voice-note.m4a',
    bytes: bytes,
    length: length,
    kind: HelpAttachmentKind.audio,
    mime: 'audio/mp4',
    source: Uri.file(path),
    read: () => File(path).readAsBytes(),
  );
}

/// How starting a recording went: [refused] when the microphone is not
/// allowed, [failed] when the phone could not record.
enum VoiceStart { recording, refused, failed }

/// Voice notes from the phone's microphone.
abstract class VoiceRecorder {
  /// Starts recording, asking for the microphone first when it must.
  Future<VoiceStart> start();

  /// Stops: the note, or null when nothing was recorded.
  Future<VoiceNote?> stop();

  /// Stops and throws the recording away.
  Future<void> cancel();
}

/// The phone's microphone (record): AAC in M4A, mono at 64 kbps, so the
/// API's longest note (5 minutes) stays near 2.4 MB, well under its 10 MB.
class DeviceVoiceRecorder implements VoiceRecorder {
  DeviceVoiceRecorder({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  AudioRecorder? _recorder;
  DateTime? _started;

  static const _config = RecordConfig(
    encoder: AudioEncoder.aacLc,
    bitRate: 64000,
    sampleRate: 44100,
    numChannels: 1,
  );

  @override
  Future<VoiceStart> start() async {
    try {
      final recorder = _recorder ??= AudioRecorder();
      if (!await recorder.hasPermission()) return VoiceStart.refused;
      final folder = Directory('${Directory.systemTemp.path}/voice-notes');
      await folder.create(recursive: true);
      await recorder.start(
        _config,
        path: '${folder.path}/${_clock().microsecondsSinceEpoch}.m4a',
      );
      _started = _clock();
      return VoiceStart.recording;
    } on MissingPluginException {
      return VoiceStart.failed;
    } on PlatformException {
      return VoiceStart.failed;
    } on FileSystemException {
      return VoiceStart.failed;
    }
  }

  @override
  Future<VoiceNote?> stop() async {
    final recorder = _recorder;
    final started = _started;
    _started = null;
    if (recorder == null || started == null) return null;
    try {
      final path = await recorder.stop();
      if (path == null) return null;
      final file = File(path.startsWith('file:') ? Uri.parse(path).path : path);
      return VoiceNote(
        path: file.path,
        length: _clock().difference(started),
        bytes: await file.length(),
      );
    } on PlatformException {
      return null;
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<void> cancel() async {
    _started = null;
    try {
      await _recorder?.cancel();
    } on PlatformException {
      return;
    }
  }

  Future<void> dispose() async => _recorder?.dispose();
}

final voiceRecorderProvider = Provider<VoiceRecorder>((ref) {
  final recorder = DeviceVoiceRecorder();
  ref.onDispose(recorder.dispose);
  return recorder;
});
