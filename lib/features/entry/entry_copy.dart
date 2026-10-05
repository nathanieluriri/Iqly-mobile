import '../../data/auth.dart';

/// Verbatim from iqly.net: change them only when the web does.
abstract final class ShippedCopy {
  static const shortPassword = 'At least 8 characters';
  static const verificationSent =
      'Verification email sent. Please check your inbox.';
  static const loginFailed = 'Login failed. Please try again.';
  static const signUpFailed = 'Sign-up failed. Please try again.';
  static const resetFailed = 'Could not send reset email. Please try again.';
}

/// What the entry screens say when something goes wrong: the B0 error
/// frames' words where Figma has them.
abstract final class EntryCopy {
  /// Figma 480:20014.
  static const badEmail =
      "That doesn't look like an email address. Check it and try again.";

  /// Figma 480:19948, with the Sign in action.
  static const emailRegistered =
      'This email already has an account. Sign in instead.';
  static const offline = 'You’re offline. Check your connection and try again.';

  static String signIn(AuthFailure failure) => switch (failure) {
    AuthFailure.wrongCredentials =>
      "That password doesn't match. Try again or reset it.",
    AuthFailure.emailNotVerified => ShippedCopy.verificationSent,
    AuthFailure.tooManyAttempts =>
      'Too many tries. Wait a minute, then try again.',
    AuthFailure.offline => offline,
    _ => ShippedCopy.loginFailed,
  };

  /// [AuthFailure.emailTaken] has no words: the screen moves on to Sign in.
  static String signUp(AuthFailure failure) => switch (failure) {
    AuthFailure.offline => offline,
    _ => ShippedCopy.signUpFailed,
  };

  static String resetLink(AuthFailure failure) => switch (failure) {
    AuthFailure.offline => offline,
    _ => ShippedCopy.resetFailed,
  };

  static String social(AuthProvider provider) => switch (provider) {
    AuthProvider.apple => 'Apple sign-in didn’t work. Try again.',
    AuthProvider.google => 'Google sign-in didn’t work. Try again.',
  };
}
