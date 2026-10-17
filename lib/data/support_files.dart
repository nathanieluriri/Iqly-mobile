import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'help_data.dart';
import 'media_service.dart';

/// Where a help request's file comes from: the phone's photos (a picture
/// or a screen recording) or its voice notes.
enum SupportSource { photos, voiceNote }

/// Files a person sends to support, from the phone's own pickers: the
/// screenshot of a report, and what a help request carries (a picture, a
/// screen recording or a voice note, contract 12.1).
abstract class SupportFiles {
  /// Null when the person backs out.
  Future<HelpAttachment?> pickScreenshot();

  /// Null when the person backs out.
  Future<HelpAttachment?> pickAttachment(SupportSource source);
}

/// The kinds the API takes, by extension.
const supportImageTypes = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'gif': 'image/gif',
};
const supportVideoTypes = {
  'mp4': 'video/mp4',
  'mov': 'video/quicktime',
  'webm': 'video/webm',
  '3gp': 'video/3gpp',
};
const supportAudioTypes = {
  'm4a': 'audio/mp4',
  'aac': 'audio/aac',
  'mp3': 'audio/mpeg',
  'ogg': 'audio/ogg',
  'opus': 'audio/ogg',
  'wav': 'audio/wav',
  'amr': 'audio/amr',
  'webm': 'audio/webm',
  '3gp': 'audio/3gpp',
};

/// HEIC photos the picker could not turn into JPEG: sent as what they are,
/// for the API to decide.
const supportHeicTypes = {'heic': 'image/heic', 'heif': 'image/heif'};

/// What the API takes of each kind (contract 12.1): its size and, for a
/// recording, its length.
abstract final class SupportLimits {
  static int bytes(HelpAttachmentKind kind) => switch (kind) {
    HelpAttachmentKind.image || HelpAttachmentKind.audio => 10 * 1024 * 1024,
    HelpAttachmentKind.video => 50000000,
  };

  static Duration? length(HelpAttachmentKind kind) => switch (kind) {
    HelpAttachmentKind.image => null,
    HelpAttachmentKind.video => const Duration(seconds: 60),
    HelpAttachmentKind.audio => const Duration(minutes: 5),
  };
}

/// What [name] is, from its extension, as the API types a part. A file
/// from the voice notes ([audio]) is a voice note whenever it can be one,
/// so a 3GP or WebM recording without pictures types as audio.
({HelpAttachmentKind kind, String mime})? supportTypeOf(
  String name, {
  bool audio = false,
}) {
  final dot = name.lastIndexOf('.');
  final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  if (audio) {
    if (supportAudioTypes[ext] case final mime?) {
      return (kind: HelpAttachmentKind.audio, mime: mime);
    }
  }
  if (supportImageTypes[ext] ?? supportHeicTypes[ext] case final mime?) {
    return (kind: HelpAttachmentKind.image, mime: mime);
  }
  if (supportVideoTypes[ext] case final mime?) {
    return (kind: HelpAttachmentKind.video, mime: mime);
  }
  if (supportAudioTypes[ext] case final mime?) {
    return (kind: HelpAttachmentKind.audio, mime: mime);
  }
  return null;
}

/// The phone's own pickers (file_picker). Photos come in the iPhone's
/// compatible representation, so a HEIC photo arrives as JPEG; one that
/// still arrives as HEIC is sent as such for the API to decide. Without the
/// plugin, as in tests, the screenshot comes from [media] and nothing else
/// can be picked.
class DeviceSupportFiles implements SupportFiles {
  DeviceSupportFiles({MediaService? media})
    : media = media ?? DemoMediaService(access: MediaAccess.allowed);

  final MediaService media;

  static const _compatible = DarwinOptions(
    assetRepresentationMode: DarwinAssetRepresentationMode.compatible,
  );

  @override
  Future<HelpAttachment?> pickScreenshot() => _guard(
    () async => _attachment(
      (await FilePicker.pickFiles(
        type: FileType.image,
        darwinOptions: _compatible,
      )).firstOrNull,
    ),
    () async {
      final name = await media.pickImage();
      return name == null
          ? null
          : HelpAttachment(
              name: name,
              bytes: 0,
              kind: HelpAttachmentKind.image,
            );
    },
  );

  /// iOS keeps voice notes in Files, which the custom picker reaches; the
  /// audio picker there only offers the music library.
  @override
  Future<HelpAttachment?> pickAttachment(SupportSource source) => _guard(
    () async => switch (source) {
      SupportSource.photos => _attachment(
        (await FilePicker.pickFiles(
          type: FileType.media,
          darwinOptions: _compatible,
        )).firstOrNull,
      ),
      SupportSource.voiceNote => _attachment(
        (await FilePicker.pickFiles(
          type: defaultTargetPlatform == TargetPlatform.iOS
              ? FileType.custom
              : FileType.audio,
          allowedExtensions: defaultTargetPlatform == TargetPlatform.iOS
              ? supportAudioTypes.keys.toList()
              : null,
        )).firstOrNull,
        audio: true,
      ),
    },
    () async => null,
  );

  static Future<HelpAttachment?> _guard(
    Future<HelpAttachment?> Function() pick,
    Future<HelpAttachment?> Function() fallback,
  ) async {
    try {
      return await pick();
    } on MissingPluginException {
      return fallback();
    } on UnimplementedError {
      return fallback();
    } on PlatformException {
      return null;
    }
  }

  static Future<HelpAttachment?> _attachment(
    PlatformFile? file, {
    bool audio = false,
  }) async {
    if (file == null) return null;
    final known = supportTypeOf(file.name, audio: audio);
    return HelpAttachment(
      name: file.name,
      bytes: file.lengthSync() ?? await file.length() ?? 0,
      kind:
          known?.kind ??
          (audio ? HelpAttachmentKind.audio : HelpAttachmentKind.image),
      mime: known?.mime,
      source: file.uri,
      read: file.readAsBytes,
    );
  }
}

final supportFilesProvider = Provider<SupportFiles>(
  (ref) => DeviceSupportFiles(media: ref.watch(mediaServiceProvider)),
);
