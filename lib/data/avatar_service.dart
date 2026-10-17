import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/backend.dart';
import '../ui/avatar.dart';
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
    return AccountAvatar(
      spec: spec ?? IqPersonAvatar(shown),
      look: shown,
      isDefault: json['isDefault'] == true,
    );
  }

  final IqAvatarSpec spec;
  final IqAvatarLook look;
  final bool isDefault;
}

/// The `PUT /me/avatar` body.
Map<String, Object?> avatarJson(IqAvatarSpec spec, IqAvatarLook look) => {
  'spec': spec.toJson(),
  'look': look.toJson(),
};

/// The avatar on the API (contract 10.1). Reads ask the API and fall back
/// to the copy kept on the phone, with a change still in the outbox laid
/// over it; a change queues like the other profile writes.
class LiveAvatarService {
  const LiveAvatarService(this.link);

  final AccountLink link;

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
  return link == null ? null : LiveAvatarService(link);
});
