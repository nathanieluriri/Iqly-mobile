import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/backend.dart';
import '../ui/avatar.dart';
import 'api_client.dart';
import 'live/live_account.dart';

/// The presets the API draws a default from (contract 10.1), by gender.
const _femalePresets = [0, 3, 4];
const _malePresets = [1, 2, 5];

/// FNV-1a over the UTF-16 code units, as the API hashes the user id.
int _stableHash(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash;
}

/// The preset the API answers until the person saves an avatar: Person 1,
/// 4 or 5 for `female`, 2, 3 or 6 for `male`, any of the six otherwise, the
/// same for the same id and gender every time.
IqAvatarLook defaultAvatarLook(String? userId, String? gender) {
  final set = switch (gender) {
    'female' => _femalePresets,
    'male' => _malePresets,
    _ => [for (var i = 0; i < IqAvatarPresets.people.length; i++) i],
  };
  return IqAvatarPresets.people[set[_stableHash(userId ?? '') % set.length]];
}

/// The account's avatar as `GET /me/avatar` answers it.
class AccountAvatar {
  const AccountAvatar({
    required this.spec,
    required this.look,
    required this.isDefault,
    this.updatedAt,
    this.photoUrl,
    this.photoShown = false,
  });

  /// [photo] stands in for a photo spec, which the API keeps without its
  /// bytes; without one the look shows.
  static AccountAvatar? fromJson(
    Map<String, dynamic> json, {
    Uint8List? photo,
  }) {
    Map<String, Object?>? map(Object? value) =>
        value is Map ? value.cast<String, Object?>() : null;
    final specJson = map(json['spec']);
    final spec = specJson == null
        ? null
        : IqAvatarSpec.fromJson(specJson, photo: photo);
    final look = switch (map(json['look'])) {
      final record? => IqAvatarLook.fromJson(record),
      null => null,
    };
    final shown = look ?? (spec is IqPersonAvatar ? spec.look : null);
    if (shown == null) return null;
    final url = json['photoUrl'];
    return AccountAvatar(
      spec: spec ?? IqPersonAvatar(shown),
      look: shown,
      isDefault: json['isDefault'] == true,
      updatedAt: DateTime.tryParse('${json['updatedAt']}'),
      photoUrl: url is String && url.isNotEmpty ? url : null,
      photoShown: specJson?['kind'] == 'photo',
    );
  }

  final IqAvatarSpec spec;
  final IqAvatarLook look;
  final bool isDefault;
  final DateTime? updatedAt;

  /// Where the account's own photo is served, owner only (contract 12.4);
  /// it changes with every upload.
  final String? photoUrl;

  /// The account shows its photo, whether or not this phone has it yet.
  final bool photoShown;
}

/// The media type [bytes] are, from their first bytes: the crop is a PNG.
String photoMediaType(Uint8List bytes) {
  bool starts(List<int> magic, [int at = 0]) =>
      bytes.length >= at + magic.length &&
      [for (var i = 0; i < magic.length; i++) bytes[at + i]].join(',') ==
          magic.join(',');
  if (starts(const [0xff, 0xd8, 0xff])) return 'image/jpeg';
  if (starts(const [0x52, 0x49, 0x46, 0x46]) &&
      starts(const [0x57, 0x45, 0x42, 0x50], 8)) {
    return 'image/webp';
  }
  return 'image/png';
}

/// The `PUT /me/avatar` body.
Map<String, Object?> avatarJson(IqAvatarSpec spec, IqAvatarLook look) => {
  'spec': spec.toJson(),
  'look': look.toJson(),
};

/// The avatar on the API (contract 10.1). Reads ask the API and fall back
/// to the copy kept on the phone, with a change still in the outbox laid
/// over it; a change queues like the other profile writes. While [photos]
/// run live (12.4) the person's photo goes up, comes down and is deleted
/// online, with the session token.
class LiveAvatarService {
  const LiveAvatarService(this.link, {this.photos = false});

  final AccountLink link;
  final bool photos;

  /// `PUT /me/avatar/photo`: the photo becomes the avatar. Throws
  /// [ApiUnreachable] or [ApiRefused] when it does not land.
  Future<AccountAvatar?> uploadPhoto(Uint8List bytes) async {
    final res = await link.scope.guard(
      link.api.multipart(
        '/me/avatar/photo',
        method: 'PUT',
        fields: const {},
        files: [
          ApiFile(
            field: 'file',
            filename: 'avatar.${photoMediaType(bytes).split('/').last}',
            bytes: bytes,
            contentType: photoMediaType(bytes),
          ),
        ],
      ),
    );
    if (!res.ok) throw ApiRefused.of(res);
    await link.keep(AccountKeys.avatar, res.data);
    return AccountAvatar.fromJson(res.data, photo: bytes);
  }

  /// `DELETE /me/avatar/photo`: a photo avatar becomes the last person.
  Future<AccountAvatar?> deletePhoto() async {
    final res = await link.scope.guard(link.api.delete('/me/avatar/photo'));
    if (!res.ok) throw ApiRefused.of(res);
    await link.keep(AccountKeys.avatar, res.data);
    return AccountAvatar.fromJson(res.data);
  }

  /// The photo at [url], or null when the API has none to give.
  Future<Uint8List?> photo(String url) async {
    final res = await link.scope.guard(link.api.download(url));
    return res.ok && res.bytes.isNotEmpty ? res.bytes : null;
  }

  Future<AccountAvatar?> avatar({Uint8List? photo}) async => answered(
    await link.fetch('/me/avatar', AccountKeys.avatar),
    photo: photo,
  );

  /// [stored] as an answer of `GET /me/avatar` or the `avatar` of `GET /me`
  /// says it, a change still to go laid over it.
  Future<AccountAvatar?> answered(
    Map<String, dynamic> stored, {
    Uint8List? photo,
  }) async {
    final waiting = await link.waiting(AccountWrite.avatar);
    final json = waiting.isEmpty
        ? stored
        : {...stored, ...waiting.last, 'isDefault': false};
    return AccountAvatar.fromJson(json, photo: photo);
  }

  Future<void> save(IqAvatarSpec spec, IqAvatarLook look) => link.queue(
    AccountWrite.avatar,
    avatarJson(spec, look),
    merge: (older, newer) => newer,
  );
}

/// The avatar's API while it runs live this launch; null in the preview,
/// with the feature off, and while the avatar stays on the phone.
final liveAvatarServiceProvider = Provider<LiveAvatarService?>((ref) {
  final link = ref.watch(liveLinkProvider(LiveFeature.avatar));
  return link == null
      ? null
      : LiveAvatarService(
          link,
          photos: ref.watch(backendProvider).isLive(LiveFeature.avatarPhoto),
        );
});
