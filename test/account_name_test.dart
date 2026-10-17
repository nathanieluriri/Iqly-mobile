import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/auth.dart';
import 'package:iqly_mobile/features/onboarding/onboarding_draft.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Account extends DemoAuthService {
  _Account(this.name);

  final String? name;
  int asked = 0;

  @override
  Future<String?> accountName() async {
    asked++;
    return name;
  }
}

Future<ProviderContainer> _container(
  _Account auth, {
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final shared = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(shared),
      authServiceProvider.overrideWithValue(auth),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<String?> _greeting(ProviderContainer container) async {
  container.listen(greetingNameProvider, (_, _) {});
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  return container.read(greetingNameProvider);
}

void main() {
  test('an account signed in before names were kept is asked once, and '
      'the answer is kept', () async {
    final auth = _Account('Ngozi  Eze');
    final container = await _container(auth, prefs: {'session.signedIn': true});
    expect(await _greeting(container), 'Ngozi');
    expect(container.read(sessionProvider).name, 'Ngozi Eze');
    expect(container.read(accountNameProvider), 'Ngozi Eze');
    expect(auth.asked, 1);

    final prefs = container.read(sharedPreferencesProvider);
    expect(prefs.getString('session.name'), 'Ngozi Eze');
    expect(prefs.getString('session.firstName'), 'Ngozi');
  });

  test('a kept name is greeted without asking', () async {
    final auth = _Account('Someone Else');
    final container = await _container(
      auth,
      prefs: {
        'session.signedIn': true,
        'session.name': 'Tolu Bello',
        'session.firstName': 'Tolu',
      },
    );
    expect(await _greeting(container), 'Tolu');
    expect(auth.asked, 0);
  });

  test('with no name from the API the greeting has none, never the sample '
      "account's", () async {
    final auth = _Account(null);
    final container = await _container(auth, prefs: {'session.signedIn': true});
    expect(await _greeting(container), isNull);
    expect(container.read(sessionProvider).name, isNull);
  });

  test('signed out, nobody is asked', () async {
    final auth = _Account('Ngozi Eze');
    final container = await _container(auth);
    expect(await _greeting(container), isNull);
    expect(auth.asked, 0);
  });

  test('forgetting the account drops the name', () async {
    final container = await _container(
      _Account(null),
      prefs: {'session.name': 'Tolu Bello', 'session.firstName': 'Tolu'},
    );
    await container.read(sessionProvider.notifier).setName(null);
    final prefs = container.read(sharedPreferencesProvider);
    expect(prefs.getString('session.name'), isNull);
    expect(prefs.getString('session.firstName'), isNull);
  });
}
