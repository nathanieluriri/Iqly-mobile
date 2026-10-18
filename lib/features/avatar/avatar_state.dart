import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/deadline.dart';
import '../../core/session.dart';
import '../../data/api_client.dart';
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
    this.pickedAt,
  });

  final IqAvatarSpec spec;
  final IqAvatarLook look;
  final Uint8List? photo;
  final bool isDefault;
  final bool known;

  /// When the person picked it, or when the account last saved it.
  final DateTime? pickedAt;
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

  /// Where the account serves the photo kept for it, once the two match.
  static String _photoUrl(String userId) => 'avatar.photoUrl.$userId';

  /// Set while the photo picked on this phone still has to go up.
  static String _photoPending(String userId) => 'avatar.photoPending.$userId';

  /// Bumped by every local change, so an account answer that left before
  /// one never overwrites it.
  var _changes = 0;
  var _synced = false;
  Future<void>? _pulling;
  Future<void>? _pushing;

  @override
  AvatarState build() {
    ref.watch(accountProvider);
    final prefs = ref.watch(sharedPreferencesProvider);
    final live = ref.watch(liveAvatarServiceProvider);
    _synced = false;
    _pulling = null;
    _pushing = null;
    final user = _userId;
    Map<String, Object?>? decode(String? value) {
      if (value == null) return null;
      try {
        return (jsonDecode(value) as Map).cast<String, Object?>();
      } on FormatException {
        return null;
      }
    }

    final legacy = {
      if (prefs.getString(_spec) case final spec?) 'spec': decode(spec),
      if (prefs.getString(_look) case final look?) 'look': decode(look),
      if (prefs.getBool(_default) == true) 'default': true,
    };
    var record = user == null ? null : decode(prefs.getString(_account(user)));
    if (record == null && user != null && legacy.isNotEmpty) {
      // The phone-wide avatar 0.4.0+4 kept is the signed-in account's pick.
      record = legacy;
      unawaited(prefs.setString(_account(user), jsonEncode(legacy)));
      final photo = prefs.getString(_photo);
      if (photo != null) {
        unawaited(prefs.setString(_accountPhoto(user), photo));
      }
    }
    record ??= legacy;
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
    final awaiting = live != null && !kept;
    final saved =
        look ??
        (live == null
            ? IqAvatarPresets.person1
            : defaultAvatarLook(user, _gender));
    return AvatarState(
      spec: awaiting ? awaitingAvatar : spec ?? IqPersonAvatar(saved),
      look: saved,
      photo: photo,
      isDefault: !kept || record['default'] == true,
      known: !awaiting,
      pickedAt: DateTime.tryParse('${record['pickedAt']}'),
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
    if (!ref.mounted) return;
    if (!_synced) {
      _pulling ??= _pull(live).whenComplete(() => _pulling = null);
    }
    if (live.photos && _pendingPhoto) _push(live);
  }

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  bool get _pendingPhoto => switch (_userId) {
    final user? => _prefs.getBool(_photoPending(user)) ?? false,
    null => false,
  };

  void _push(LiveAvatarService live) {
    _pushing ??= _pushPhoto(live).whenComplete(() => _pushing = null);
  }

  /// Sends the photo picked on this phone up (contract 12.4). Without an
  /// answer, or while the API asks to wait, it stays to go again when the
  /// API is reachable or the app comes back; refused for good, it stays on
  /// the phone and the account keeps the pick without it, as before photos
  /// went up. A pick made while it went is sent again after it, so the
  /// newest pick wins.
  Future<void> _pushPhoto(LiveAvatarService live) async {
    final user = _userId;
    final bytes = state.photo;
    if (user == null) return;
    if (bytes == null) {
      await _prefs.remove(_photoPending(user));
      return;
    }
    final scope = ref.read(accountScopeProvider);
    final changes = _changes;
    final AccountAvatar? account;
    try {
      account = await live.uploadPhoto(bytes);
    } on ApiUnreachable {
      return;
    } on ApiRefused catch (refused) {
      if (unanswered(refused) || refused.code == 'ACCOUNT_CLOSING') return;
      debugPrint('Avatar: photo refused: $refused');
      if (!ref.mounted || !scope.open) return;
      await _prefs.remove(_photoPending(user));
      if (state.spec is IqPhotoAvatar) {
        await _upload(live, state.spec, state.look);
      }
      return;
    } on Object catch (error) {
      debugPrint('Avatar: photo not sent: $error');
      return;
    }
    if (!ref.mounted || !scope.open) return;
    final sent = state.photo;
    if (sent == null || !listEquals(sent, bytes)) {
      // A newer photo was picked while this one went: it goes next.
      if (sent != null) Future(() => _push(live));
      return;
    }
    await _prefs.remove(_photoPending(user));
    if (account?.photoUrl case final url?) {
      await _prefs.setString(_photoUrl(user), url);
    }
    if (changes != _changes || state.spec is! IqPhotoAvatar) {
      if (state.spec is! IqPhotoAvatar) {
        await _upload(live, state.spec, state.look);
      }
      return;
    }
    if (account == null) return;
    state = AvatarState(
      spec: IqPhotoAvatar(bytes),
      look: account.look,
      photo: bytes,
      pickedAt: account.updatedAt,
    );
    await _keep(
      IqPhotoAvatar(bytes),
      account.look,
      pickedAt: account.updatedAt,
    );
  }

  /// Brings the account's photo onto this phone when it is not the one kept
  /// here (another phone uploaded it, or this one never had it), and lets
  /// go of a kept photo the account no longer has. A photo still to go up
  /// from here wins.
  Future<void> _pullPhoto(LiveAvatarService live, AccountAvatar account) async {
    final user = _userId;
    if (user == null || _pendingPhoto) return;
    final kept = _prefs.getString(_photoUrl(user));
    final url = account.photoUrl;
    if (url == null) {
      if (kept == null) {
        // Picked before photos went up: the account shows it without it.
        if (account.photoShown && state.photo != null) {
          await _prefs.setBool(_photoPending(user), true);
          _push(live);
        }
        return;
      }
      await _dropPhoto(user);
      if (state.spec is IqPhotoAvatar) {
        state = AvatarState(
          spec: IqPersonAvatar(state.look),
          look: state.look,
          pickedAt: state.pickedAt,
        );
        await _keep(state.spec, state.look, pickedAt: state.pickedAt);
      } else {
        state = AvatarState(
          spec: state.spec,
          look: state.look,
          isDefault: state.isDefault,
          pickedAt: state.pickedAt,
        );
      }
      return;
    }
    if (url == kept && state.photo != null) {
      if (account.photoShown && state.spec is! IqPhotoAvatar) {
        state = AvatarState(
          spec: IqPhotoAvatar(state.photo!),
          look: state.look,
          photo: state.photo,
          pickedAt: state.pickedAt,
        );
      }
      return;
    }
    final scope = ref.read(accountScopeProvider);
    final changes = _changes;
    final Uint8List? bytes;
    try {
      bytes = await live.photo(url);
    } on Object catch (error) {
      debugPrint('Avatar: photo not read: $error');
      return;
    }
    if (bytes == null || !ref.mounted || !scope.open) return;
    if (changes != _changes) return;
    await _prefs.setString(_accountPhoto(user), base64Encode(bytes));
    await _prefs.setString(_photoUrl(user), url);
    final spec = account.photoShown ? IqPhotoAvatar(bytes) : state.spec;
    state = AvatarState(
      spec: spec,
      look: state.look,
      photo: bytes,
      isDefault: state.isDefault,
      pickedAt: state.pickedAt,
    );
    if (spec is IqPhotoAvatar) {
      await _keep(spec, state.look, pickedAt: state.pickedAt);
    }
  }

  Future<void> _dropPhoto(String user) async {
    await _prefs.remove(_accountPhoto(user));
    await _prefs.remove(_photoUrl(user));
    await _prefs.remove(_photoPending(user));
    await _prefs.remove(_photo);
  }

  /// Removes the photo from the account and this phone (contract 12.4); a
  /// photo avatar becomes the last illustrated person, as the API answers.
  /// Online only, so it throws [ApiUnreachable] or [ApiRefused] when the
  /// API does not take it.
  Future<void> removePhoto() async {
    final live = ref.read(liveAvatarServiceProvider);
    final user = _userId;
    if (live == null || !live.photos || user == null) return;
    final scope = ref.read(accountScopeProvider);
    _changes++;
    await _prefs.remove(_photoPending(user));
    final account = await live.deletePhoto();
    if (!ref.mounted || !scope.open) return;
    await _dropPhoto(user);
    final look = account?.look ?? state.look;
    final spec = state.spec is IqPhotoAvatar
        ? account?.spec ?? IqPersonAvatar(look)
        : state.spec;
    state = AvatarState(
      spec: spec,
      look: look,
      isDefault: state.isDefault,
      pickedAt: account?.updatedAt ?? state.pickedAt,
    );
    await _keep(spec, look, pickedAt: state.pickedAt);
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

  /// The newest pick wins: a pick on the phone newer than the account's
  /// avatar, or any pick while the account only has its default (one made
  /// before the account kept avatars), goes up instead.
  Future<void> _apply(LiveAvatarService live, AccountAvatar? account) async {
    if (account == null) return;
    _synced = true;
    final held = state;
    final picked = held.pickedAt;
    final updated = account.updatedAt;
    final newer =
        picked != null && (updated == null || picked.isAfter(updated));
    if (held.known &&
        !held.isDefault &&
        (account.isDefault || (newer && held.spec != account.spec))) {
      await _save(live, held.spec, held.look);
      return;
    }
    state = AvatarState(
      spec: account.spec,
      look: account.look,
      photo: held.photo,
      isDefault: account.isDefault,
      pickedAt: updated,
    );
    await _keep(
      account.spec,
      account.look,
      isDefault: account.isDefault,
      pickedAt: updated,
    );
    if (live.photos) await _pullPhoto(live, account);
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

  /// A photo not yet on the account goes up while photos run live; any
  /// other pick queues.
  Future<void> _save(
    LiveAvatarService live,
    IqAvatarSpec spec,
    IqAvatarLook look,
  ) async {
    final user = _userId;
    if (spec is IqPhotoAvatar && live.photos && user != null) {
      final onAccount = _prefs.getString(_photoUrl(user)) != null;
      if (_pendingPhoto || !onAccount) {
        await _prefs.setBool(_photoPending(user), true);
        _push(live);
        return;
      }
    }
    await _upload(live, spec, look);
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
    DateTime? pickedAt,
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
        if (pickedAt != null) 'pickedAt': pickedAt.toUtc().toIso8601String(),
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
    final user = _userId;
    final previous = state.photo;
    if (spec is IqPhotoAvatar &&
        user != null &&
        (previous == null || !listEquals(previous, spec.bytes))) {
      // A new photo: the one the account has, if any, is not it.
      await _prefs.remove(_photoUrl(user));
      await _prefs.setBool(_photoPending(user), true);
    }
    final now = ref.read(clockProvider)();
    state = AvatarState(spec: spec, look: look, photo: photo, pickedAt: now);
    await _keep(spec, look, pickedAt: now);
    final live = ref.read(liveAvatarServiceProvider);
    if (live != null) await _save(live, spec, look);
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
    // A live account says its own default; a guess would only stand in.
    if (!state.isDefault || ref.read(liveAvatarServiceProvider) != null) {
      return;
    }
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
    await prefs.remove(_photoUrl(userId));
    await prefs.remove(_photoPending(userId));
    ref.invalidateSelf();
  }
}

final avatarProvider = NotifierProvider<AvatarNotifier, AvatarState>(
  AvatarNotifier.new,
);
