import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'help_data.dart';
import 'media_service.dart';

/// Files a person sends to support, from the phone's own picker: the
/// screenshot of a report, and what a help request carries (a picture, a
/// screen recording or a voice note, contract 12.1).
abstract class SupportFiles {
  /// Null when the person backs out.
  Future<HelpAttachment?> pickScreenshot();

  /// Null when the person backs out.
  Future<HelpAttachment?> pickAttachment();
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
  'wav': 'audio/wav',
  'amr': 'audio/amr',
};

/// What [name] is, from its extension, as the API types a part.
({HelpAttachmentKind kind, String mime})? supportTypeOf(String name) {
  final dot = name.lastIndexOf('.');
  final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  if (supportImageTypes[ext] case final mime?) {
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

/// The phone's own picker (file_picker). Without the plugin, as in tests,
/// the screenshot comes from [media] and nothing else can be picked.
class DeviceSupportFiles implements SupportFiles {
  DeviceSupportFiles({MediaService? media})
    : media = media ?? DemoMediaService(access: MediaAccess.allowed);

  final MediaService media;

  @override
  Future<HelpAttachment?> pickScreenshot() => _pick(FileType.image, () async {
    final name = await media.pickImage();
    return name == null
        ? null
        : HelpAttachment(name: name, bytes: 0, kind: HelpAttachmentKind.image);
  });

  /// iOS keeps screen recordings in Photos, which only the media picker
  /// reaches; elsewhere the system picker also offers voice notes.
  @override
  Future<HelpAttachment?> pickAttachment() => _pick(
    defaultTargetPlatform == TargetPlatform.iOS
        ? FileType.media
        : FileType.custom,
    () async => null,
  );

  Future<HelpAttachment?> _pick(
    FileType type,
    Future<HelpAttachment?> Function() fallback,
  ) async {
    try {
      final files = await FilePicker.pickFiles(
        type: type,
        allowedExtensions: type == FileType.custom
            ? [
                ...supportImageTypes.keys,
                ...supportVideoTypes.keys,
                ...supportAudioTypes.keys,
              ]
            : null,
      );
      if (files.isEmpty) return null;
      final file = files.first;
      final known = supportTypeOf(file.name);
      return HelpAttachment(
        name: file.name,
        bytes: file.lengthSync() ?? await file.length() ?? 0,
        kind: known?.kind ?? HelpAttachmentKind.image,
        mime: known?.mime,
        source: file.uri,
        read: file.readAsBytes,
      );
    } on MissingPluginException {
      return fallback();
    } on UnimplementedError {
      return fallback();
    } on PlatformException {
      return null;
    }
  }
}

final supportFilesProvider = Provider<SupportFiles>(
  (ref) => DeviceSupportFiles(media: ref.watch(mediaServiceProvider)),
);
