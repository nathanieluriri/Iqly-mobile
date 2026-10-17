import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../../data/avatar_service.dart';
import '../../data/live/live_account.dart';
import '../../ui/avatar.dart';
import '../profile/profile_state.dart';

/// The person's avatar: what shows ([spec]), the last illustrated person
/// (the editor starts from it, whatever shows) and the saved [photo], first
/// in the picker's Avatars. [isDefault] while the person has not picked one;
/// not [known] while a live account has not said yet and nothing is kept
/// for it, when a blank circle stands in rather than a guess.
@immutable
class AvatarState {
  const AvatarState({
    required this.spec,
    required this.look,
    this.photo,
    this.isDefault = false,
    this.known = true,
  });

  final IqAvatarSpec spec;
  final IqAvatarLook look;
  final Uint8List? photo;
  final bool isDefault;
  final bool known;
}

/// What shows while the account's avatar is not known yet: a plain circle.
const awaitingAvatar = IqEmojiAvatar('', bg: 1);

/// The avatar, kept on this phone for each account so the same account gets
/// it back after a sign out, and on the account while the avatar runs live
/// (contract 10.1): the account's copy wins once it answers (in `GET /me` or
/// `GET /me/avatar`, asked again when the API is reachable again and on
/// resume until it answers), and a pick queues for it, so it also follows
/// the person onto another phone. The sample account is Person 1, as every
/// Figma frame draws Adaeze; a new account starts on the preset the API
/// defaults to for its id and gender.
class AvatarNotifier extends Notifier<AvatarState> {
  static const _spec = 'avatar.spec';
  static const _look = 'avatar.look';
  static const _photo = 'avatar.photo';
  static const _default = 'avatar.default';

  static String _account(String userId) => 'avatar.account.$userId';
  static String _accountPhoto(String userId) => 'avatar.accountPhoto.$userId';

  /// Bumped by every local change, so an account answer that left before
  /// one never overwrites it.
  var _changes = 0;
  var _synced = false;
  Future<void>? _pulling;

  @override
  AvatarState build() {
    ref.watch(accountProvider);
    final prefs = ref.watch(sharedPreferencesProvider);
    final live = ref.watch(liveAvatarServiceProvider);
    _synced = false;
    _pulling = null;
    final user = _userId;
    Map<String, Object?>? decode(String? value) {
      if (value == null) return null;
      try {
        return (jsonDecode(value) as Map).cast<String, Object?>();
      } on FormatException {
        return null;
      }
    }

    final record =
        (user == null ? null : decode(prefs.getString(_account(user)))) ??
        {
          if (prefs.getString(_spec) case final spec?) 'spec': decode(spec),
          if (prefs.getString(_look) case final look?) 'look': decode(look),
          if (prefs.getBool(_default) == true) 'default': true,
        };
    final photoData =
        (user == null ? null : prefs.getString(_accountPhoto(user))) ??
        prefs.getString(_photo);
    final photo = photoData == null ? null : base64Decode(photoData);
    final look = switch (record['look']) {
      final Map<String, Object?> json => IqAvatarLook.fromJson(json),
      _ => null,
    };
    final spec = switch (record['spec']) {
      final Map<String, Object?> json => IqAvatarSpec.fromJson(
        json,
        photo: photo,
      ),
      _ => null,
    };
    if (live != null) _follow(live);
    final kept = look != null || spec != null;
    final gender = _gender;
    final guess = live != null && !kept && gender == null;
    final saved =
        look ??
        (live == null
            ? IqAvatarPresets.person1
            : defaultAvatarLook(user, gender));
    return AvatarState(
      spec: guess ? awaitingAvatar : spec ?? IqPersonAvatar(saved),
      look: saved,
      photo: photo,
      isDefault: !kept || record['default'] == true,
      known: !guess,
    );
  }

  /// Takes the account's avatar from `GET /me`, and asks `GET /me/avatar`
  /// now, whenever the API is reachable again and on resume, until one
  /// answers.
  void _follow(LiveAvatarService live) {
    ref.listen(meProvider, (_, next) {
      final avatar = next.value?.avatar;
      if (avatar != null) unawaited(_take(live, avatar));
    });
    final back = live.link.api.reachable.listen((_) => _retry(live));
    final resumes = AppLifecycleListener(onResume: () => _retry(live));
    ref.onDispose(() {
      back.cancel();
      resumes.dispose();
    });
    Future.microtask(() => _retry(live));
  }

  void _retry(LiveAvatarService live) {
    if (_synced || !ref.mounted) return;
    _pulling ??= _pull(live).whenComplete(() => _pulling = null);
  }

  Future<void> _pull(LiveAvatarService live) async {
    final scope = ref.read(accountScopeProvider);
    if (scope.userId == null) return;
    final changes = _changes;
    final AccountAvatar? account;
    try {
      account = await scope.guard(live.avatar(photo: state.photo));
    } on Object catch (error) {
      debugPrint('Avatar: account copy not read: $error');
      return;
    }
    if (!ref.mounted || !scope.open || changes != _changes) return;
    await _apply(live, account);
  }

  Future<void> _take(LiveAvatarService live, Map<String, dynamic> json) async {
    final scope = ref.read(accountScopeProvider);
    final changes = _changes;
    final account = await live.answered(json, photo: state.photo);
    if (!ref.mounted || !scope.open || changes != _changes) return;
    await _apply(live, account);
  }

  /// One the account only defaults while the phone holds the person's own
  /// pick takes that pick, as a pick made before the account kept avatars.
  Future<void> _apply(LiveAvatarService live, AccountAvatar? account) async {
    if (account == null) return;
    _synced = true;
    final held = state;
    if (account.isDefault && held.known && !held.isDefault) {
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

  String? get _userId => switch (ref.read(accountProvider)) {
    final id? when id.isNotEmpty => id,
    _ => null,
  };

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

  /// Kept under the account's id, and as the phone's current avatar.
  Future<void> _keep(
    IqAvatarSpec spec,
    IqAvatarLook look, {
    bool isDefault = false,
  }) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final user = _userId;
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
    if (user == null) return;
    await prefs.setString(
      _account(user),
      jsonEncode({
        'spec': spec.toJson(),
        'look': look.toJson(),
        if (isDefault) 'default': true,
      }),
    );
    if (spec is IqPhotoAvatar) {
      await prefs.setString(_accountPhoto(user), base64Encode(spec.bytes));
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
    if (state.known && state.spec == IqPersonAvatar(look)) return;
    await startNewcomer(gender: gender);
  }

  /// Sign out: the phone's current avatar goes, but each account's own
  /// stays for its next sign-in, here or (while live) on the account.
  Future<void> forget() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(_spec);
    await prefs.remove(_look);
    await prefs.remove(_photo);
    await prefs.remove(_default);
    ref.invalidateSelf();
  }

  /// Forgets [userId]'s avatar on this phone for good (the Live or Preview
  /// switch, a closed account).
  Future<void> wipe(String userId) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(_account(userId));
    await prefs.remove(_accountPhoto(userId));
    ref.invalidateSelf();
  }
}

final avatarProvider = NotifierProvider<AvatarNotifier, AvatarState>(
  AvatarNotifier.new,
);
