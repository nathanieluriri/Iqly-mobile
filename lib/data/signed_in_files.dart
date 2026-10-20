import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

/// Files the API serves only to the signed-in person (what they sent to support
/// or with an entry), downloaded with the session token into a folder of the
/// account's own in the phone's temporary directory, so a player opens them
/// from disk: iOS will not stream a link whose server ignores Range. A file
/// already downloaded is used again; signing out deletes the account's folder.
class SignedInFiles {
  SignedInFiles({required this.api, Directory? root})
    : root = root ?? Directory('${Directory.systemTemp.path}/iqly-files');

  final ApiClient api;
  final Directory root;
  final _fetching = <String, Future<File>>{};

  static String _safe(String value) =>
      value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  Directory _folder(String userId) =>
      Directory('${root.path}/${_safe(userId.isEmpty ? 'session' : userId)}');

  /// The file [id] that [url] serves, named with [name]'s extension, from
  /// the account's folder, downloaded first when it is not there. One
  /// download at a time per file; a failed one leaves nothing behind.
  Future<File> fetch({
    required String userId,
    required String id,
    required String url,
    String name = '',
    void Function(double progress)? onProgress,
  }) {
    final dot = name.lastIndexOf('.');
    final ext = dot < 0 ? '' : _safe(name.substring(dot + 1));
    final file = File(
      '${_folder(userId).path}/${_safe(id)}${ext.isEmpty ? '' : '.$ext'}',
    );
    return _fetching[file.path] ??= _fetch(file, url, onProgress).whenComplete(
      () {
        _fetching.remove(file.path);
      },
    );
  }

  Future<File> _fetch(
    File file,
    String url,
    void Function(double progress)? onProgress,
  ) async {
    if (await file.exists() && await file.length() > 0) {
      onProgress?.call(1);
      return file;
    }
    await file.parent.create(recursive: true);
    final part = File('${file.path}.part');
    try {
      await api.downloadTo(url, part, onProgress: onProgress);
      return await part.rename(file.path);
    } catch (_) {
      if (await part.exists()) await part.delete();
      rethrow;
    }
  }

  /// Deletes what [userId]'s account downloaded.
  Future<void> forget(String userId) async {
    final folder = _folder(userId);
    if (await folder.exists()) await folder.delete(recursive: true);
  }
}

/// Null in the preview build, which has no signed-in files.
final signedInFilesProvider = Provider<SignedInFiles?>((ref) {
  final api = ref.watch(apiClientProvider);
  return api == null ? null : SignedInFiles(api: api);
});

/// How a save to the phone went.
enum FileSave { saved, cancelled, failed }

/// Hands a downloaded file the app cannot show (a PDF) to the phone's own
/// save dialog, so the person keeps it where they can open it.
abstract class FileSaver {
  Future<FileSave> save(
    File file, {
    required String name,
    required String mime,
  });
}

class DeviceFileSaver implements FileSaver {
  const DeviceFileSaver();

  @override
  Future<FileSave> save(
    File file, {
    required String name,
    required String mime,
  }) async {
    try {
      final saved = await FilePicker.saveFile(
        fileName: name,
        bytes: await file.readAsBytes(),
        mimeType: mime,
      );
      return saved == null ? FileSave.cancelled : FileSave.saved;
    } on Exception {
      return FileSave.failed;
    }
  }
}

final fileSaverProvider = Provider<FileSaver>((ref) => const DeviceFileSaver());
