import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../../data/avatar_service.dart';
import '../../ui/avatar.dart';
import '../profile/profile_state.dart';

/// The person's avatar: what shows ([spec]), the last illustrated person
/// (the editor starts from it, whatever shows) and the saved [photo], first
/// in the picker's Avatars. [isDefault] while the person has not picked one.
@immutable
class AvatarState {
  const AvatarState({
    required this.spec,
    required this.look,
    this.photo,
    this.isDefault = false,
  });

  final IqAvatarSpec spec;
  final IqAvatarLook look;
  final Uint8List? photo;
  final bool isDefault;
}

/// The avatar on this phone, and on the account while the avatar runs live
/// (contract 10.1): the account's copy wins once it answers, and a pick
/// queues for it, so the avatar follows the person through a sign out and
/// onto another phone. The sample account is Person 1, as every Figma
/// frame draws Adaeze; a new account starts on the preset the API defaults
/// to for its id and gender.
class AvatarNotifier extends Notifier<AvatarState> {
  static const _spec = 'avatar.spec';
  static const _look = 'avatar.look';
  static const _photo = 'avatar.photo';
  static const _default = 'avatar.default';

  /// Bumped by every local change, so an account answer that left before
  /// one never overwrites it.
  var _changes = 0;

  @override
  AvatarState build() {
    ref.watch(accountProvider);
    final prefs = ref.watch(sharedPreferencesProvider);
    final live = ref.watch(liveAvatarServiceProvider);
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
    final spec = switch (json(_spec)) {
      final record? => IqAvatarSpec.fromJson(record, photo: photo),
      null => null,
    };
    if (live != null) {
      final changes = _changes;
      Future.microtask(() => _pull(live, changes, photo: photo));
    }
    final saved =
        look ??
        (live == null
            ? IqAvatarPresets.person1
            : defaultAvatarLook(_userId, _gender));
    return AvatarState(
      spec: spec ?? IqPersonAvatar(saved),
      look: saved,
      photo: photo,
      isDefault:
          (look == null && spec == null) || (prefs.getBool(_default) ?? false),
    );
  }

  String? get _userId => ref.read(accountProvider);

  /// The gender Your details last kept on this phone.
  String? get _gender {
    final raw = ref
        .read(sharedPreferencesProvider)
        .getString(AccountDetailsNotifier.key);
    if (raw == null) return null;
    try {
      final gender = (jsonDecode(raw) as Map)['gender'];
      return gender is String ? gender : null;
    } on FormatException {
      return null;
    }
  }

  /// The account's avatar replaces what shows. One the account only
  /// defaults while the phone holds the person's own pick takes that pick,
  /// as a pick made before the account kept avatars.
  Future<void> _pull(
    LiveAvatarService live,
    int changes, {
    Uint8List? photo,
  }) async {
    final scope = ref.read(accountScopeProvider);
    if (scope.userId == null) return;
    final AccountAvatar? account;
    try {
      account = await live.avatar(photo: photo);
    } on Object catch (error) {
      debugPrint('Avatar: account copy not read: $error');
      return;
    }
    if (!ref.mounted || !scope.open || changes != _changes) return;
    if (account == null) return;
    final held = state;
    if (account.isDefault && !held.isDefault) {
      await _upload(live, held.spec, held.look);
      return;
    }
    state = AvatarState(
      spec: account.spec,
      look: account.look,
      photo: held.photo,
      isDefault: account.isDefault,
    );
    await _keep(account.spec, account.look, isDefault: account.isDefault);
  }

  Future<void> _upload(
    LiveAvatarService live,
    IqAvatarSpec spec,
    IqAvatarLook look,
  ) async {
    try {
      await live.save(spec, look);
    } on Object catch (error) {
      debugPrint('Avatar: not queued for the account: $error');
    }
  }

  Future<void> _keep(
    IqAvatarSpec spec,
    IqAvatarLook look, {
    bool isDefault = false,
  }) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_spec, jsonEncode(spec.toJson()));
    await prefs.setString(_look, jsonEncode(look.toJson()));
    if (isDefault) {
      await prefs.setBool(_default, true);
    } else {
      await prefs.remove(_default);
    }
    if (spec is IqPhotoAvatar) {
      await prefs.setString(_photo, base64Encode(spec.bytes));
    }
  }

  /// Shows [spec] from now on. A person also becomes the look the editor
  /// starts from; a photo replaces the saved one. A live avatar queues it
  /// for the account.
  Future<void> choose(IqAvatarSpec spec) async {
    _changes++;
    final look = spec is IqPersonAvatar ? spec.look : state.look;
    final photo = spec is IqPhotoAvatar ? spec.bytes : state.photo;
    state = AvatarState(spec: spec, look: look, photo: photo);
    await _keep(spec, look);
    final live = ref.read(liveAvatarServiceProvider);
    if (live != null) await _upload(live, spec, look);
  }

  /// A new account's avatar: the preset the API defaults to for its id and
  /// [gender]. Nothing goes to the account until the person picks.
  Future<void> startNewcomer({String? gender}) async {
    _changes++;
    final look = defaultAvatarLook(_userId, gender ?? _gender);
    state = AvatarState(
      spec: IqPersonAvatar(look),
      look: look,
      isDefault: true,
    );
    await _keep(IqPersonAvatar(look), look, isDefault: true);
  }

  /// A gender is known now: an avatar the person has not picked moves to
  /// the preset the API defaults to for it.
  Future<void> genderKnown(String? gender) async {
    if (!state.isDefault) return;
    final look = defaultAvatarLook(_userId, gender);
    if (state.spec == IqPersonAvatar(look)) return;
    await startNewcomer(gender: gender);
  }

  /// Forgets the avatar and the saved photo on this phone (sign out). The
  /// account keeps its own copy for the next sign-in.
  Future<void> forget() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(_spec);
    await prefs.remove(_look);
    await prefs.remove(_photo);
    await prefs.remove(_default);
    ref.invalidateSelf();
  }
}

final avatarProvider = NotifierProvider<AvatarNotifier, AvatarState>(
  AvatarNotifier.new,
);
