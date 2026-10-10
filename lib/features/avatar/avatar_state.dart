import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../../ui/avatar.dart';

/// The person's avatar: what shows ([spec]), the last illustrated person
/// (the editor starts from it, whatever shows) and the saved [photo], first
/// in the picker's Avatars.
@immutable
class AvatarState {
  const AvatarState({required this.spec, required this.look, this.photo});

  final IqAvatarSpec spec;
  final IqAvatarLook look;
  final Uint8List? photo;
}

/// Kept on this phone until the API stores avatars. The sample account is
/// Person 1, as every Figma frame draws Adaeze; a new account starts as a
/// random one of the six people (designer doc, 6 Oct).
class AvatarNotifier extends Notifier<AvatarState> {
  static const _spec = 'avatar.spec';
  static const _look = 'avatar.look';
  static const _photo = 'avatar.photo';

  @override
  AvatarState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    Map<String, Object?>? json(String key) {
      final value = prefs.getString(key);
      if (value == null) return null;
      try {
        return (jsonDecode(value) as Map).cast<String, Object?>();
      } on FormatException {
        return null;
      }
    }

    final photoData = prefs.getString(_photo);
    final photo = photoData == null ? null : base64Decode(photoData);
    final look = switch (json(_look)) {
      final record? => IqAvatarLook.fromJson(record),
      null => null,
    };
    final saved = look ?? IqAvatarPresets.person1;
    final spec = switch (json(_spec)) {
      final record? => IqAvatarSpec.fromJson(record, photo: photo),
      null => null,
    };
    return AvatarState(
      spec: spec ?? IqPersonAvatar(saved),
      look: saved,
      photo: photo,
    );
  }

  /// Shows [spec] from now on. A person also becomes the look the editor
  /// starts from; a photo replaces the saved one.
  Future<void> choose(IqAvatarSpec spec) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final look = spec is IqPersonAvatar ? spec.look : state.look;
    final photo = spec is IqPhotoAvatar ? spec.bytes : state.photo;
    state = AvatarState(spec: spec, look: look, photo: photo);
    await prefs.setString(_spec, jsonEncode(spec.toJson()));
    await prefs.setString(_look, jsonEncode(look.toJson()));
    if (spec is IqPhotoAvatar) {
      await prefs.setString(_photo, base64Encode(spec.bytes));
    }
  }

  /// A new account's avatar: one of the six people, at random.
  Future<void> startNewcomer([Random? random]) {
    final people = IqAvatarPresets.people;
    return choose(
      IqPersonAvatar(people[(random ?? Random()).nextInt(people.length)]),
    );
  }

  /// Forgets the avatar and the saved photo on this phone (sign out).
  Future<void> forget() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(_spec);
    await prefs.remove(_look);
    await prefs.remove(_photo);
    ref.invalidateSelf();
  }
}

final avatarProvider = NotifierProvider<AvatarNotifier, AvatarState>(
  AvatarNotifier.new,
);
