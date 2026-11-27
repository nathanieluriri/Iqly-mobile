import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/backend.dart';
import 'package:iqly_mobile/core/deadline.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/assessment_data.dart';
import 'package:iqly_mobile/data/assessment_service.dart';
import 'package:iqly_mobile/data/token_store.dart';
import 'package:iqly_mobile/data/live/live_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Service extends AssessmentService {
  _Service(this.result) : super(ApiClient(tokens: MemoryTokenStore()));

  Future<AssessmentAccess> Function() result;
  int calls = 0;

  @override
  Future<AssessmentAccess> access() {
    calls++;
    return result();
  }
}

AssessmentAccess _access({
  bool canTake = false,
  bool canResume = false,
  bool canAccessChallenges = false,
  String state = 'needed',
  String? activeSessionId,
}) => AssessmentAccess(
  canTake: canTake,
  canResume: canResume,
  canAccessChallenges: canAccessChallenges,
  state: state,
  activeSessionId: activeSessionId,
);

String _snapshot(AssessmentAccess access, DateTime fetchedAt) => jsonEncode({
  'access': access.toJson(),
  'fetchedAt': fetchedAt.toIso8601String(),
});

Future<ProviderContainer> _container(
  _Service service, {
  required Map<String, Object> initial,
  DateTime? now,
}) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      clockProvider.overrideWithValue(() => now ?? DateTime(2026, 11, 27, 12)),
      liveModeProvider.overrideWithValue(Backend.none),
      assessmentServiceProvider.overrideWithValue(service),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Map<String, Object> _signedIn([String userId = 'u1']) => {
  'session.signedIn': true,
  'session.userId': userId,
  'session.onboardingDone': true,
};

void main() {
  test('an expired cached no-show renders before an offline refresh', () async {
    final old = DateTime(2026, 11, 27, 11);
    final service = _Service(() => Future.error(Exception('offline')));
    final c = await _container(
      service,
      initial: {
        ..._signedIn(),
        'assessment.access.u1': _snapshot(_access(state: 'unavailable'), old),
      },
    );

    final first = c.read(assessmentAccessProvider);
    expect(first.access?.state, 'unavailable');
    expect(first.fetchedAt, old);
    expect(first.terminalPassed, isFalse);

    await Future<void>.delayed(Duration.zero);
    final after = c.read(assessmentAccessProvider);
    expect(after.access?.state, 'unavailable');
    expect(after.fetchedAt, old);
    expect(after.refreshing, isFalse);
    expect(after.error, isNotNull);
  });

  test('a failed forced refresh keeps the snapshot and fetchedAt', () async {
    final fetchedAt = DateTime(2026, 11, 27, 11, 59);
    final service = _Service(() => Future.error(Exception('offline')));
    final c = await _container(
      service,
      initial: {
        ..._signedIn(),
        'assessment.access.u1': _snapshot(
          _access(canResume: true, state: 'in_progress', activeSessionId: 's1'),
          fetchedAt,
        ),
      },
    );

    await c.read(assessmentAccessProvider.notifier).refresh(force: true);
    final state = c.read(assessmentAccessProvider);
    expect(state.access?.activeSessionId, 's1');
    expect(state.fetchedAt, fetchedAt);
    expect(state.error, isNotNull);
  });

  test(
    'a successful refresh replaces the cached state and timestamp',
    () async {
      final old = DateTime(2026, 11, 27, 11);
      final now = DateTime(2026, 11, 27, 12);
      final service = _Service(() async => _access(canTake: true));
      final c = await _container(
        service,
        now: now,
        initial: {
          ..._signedIn(),
          'assessment.access.u1': _snapshot(_access(state: 'unavailable'), old),
        },
      );

      await c.read(assessmentAccessProvider.notifier).refresh(force: true);
      final state = c.read(assessmentAccessProvider);
      expect(state.access?.canTake, isTrue);
      expect(state.fetchedAt, now);
      expect(state.error, isNull);
      final prefs = c.read(sharedPreferencesProvider);
      expect(
        prefs.getString('assessment.access.u1'),
        _snapshot(state.access!, now),
      );
    },
  );

  test('a pass removes the snapshot and writes a terminal receipt', () async {
    final now = DateTime(2026, 11, 27, 12);
    final service = _Service(
      () async => _access(canAccessChallenges: true, state: 'passed'),
    );
    final c = await _container(
      service,
      now: now,
      initial: {
        ..._signedIn(),
        'assessment.access.u1': _snapshot(
          _access(canTake: true),
          now.subtract(const Duration(minutes: 20)),
        ),
      },
    );

    await c.read(assessmentAccessProvider.notifier).refresh(force: true);
    final state = c.read(assessmentAccessProvider);
    expect(state.terminalPassed, isTrue);
    expect(state.access?.canAccessChallenges, isTrue);
    final prefs = c.read(sharedPreferencesProvider);
    expect(prefs.containsKey('assessment.access.u1'), isFalse);
    expect(prefs.getString('assessment.qualified.u1'), now.toIso8601String());
  });

  test('a cold launch with a terminal receipt makes no request', () async {
    final service = _Service(() => Future.error(Exception('must not run')));
    final c = await _container(
      service,
      initial: {
        ..._signedIn(),
        'assessment.qualified.u1': DateTime(2026, 11, 27, 12).toIso8601String(),
      },
    );

    final state = c.read(assessmentAccessProvider);
    expect(state.terminalPassed, isTrue);
    await c.read(assessmentAccessProvider.notifier).refresh(force: true);
    await Future<void>.delayed(Duration.zero);
    expect(service.calls, 0);
  });

  test('account changes use only the new account snapshot', () async {
    final service = _Service(() => Future.error(Exception('must not run')));
    final c = await _container(
      service,
      initial: {
        ..._signedIn('u1'),
        'assessment.access.u1': _snapshot(
          _access(canTake: true),
          DateTime(2026, 11, 27, 12),
        ),
        'assessment.access.u2': _snapshot(
          _access(state: 'unavailable'),
          DateTime(2026, 11, 27, 12),
        ),
      },
    );

    expect(c.read(assessmentAccessProvider).access?.canTake, isTrue);
    await c.read(sessionProvider.notifier).setUserId('u2');
    expect(c.read(assessmentAccessProvider).access?.state, 'unavailable');
    expect(service.calls, 0);
  });
}
