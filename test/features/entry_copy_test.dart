import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/auth.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/features/entry/entry_copy.dart';

void main() {
  group('failure to copy', () {
    test('sign in', () {
      expect(
        EntryCopy.signIn(AuthFailure.wrongCredentials),
        'That email and password don’t match. Try again.',
      );
      expect(
        EntryCopy.signIn(AuthFailure.emailNotVerified),
        'Verification email sent. Please check your inbox.',
      );
      expect(
        EntryCopy.signIn(AuthFailure.tooManyAttempts),
        'Too many tries. Wait a minute, then try again.',
      );
      expect(
        EntryCopy.signIn(AuthFailure.offline),
        'You’re offline. Check your connection and try again.',
      );
      for (final failure in [
        AuthFailure.unknown,
        AuthFailure.emailTaken,
        AuthFailure.cancelled,
      ]) {
        expect(EntryCopy.signIn(failure), 'Login failed. Please try again.');
      }
    });

    test('sign up', () {
      expect(EntryCopy.signUp(AuthFailure.offline), EntryCopy.offline);
      for (final failure in AuthFailure.values.where(
        (f) => f != AuthFailure.offline,
      )) {
        expect(EntryCopy.signUp(failure), 'Sign-up failed. Please try again.');
      }
    });

    test('reset link', () {
      expect(EntryCopy.resetLink(AuthFailure.offline), EntryCopy.offline);
      for (final failure in AuthFailure.values.where(
        (f) => f != AuthFailure.offline,
      )) {
        expect(
          EntryCopy.resetLink(failure),
          'Could not send reset email. Please try again.',
        );
      }
    });

    test('Apple and Google', () {
      expect(
        EntryCopy.social(AuthProvider.apple),
        'Apple sign-in didn’t work. Try again.',
      );
      expect(
        EntryCopy.social(AuthProvider.google),
        'Google sign-in didn’t work. Try again.',
      );
    });

    test('bad email and the shipped password rule', () {
      expect(
        EntryCopy.badEmail,
        'That email doesn’t look right. Check for typos.',
      );
      expect(ShippedCopy.shortPassword, 'At least 8 characters');
    });
  });

  group('demo service', () {
    final auth = DemoAuthService(delay: Duration.zero);
    const adaeze = 'adaeze@example.com';

    Future<AuthFailure?> signIn(String email, [String? password]) async =>
        (await auth.signIn(
          email: email,
          password: password ?? DemoAuthService.password,
        )).failure;

    Future<AuthFailure?> signUp(String email) async => (await auth.signUp(
      firstName: 'Tolu',
      lastName: 'Bello',
      email: email,
      password: 'longenough',
    )).failure;

    test('the sample account signs in with the demo password only', () async {
      expect(DemoData.user.email, adaeze);
      expect(DemoAuthService.password.length, greaterThanOrEqualTo(8));
      expect(await signIn(adaeze), isNull);
      expect(await signIn(' Adaeze@Example.com '), isNull);
      expect(await signIn(adaeze, 'wrongpass'), AuthFailure.wrongCredentials);
      expect(await signIn('tolu@example.com'), AuthFailure.wrongCredentials);
    });

    test('demo emails act out each sign-in failure', () async {
      expect(
        await signIn(DemoAuthService.lockedEmail),
        AuthFailure.tooManyAttempts,
      );
      expect(
        await signIn(DemoAuthService.unverifiedEmail),
        AuthFailure.emailNotVerified,
      );
      expect(await signIn(DemoAuthService.offlineEmail), AuthFailure.offline);
      expect(await signIn(DemoAuthService.brokenEmail), AuthFailure.unknown);
    });

    test('lookup: known, new and offline', () async {
      for (final email in [
        adaeze,
        DemoAuthService.lockedEmail,
        DemoAuthService.unverifiedEmail,
      ]) {
        final result = await auth.lookUpEmail(email);
        expect(result.ok && !result.newAccount, isTrue, reason: email);
      }
      for (final email in [
        'tolu@example.com',
        DemoAuthService.takenEmail,
        DemoAuthService.brokenEmail,
      ]) {
        expect((await auth.lookUpEmail(email)).newAccount, isTrue);
      }
      expect(
        (await auth.lookUpEmail(DemoAuthService.offlineEmail)).failure,
        AuthFailure.offline,
      );
    });

    test('sign up: new, taken, offline and unknown', () async {
      expect(await signUp('tolu@example.com'), isNull);
      expect(await signUp(DemoAuthService.takenEmail), AuthFailure.emailTaken);
      expect(await signUp(adaeze), AuthFailure.emailTaken);
      expect(await signUp(DemoAuthService.offlineEmail), AuthFailure.offline);
      expect(await signUp(DemoAuthService.brokenEmail), AuthFailure.unknown);
    });

    test('reset link: sent, offline and unknown', () async {
      expect((await auth.sendResetLink(adaeze)).ok, isTrue);
      expect(
        (await auth.sendResetLink(DemoAuthService.offlineEmail)).failure,
        AuthFailure.offline,
      );
      expect(
        (await auth.sendResetLink(DemoAuthService.brokenEmail)).failure,
        AuthFailure.unknown,
      );
    });

    test('Apple and Google: new, existing or failing on request', () async {
      expect((await auth.continueWith(AuthProvider.apple)).newAccount, isTrue);
      final existing = DemoAuthService(
        delay: Duration.zero,
        socialAccountExists: true,
      );
      final known = await existing.continueWith(AuthProvider.google);
      expect(known.ok && !known.newAccount, isTrue);
      final failing = DemoAuthService(
        delay: Duration.zero,
        socialFailure: AuthFailure.cancelled,
      );
      expect(
        (await failing.continueWith(AuthProvider.apple)).failure,
        AuthFailure.cancelled,
      );
    });
  });
}
