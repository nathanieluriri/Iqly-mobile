import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/deadline.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/core/updates.dart';
import 'package:iqly_mobile/data/app_version.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Service implements AppVersionService {
  _Service(this.answer);

  Future<AppRelease> Function() answer;
  int calls = 0;

  @override
  Future<AppRelease> check() {
    calls++;
    return answer();
  }
}

const _available = AppRelease(
  installed: '0.1.0+1',
  status: UpdateStatus.available,
  latest: '0.1.0+2',
);

void main() {
  late DateTime now;
  late _Service service;

  Future<ProviderContainer> container() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        clockProvider.overrideWithValue(() => now),
        appVersionServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    now = DateTime(2026, 10, 16, 9);
    service = _Service(() async => _available);
  });

  test('keeps the answer', () async {
    final c = await container();
    await c.read(updatesProvider.notifier).check();
    expect(c.read(updatesProvider)?.status, UpdateStatus.available);
  });

  test('a failed check keeps what was known', () async {
    final c = await container();
    final updates = c.read(updatesProvider.notifier);
    await updates.check();
    service.answer = () => Future.error(Exception('offline'));
    await updates.check();
    expect(c.read(updatesProvider)?.status, UpdateStatus.available);
  });

  test('a check that never answers leaves the app open', () async {
    service.answer = () => Completer<AppRelease>().future;
    final c = await container();
    final updates = c.read(updatesProvider.notifier);
    unawaited(updates.check());
    expect(updates.checking, isTrue);
    await updates.settled(const Duration(milliseconds: 10));
    expect(updates.required, isFalse);
    expect(c.read(updatesProvider), isNull);
  });

  test('a resume checks again only once an hour has passed', () async {
    final c = await container();
    final updates = c.read(updatesProvider.notifier);
    await updates.check();
    now = now.add(const Duration(minutes: 59));
    updates.resumed();
    expect(service.calls, 1);
    now = now.add(const Duration(minutes: 1));
    updates.resumed();
    expect(service.calls, 2);
  });

  test('offers a newer build at once, then daily until installed', () async {
    final c = await container();
    final updates = c.read(updatesProvider.notifier);
    await updates.check();
    expect(updates.offer, isTrue);
    await updates.offered();
    expect(updates.offer, isFalse);

    now = now.add(const Duration(hours: 23, minutes: 59));
    expect(updates.offer, isFalse);
    now = now.add(const Duration(minutes: 1));
    expect(updates.offer, isTrue);
    await updates.offered();
    expect(updates.offer, isFalse);

    service.answer = () async => const AppRelease(
      installed: '0.1.0+1',
      status: UpdateStatus.available,
      latest: '0.1.0+3',
    );
    await updates.check();
    expect(updates.offer, isTrue);
  });

  test('never offers a build that is required or current', () async {
    service.answer = () async => const AppRelease(
      installed: '0.1.0+1',
      status: UpdateStatus.required,
      minimum: '0.2.0',
      latest: '0.2.0+4',
    );
    final c = await container();
    final updates = c.read(updatesProvider.notifier);
    await updates.check();
    expect(updates.required, isTrue);
    expect(updates.offer, isFalse);
  });
}
