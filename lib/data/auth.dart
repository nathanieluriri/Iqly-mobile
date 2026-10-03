import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'demo_data.dart';

enum AuthProvider { apple, google }

class AuthResult {
  const AuthResult.success({this.newAccount = false}) : error = null;
  const AuthResult.failure(String this.error) : newAccount = false;

  final bool newAccount;

  /// The API's message, shown under the field as it comes back.
  final String? error;

  bool get ok => error == null;
}

/// Sign up, sign in and password reset. The demo succeeds after a short
/// delay; the live API replaces it behind the same interface.
abstract class AuthService {
  Future<bool> isKnownEmail(String email);
  Future<AuthResult> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  });
  Future<AuthResult> signIn({required String email, required String password});

  /// Apple needs sign_in_with_apple, Google needs google_sign_in.
  Future<AuthResult> continueWith(AuthProvider provider);
  Future<AuthResult> sendResetLink(String email);
}

class DemoAuthService implements AuthService {
  DemoAuthService({this.delay = const Duration(milliseconds: 600)});

  final Duration delay;

  Future<void> _wait() => Future<void>.delayed(delay);

  @override
  Future<bool> isKnownEmail(String email) async {
    await _wait();
    return email.trim().toLowerCase() == DemoData.user.email;
  }

  @override
  Future<AuthResult> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    await _wait();
    return const AuthResult.success(newAccount: true);
  }

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    await _wait();
    return const AuthResult.success();
  }

  @override
  Future<AuthResult> continueWith(AuthProvider provider) async {
    await _wait();
    return const AuthResult.success(newAccount: true);
  }

  @override
  Future<AuthResult> sendResetLink(String email) async {
    await _wait();
    return const AuthResult.success();
  }
}

final authServiceProvider = Provider<AuthService>((ref) => DemoAuthService());
