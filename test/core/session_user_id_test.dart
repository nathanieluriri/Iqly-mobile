import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('the account id survives a restart, a name change, and goes with '
      'the account', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    ProviderContainer container() => ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );

    final first = container();
    addTearDown(first.dispose);
    final session = first.read(sessionProvider.notifier);
    await session.setUserId('u_1');
    await session.setName('Ada Obi');
    await session.setSignedIn(true);
    expect(first.read(sessionProvider).userId, 'u_1');

    final second = container();
    addTearDown(second.dispose);
    expect(second.read(sessionProvider).userId, 'u_1');
    await second.read(sessionProvider.notifier).setUserId(null);
    expect(second.read(sessionProvider).userId, isNull);
    expect(prefs.getString('session.userId'), isNull);
  });
}
