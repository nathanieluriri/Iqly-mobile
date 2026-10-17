import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _signedIn() async {
  SharedPreferences.setMockInitialValues({
    'session.signedIn': true,
    'session.userId': 'u_1',
  });
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(c.dispose);
  return c;
}

/// One stretch per account signed in: it closes the moment the account
/// signs out or its session is lost, and the next sign-in, the same
/// account's included, opens a new one.
void main() {
  test('a sign out closes the stretch, and signing back in to the same '
      'account opens a new one', () async {
    final c = await _signedIn();
    final first = c.read(accountScopeProvider);
    expect(first.open, isTrue);
    expect(first.userId, 'u_1');

    final session = c.read(sessionProvider.notifier);
    await session.signOut();
    await session.setUserId('u_1');
    await session.setSignedIn(true);
    final second = c.read(accountScopeProvider);
    expect(first.open, isFalse);
    expect(second, isNot(same(first)));
    expect(second.open, isTrue);
    expect(second.userId, 'u_1');
  });

  test('a lost session closes it too; a new name does not', () async {
    final c = await _signedIn();
    final first = c.read(accountScopeProvider);
    final session = c.read(sessionProvider.notifier);
    await session.setName('Ada Obi');
    expect(c.read(accountScopeProvider), same(first));
    expect(first.open, isTrue);

    await session.lose();
    expect(first.open, isFalse);
    expect(c.read(accountScopeProvider).userId, isNull);
  });

  test('an answer that lands once the stretch has closed fails with '
      'AccountChanged', () async {
    final c = await _signedIn();
    final answer = Completer<int>();
    final guarded = c.read(accountScopeProvider).guard(answer.future);
    await c.read(sessionProvider.notifier).signOut();
    answer.complete(1);
    await expectLater(guarded, throwsA(isA<AccountChanged>()));
  });
}
