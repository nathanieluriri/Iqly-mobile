import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'demo_data.dart';

enum AuthProvider { apple, google }

abstract final class AuthTiming {
  /// A new email code can go out once a minute.
  static const codeResendAfter = Duration(seconds: 60);
  static const countdownStep = Duration(seconds: 1);
}

/// Why an auth call failed. The live API layer maps its codes onto these
/// (INVALID_EMAIL_OR_PASSWORD to [wrongCredentials], EMAIL_NOT_VERIFIED to
/// [emailNotVerified], and so on); the screens choose the words.
enum AuthFailure {
  wrongCredentials,
  emailNotVerified,
  tooManyAttempts,
  offline,

  /// Sign up with an email that already has an account.
  emailTaken,

  /// The person closed the Apple or Google sheet.
  cancelled,

  /// The email code doesn't match the one sent.
  wrongCode,

  /// The email code is past its 5 minutes; a new one is needed.
  codeExpired,
  unknown,
}

class AuthResult {
  const AuthResult.success({this.newAccount = false}) : failure = null;
  const AuthResult.failure(AuthFailure this.failure) : newAccount = false;

  /// No account holds this email or Apple or Google identity yet.
  final bool newAccount;
  final AuthFailure? failure;

  bool get ok => failure == null;
}

/// Sign up, sign in and password reset. The demo answers after a short
/// delay; the live API replaces it behind the same interface.
abstract class AuthService {
  /// Succeeds with [AuthResult.newAccount] set when no account has [email].
  Future<AuthResult> lookUpEmail(String email);

  /// [inviteCode] is the friend's code from an invite link, if any.
  Future<AuthResult> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? inviteCode,
  });
  Future<AuthResult> signIn({required String email, required String password});

  /// Whether this device offers [provider] on the landing.
  bool offers(AuthProvider provider);

  /// Apple needs sign_in_with_apple, Google needs google_sign_in.
  Future<AuthResult> continueWith(AuthProvider provider);
  Future<AuthResult> sendResetLink(String email);

  /// Emails a 6-digit code that confirms [email]. Sign up and a sign in
  /// before verifying both end on the code screen.
  Future<AuthResult> sendVerificationCode(String email);

  /// Confirms [email] with [code] and signs in. [AuthResult.newAccount] is
  /// set while onboarding is still to do.
  Future<AuthResult> verifyEmail({required String email, required String code});

  Future<void> signOut();
}

/// The sample account is [DemoData.user] with [password]. The other
/// addresses act out each failure for tests and preview films.
class DemoAuthService implements AuthService {
  DemoAuthService({
    this.delay = const Duration(milliseconds: 600),
    this.socialAccountExists = false,
    this.socialFailure,
  });

  /// Signs [DemoData.user] in; any other password is
  /// [AuthFailure.wrongCredentials].
  static const password = 'boldthinker';

  /// Every call fails as [AuthFailure.offline].
  static const offlineEmail = 'offline@example.com';

  /// Has an account; signing in fails as [AuthFailure.tooManyAttempts].
  static const lockedEmail = 'locked@example.com';

  /// Has an account; signing in fails as [AuthFailure.emailNotVerified].
  static const unverifiedEmail = 'unverified@example.com';

  /// Looks new on the landing; signing up fails as [AuthFailure.emailTaken].
  static const takenEmail = 'taken@example.com';

  /// Looks new; signing up, signing in and resets fail as
  /// [AuthFailure.unknown].
  static const brokenEmail = 'broken@example.com';

  /// Verifies any email; [expiredCode] and [lockedCode] act out those
  /// failures and anything else is [AuthFailure.wrongCode].
  static const code = '482915';
  static const expiredCode = '000000';
  static const lockedCode = '999999';

  final Duration delay;

  /// Apple and Google find an existing account instead of a new one.
  final bool socialAccountExists;

  /// Apple and Google fail with this, when set.
  final AuthFailure? socialFailure;

  static final _known = {DemoData.user.email, lockedEmail, unverifiedEmail};

  Future<void> _wait() => Future<void>.delayed(delay);

  static String _normal(String email) => email.trim().toLowerCase();

  @override
  Future<AuthResult> lookUpEmail(String email) async {
    await _wait();
    final address = _normal(email);
    if (address == offlineEmail) {
      return const AuthResult.failure(AuthFailure.offline);
    }
    return AuthResult.success(newAccount: !_known.contains(address));
  }

  @override
  Future<AuthResult> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? inviteCode,
  }) async {
    await _wait();
    final address = _normal(email);
    return switch (address) {
      offlineEmail => const AuthResult.failure(AuthFailure.offline),
      takenEmail => const AuthResult.failure(AuthFailure.emailTaken),
      brokenEmail => const AuthResult.failure(AuthFailure.unknown),
      _ when _known.contains(address) => const AuthResult.failure(
        AuthFailure.emailTaken,
      ),
      _ => const AuthResult.success(newAccount: true),
    };
  }

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    await _wait();
    final address = _normal(email);
    return switch (address) {
      offlineEmail => const AuthResult.failure(AuthFailure.offline),
      lockedEmail => const AuthResult.failure(AuthFailure.tooManyAttempts),
      unverifiedEmail => const AuthResult.failure(AuthFailure.emailNotVerified),
      brokenEmail => const AuthResult.failure(AuthFailure.unknown),
      _
          when address == DemoData.user.email &&
              password == DemoAuthService.password =>
        const AuthResult.success(),
      _ => const AuthResult.failure(AuthFailure.wrongCredentials),
    };
  }

  @override
  bool offers(AuthProvider provider) => true;

  @override
  Future<AuthResult> continueWith(AuthProvider provider) async {
    await _wait();
    final failure = socialFailure;
    if (failure != null) return AuthResult.failure(failure);
    return AuthResult.success(newAccount: !socialAccountExists);
  }

  @override
  Future<AuthResult> sendResetLink(String email) async {
    await _wait();
    return switch (_normal(email)) {
      offlineEmail => const AuthResult.failure(AuthFailure.offline),
      brokenEmail => const AuthResult.failure(AuthFailure.unknown),
      _ => const AuthResult.success(),
    };
  }

  @override
  Future<AuthResult> sendVerificationCode(String email) async {
    await _wait();
    return switch (_normal(email)) {
      offlineEmail => const AuthResult.failure(AuthFailure.offline),
      brokenEmail => const AuthResult.failure(AuthFailure.unknown),
      _ => const AuthResult.success(),
    };
  }

  @override
  Future<AuthResult> verifyEmail({
    required String email,
    required String code,
  }) async {
    await _wait();
    return switch (code) {
      DemoAuthService.code => AuthResult.success(
        newAccount: !_known.contains(_normal(email)),
      ),
      expiredCode => const AuthResult.failure(AuthFailure.codeExpired),
      lockedCode => const AuthResult.failure(AuthFailure.tooManyAttempts),
      _ => const AuthResult.failure(AuthFailure.wrongCode),
    };
  }

  @override
  Future<void> signOut() async {}
}

final authServiceProvider = Provider<AuthService>((ref) => DemoAuthService());
