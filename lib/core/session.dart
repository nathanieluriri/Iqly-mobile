import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  });

  final bool signedIn;
  final bool onboardingDone;
  final bool firstTipSeen;

  /// The first name typed at sign-up on this device, null after any other
  /// sign-in. Welcome and Done greet it until the account says otherwise.
  final String? firstName;

  SessionState copyWith({
    bool? signedIn,
    bool? onboardingDone,
    bool? firstTipSeen,
  }) => SessionState(
    signedIn: signedIn ?? this.signedIn,
    onboardingDone: onboardingDone ?? this.onboardingDone,
    firstTipSeen: firstTipSeen ?? this.firstTipSeen,
    firstName: firstName,
  );
}

class SessionNotifier extends Notifier<SessionState> {
  static const _signedIn = 'session.signedIn';
  static const _onboardingDone = 'session.onboardingDone';
  static const _firstTipSeen = 'session.firstTipSeen';
  static const _firstName = 'session.firstName';

  @override
  SessionState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return SessionState(
      signedIn: prefs.getBool(_signedIn) ?? false,
      onboardingDone: prefs.getBool(_onboardingDone) ?? false,
      firstTipSeen: prefs.getBool(_firstTipSeen) ?? false,
      firstName: prefs.getString(_firstName),
    );
  }

  Future<void> setSignedIn(bool value) =>
      _set(_signedIn, value, state.copyWith(signedIn: value));

  Future<void> setOnboardingDone(bool value) =>
      _set(_onboardingDone, value, state.copyWith(onboardingDone: value));

  Future<void> setFirstTipSeen(bool value) =>
      _set(_firstTipSeen, value, state.copyWith(firstTipSeen: value));

  Future<void> setFirstName(String? value) async {
    state = SessionState(
      signedIn: state.signedIn,
      onboardingDone: state.onboardingDone,
      firstTipSeen: state.firstTipSeen,
      firstName: value,
    );
    final prefs = ref.read(sharedPreferencesProvider);
    await (value == null
        ? prefs.remove(_firstName)
        : prefs.setString(_firstName, value));
  }

  Future<void> _set(String key, bool value, SessionState next) async {
    state = next;
    await ref.read(sharedPreferencesProvider).setBool(key, value);
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, SessionState>(
  SessionNotifier.new,
);
