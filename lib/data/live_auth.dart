import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'api_client.dart';
import 'api_config.dart';
import 'auth.dart';

/// What Apple or Google hand back: an ID token for the API to check.
class SocialToken {
  const SocialToken(this.idToken, {this.nonce, this.firstName, this.lastName});

  final String idToken;
  final String? nonce;

  /// Apple shares the name on the first sign in only.
  final String? firstName;
  final String? lastName;
}

/// The native Apple and Google sheets. Null means the person closed them.
abstract class SocialIdentity {
  bool offers(AuthProvider provider);
  Future<SocialToken?> signIn(AuthProvider provider);
  Future<void> signOut();
}

/// Apple on iPhone only for now (Android needs Apple's web flow set up);
/// Google on Android and iPhone.
class NativeSocialIdentity implements SocialIdentity {
  Future<void>? _googleReady;

  @override
  bool offers(AuthProvider provider) => switch (provider) {
    AuthProvider.apple => Platform.isIOS,
    AuthProvider.google => Platform.isAndroid || Platform.isIOS,
  };

  @override
  Future<SocialToken?> signIn(AuthProvider provider) => switch (provider) {
    AuthProvider.apple => _apple(),
    AuthProvider.google => _google(),
  };

  Future<SocialToken?> _google() async {
    final google = GoogleSignIn.instance;
    await (_googleReady ??= google.initialize(
      clientId: Platform.isIOS ? ApiConfig.googleIosClientId : null,
      serverClientId: ApiConfig.googleWebClientId,
    ));
    try {
      final account = await google.authenticate();
      final token = account.authentication.idToken;
      if (token == null) throw StateError('Google returned no ID token');
      return SocialToken(token);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  Future<SocialToken?> _apple() async {
    final random = Random.secure();
    final raw = base64Url.encode(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    // Apple puts the hash in the token, and the API compares it as sent.
    final nonce = sha256.convert(utf8.encode(raw)).toString();
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );
      final token = credential.identityToken;
      if (token == null) throw StateError('Apple returned no identity token');
      return SocialToken(
        token,
        nonce: nonce,
        firstName: credential.givenName,
        lastName: credential.familyName,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    if (_googleReady != null) await GoogleSignIn.instance.signOut();
  }
}

/// [AuthService] on the iQLY API (Better Auth under /auth/web, with bearer
/// tokens and email codes for the app).
class LiveAuthService implements AuthService {
  LiveAuthService({required this.api, SocialIdentity? social})
    : social = social ?? NativeSocialIdentity();

  final ApiClient api;
  final SocialIdentity social;

  static const _auth = ApiConfig.authPath;

  @override
  Future<AuthResult> lookUpEmail(String email) => _guard(() async {
    final res = await api.post('/mobile/email-status', {'email': email});
    if (!res.ok) return _failure(res);
    return AuthResult.success(newAccount: res.data['exists'] != true);
  });

  @override
  Future<AuthResult> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? inviteCode,
  }) => _guard(() async {
    final res = await api.post('$_auth/sign-up/email', {
      'name': '$firstName $lastName'.trim(),
      'email': email.trim(),
      'password': password,
    });
    if (!res.ok) return _failure(res);
    final sent = await sendVerificationCode(email);
    return sent.ok ? const AuthResult.success(newAccount: true) : sent;
  });

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) => _guard(() async {
    final res = await api.post('$_auth/sign-in/email', {
      'email': email.trim(),
      'password': password,
    });
    if (!res.ok) return _failure(res);
    return _signedIn(res);
  });

  @override
  bool offers(AuthProvider provider) => social.offers(provider);

  @override
  Future<AuthResult> continueWith(AuthProvider provider) => _guard(() async {
    final SocialToken? token;
    try {
      token = await social.signIn(provider);
    } catch (_) {
      return const AuthResult.failure(AuthFailure.unknown);
    }
    if (token == null) return const AuthResult.failure(AuthFailure.cancelled);
    final name = [token.firstName, token.lastName].whereType<String>();
    final res = await api.post('$_auth/sign-in/social', {
      'provider': provider.name,
      'idToken': {
        'token': token.idToken,
        'nonce': ?token.nonce,
        if (name.isNotEmpty)
          'user': {
            'name': {'firstName': token.firstName, 'lastName': token.lastName},
          },
      },
    });
    if (!res.ok) return _failure(res);
    return _signedIn(res);
  });

  @override
  Future<AuthResult> sendResetLink(String email) => _guard(() async {
    final res = await api.post('$_auth/request-password-reset', {
      'email': email.trim(),
      'redirectTo': '${ApiConfig.webUrl}/reset-password',
    });
    return res.ok ? const AuthResult.success() : _failure(res);
  });

  @override
  Future<AuthResult> sendVerificationCode(String email) => _guard(() async {
    final res = await api.post('$_auth/email-otp/send-verification-otp', {
      'email': email.trim(),
      'type': 'email-verification',
    });
    return res.ok ? const AuthResult.success() : _failure(res);
  });

  @override
  Future<AuthResult> verifyEmail({
    required String email,
    required String code,
  }) => _guard(() async {
    final res = await api.post('$_auth/email-otp/verify-email', {
      'email': email.trim(),
      'otp': code,
    });
    if (!res.ok) return _failure(res);
    return _signedIn(res);
  });

  @override
  Future<void> signOut() async {
    try {
      await api.post('$_auth/sign-out');
    } on ApiUnreachable {
      // The token is dropped below either way; the server one expires.
    }
    await api.tokens.clear();
    await social.signOut();
  }

  @override
  Future<String?> accountName() async {
    try {
      final res = await api.get('$_auth/get-session');
      return res.ok ? _nameIn(res.body) : null;
    } on ApiUnreachable {
      return null;
    }
  }

  Future<AuthResult> _signedIn(ApiResponse res) async => AuthResult.success(
    newAccount: await _onboardingDue(),
    name: _nameIn(res.body) ?? await accountName(),
    userId: _userIn(res.body, 'id'),
  );

  /// Better Auth answers sign-ins and sessions with the account as `user`.
  static String? _nameIn(Map<String, dynamic> body) => _userIn(body, 'name');

  static String? _userIn(Map<String, dynamic> body, String field) {
    final user = body['user'];
    final value = user is Map ? user[field] : null;
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  /// A new account has no contributor profile yet (the API's not found),
  /// or one with onboarding still open. Any other failure asks `GET /me`,
  /// whose profile carries the same date; with no answer from either the
  /// account counts as returning, so nobody who finished first run is sent
  /// back to it (`syncFirstRun` puts first run back once `/me` shows the
  /// account has no record of it).
  Future<bool> _onboardingDue() async {
    try {
      final res = await api.get('/profiles/contributors/me');
      if (res.ok) return res.data['onboardingCompletedAt'] == null;
      if (res.status == 404) return true;
    } on ApiUnreachable {
      // Asked of /me below.
    }
    try {
      final res = await api.get('/me');
      if (res.ok) {
        final profile = res.data['profile'];
        return profile is! Map || profile['onboardingCompletedAt'] == null;
      }
    } on ApiUnreachable {
      // Neither answered: returning.
    }
    return false;
  }

  static Future<AuthResult> _guard(Future<AuthResult> Function() call) async {
    try {
      return await call();
    } on ApiUnreachable {
      return const AuthResult.failure(AuthFailure.offline);
    }
  }

  static AuthResult _failure(ApiResponse res) =>
      AuthResult.failure(switch (res.code) {
        'INVALID_EMAIL_OR_PASSWORD' => AuthFailure.wrongCredentials,
        'EMAIL_NOT_VERIFIED' => AuthFailure.emailNotVerified,
        'USER_ALREADY_EXISTS' ||
        'USER_ALREADY_EXISTS_USE_ANOTHER_EMAIL' => AuthFailure.emailTaken,
        'INVALID_OTP' => AuthFailure.wrongCode,
        'OTP_EXPIRED' => AuthFailure.codeExpired,
        'TOO_MANY_ATTEMPTS' => AuthFailure.tooManyAttempts,
        _ when res.status == 429 => AuthFailure.tooManyAttempts,
        _ => AuthFailure.unknown,
      });
}
