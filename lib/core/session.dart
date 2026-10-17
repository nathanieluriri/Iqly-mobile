import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:shared_preferences/shared_preferences.dart';

/// `read` of a widget's ref, a provider's ref or the container, for code
/// any of them runs.
typedef Reader = T Function<T>(ProviderListenable<T> provider);

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) =>
      throw UnimplementedError('Override sharedPreferencesProvider in main'),
);

class SessionState {
  const SessionState({
    this.signedIn = false,
    this.onboardingDone = false,
    this.firstTipSeen = false,
    this.firstName,
    this.name,
    this.userId,
    this.lostUserId,
  });

  final bool signedIn;
  final bool onboardingDone;
  final bool firstTipSeen;

  /// The first word of [name], which Welcome, Resume and Done greet.
  final String? firstName;

  /// The account's name: typed at sign-up on this device, or as the API
  /// holds it after any other sign-in. Null when neither has said.
  final String? name;

  /// The account's id on the API, which keys this person's local store rows.
  /// Null in preview and until the API has said.
  final String? userId;

  /// The account whose session the API ended. What it keeps on this phone
  /// waits for the next sign-in, which keeps it for that account and
  /// forgets it for anyone else.
  final String? lostUserId;

  SessionState copyWith({
    bool? signedIn,
    bool? onboardingDone,
    bool? firstTipSeen,
  }) => SessionState(
    signedIn: signedIn ?? this.signedIn,
    onboardingDone: onboardingDone ?? this.onboardingDone,
    firstTipSeen: firstTipSeen ?? this.firstTipSeen,
    firstName: firstName,
    name: name,
    userId: userId,
    lostUserId: lostUserId,
  );
}

class SessionNotifier extends Notifier<SessionState> {
  static const _signedIn = 'session.signedIn';
  static const _onboardingDone = 'session.onboardingDone';
  static const _firstTipSeen = 'session.firstTipSeen';
  static const _firstName = 'session.firstName';
  static const _name = 'session.name';
  static const _userId = 'session.userId';
  static const _lostUserId = 'session.lostUserId';

  @override
  SessionState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return SessionState(
      signedIn: prefs.getBool(_signedIn) ?? false,
      onboardingDone: prefs.getBool(_onboardingDone) ?? false,
      firstTipSeen: prefs.getBool(_firstTipSeen) ?? false,
      firstName: prefs.getString(_firstName),
      name: prefs.getString(_name),
      userId: prefs.getString(_userId),
      lostUserId: prefs.getString(_lostUserId),
    );
  }

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  Future<void> setSignedIn(bool value) =>
      _set(_signedIn, value, state.copyWith(signedIn: value));

  Future<void> setOnboardingDone(bool value) =>
      _set(_onboardingDone, value, state.copyWith(onboardingDone: value));

  Future<void> setFirstTipSeen(bool value) =>
      _set(_firstTipSeen, value, state.copyWith(firstTipSeen: value));

  Future<void> setName(String? value) async {
    final name = value?.trim().replaceAll(RegExp(r'\s+'), ' ');
    final full = name == null || name.isEmpty ? null : name;
    final first = full?.split(' ').first;
    state = SessionState(
      signedIn: state.signedIn,
      onboardingDone: state.onboardingDone,
      firstTipSeen: state.firstTipSeen,
      firstName: first,
      name: full,
      userId: state.userId,
      lostUserId: state.lostUserId,
    );
    await Future.wait([_keep(_name, full), _keep(_firstName, first)]);
  }

  Future<void> setUserId(String? value) async {
    final id = value == null || value.isEmpty ? null : value;
    state = SessionState(
      signedIn: state.signedIn,
      onboardingDone: state.onboardingDone,
      firstTipSeen: state.firstTipSeen,
      firstName: state.firstName,
      name: state.name,
      userId: id,
      lostUserId: state.lostUserId,
    );
    await _keep(_userId, id);
  }

  Future<void> setLostUserId(String? value) async {
    state = SessionState(
      signedIn: state.signedIn,
      onboardingDone: state.onboardingDone,
      firstTipSeen: state.firstTipSeen,
      firstName: state.firstName,
      name: state.name,
      userId: state.userId,
      lostUserId: value,
    );
    await _keep(_lostUserId, value);
  }

  /// The API ended the session: signed out in one step, with the account
  /// noted as [SessionState.lostUserId] and the rest of the session kept
  /// for its next sign-in.
  Future<void> lose() async {
    final lost = state.userId;
    state = SessionState(
      onboardingDone: state.onboardingDone,
      firstTipSeen: state.firstTipSeen,
      firstName: state.firstName,
      name: state.name,
      lostUserId: lost,
    );
    await Future.wait([
      _prefs.setBool(_signedIn, false),
      _keep(_userId, null),
      _keep(_lostUserId, lost),
    ]);
  }

  /// Signed out in one step, with nothing of any account kept.
  Future<void> signOut() async {
    state = const SessionState();
    await Future.wait([
      _prefs.setBool(_signedIn, false),
      _prefs.setBool(_onboardingDone, false),
      _prefs.setBool(_firstTipSeen, false),
      for (final key in [_firstName, _name, _userId, _lostUserId])
        _prefs.remove(key),
    ]);
  }

  Future<void> _keep(String key, String? value) =>
      value == null ? _prefs.remove(key) : _prefs.setString(key, value);

  Future<void> _set(String key, bool value, SessionState next) async {
    state = next;
    await _prefs.setBool(key, value);
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, SessionState>(
  SessionNotifier.new,
);

/// Whose data the app holds: the signed-in account's id, '' while signed in
/// before the API has given one, null while signed out. Everything that
/// keeps one person's data watches it, so a sign-out drops that data and
/// the next sign-in starts from nothing of anyone else's.
final accountProvider = Provider<String?>(
  (ref) => ref.watch(
    sessionProvider.select((s) => s.signedIn ? s.userId ?? '' : null),
  ),
);
