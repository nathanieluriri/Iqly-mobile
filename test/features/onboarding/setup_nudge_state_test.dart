import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/live/live_account.dart';
import 'package:iqly_mobile/data/live/live_profile_service.dart';
import 'package:iqly_mobile/data/onboarding_service.dart';
import 'package:iqly_mobile/features/onboarding/onboarding_draft.dart';
import 'package:iqly_mobile/features/onboarding/setup_nudge_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _full = OnboardingProfile(
  occupation: 'student',
  state: 'Lagos',
  city: 'Ikeja',
  education: 'bsc',
  interests: ['technology', 'sports'],
  dateOfBirth: DateTime(2000, 4, 9),
  gender: 'female',
);

OnboardingProfile _adultFull() => _full;

ContributorProfile _serverFull({DateTime? completedAt}) => ContributorProfile(
  occupations: const ['student'],
  stateOfResidence: 'Lagos',
  city: 'Ikeja',
  education: 'bsc',
  interests: const ['technology', 'sports'],
  dateOfBirth: DateTime(2000, 4, 9),
  gender: 'female',
  onboardingCompletedAt: completedAt,
);

OnboardingDraft _draft({
  OnboardingProfile profile = const OnboardingProfile(),
  OnboardingStep? lastStep,
  bool deferred = false,
  bool underAge = false,
}) => OnboardingDraft(
  profile: profile,
  lastStep: lastStep,
  deferred: deferred,
  underAge: underAge,
);

void main() {
  test('first run is pending before any answer exists', () {
    final state = resolveSetupNudge(
      session: const SessionState(signedIn: true, onboardingDone: false),
      draft: _draft(),
    );
    expect(state.status, SetupNudgeStatus.pendingFirstRun);
  });

  test('a partial skip stays pending after onboardingDone is set', () {
    final state = resolveSetupNudge(
      session: const SessionState(signedIn: true, onboardingDone: true),
      draft: _draft(
        profile: _full.copyWith(city: ''),
        lastStep: OnboardingStep.whereYouLive,
        deferred: true,
      ),
    );
    expect(state.status, SetupNudgeStatus.pendingPartial);
    expect(state.stepsLeft, greaterThan(0));
    expect(state.firstIncomplete, OnboardingStep.whereYouLive);
  });

  test('a locally complete draft is complete', () {
    final state = resolveSetupNudge(
      session: const SessionState(signedIn: true, onboardingDone: true),
      draft: _draft(profile: _adultFull()),
    );
    expect(state.status, SetupNudgeStatus.complete);
    expect(state.stepsLeft, 0);
  });

  test('an explicit under-age refusal reopens setup', () {
    final state = resolveSetupNudge(
      session: const SessionState(signedIn: true, onboardingDone: true),
      draft: _draft(
        profile: _adultFull().withoutDateOfBirth(),
        lastStep: OnboardingStep.aboutYou,
        underAge: true,
      ),
      server: _serverFull(completedAt: DateTime(2026, 11, 1)),
    );
    expect(state.status, SetupNudgeStatus.pendingUnderAge);
  });

  test(
    'a returning account with no local draft does not restart first run',
    () {
      final state = resolveSetupNudge(
        session: const SessionState(signedIn: true, onboardingDone: true),
        draft: _draft(),
      );
      expect(state.status, SetupNudgeStatus.complete);
    },
  );

  test('server completion replaces stale partial local answers', () {
    final state = resolveSetupNudge(
      session: const SessionState(signedIn: true, onboardingDone: true),
      draft: _draft(
        profile: _full.copyWith(city: '', interests: const []),
        lastStep: OnboardingStep.whereYouLive,
        deferred: true,
      ),
      server: _serverFull(completedAt: DateTime(2026, 11, 27)),
    );
    expect(state.status, SetupNudgeStatus.complete);
    expect(state.draft.profile.city, 'Ikeja');
    expect(state.draft.profile.interests, ['technology', 'sports']);
    expect(state.stepsLeft, 0);
  });

  test('a partial server profile remains pending', () {
    final state = resolveSetupNudge(
      session: const SessionState(signedIn: true, onboardingDone: true),
      draft: _draft(),
      server: ContributorProfile(
        occupations: const ['student'],
        stateOfResidence: 'Lagos',
        dateOfBirth: DateTime(2000, 4, 9),
        gender: 'female',
      ),
    );
    expect(state.status, SetupNudgeStatus.pendingServerIncomplete);
    expect(state.stepsLeft, greaterThan(0));
  });

  test('pending local writes are newer than the server snapshot', () {
    final state = resolveSetupNudge(
      session: const SessionState(signedIn: true, onboardingDone: true),
      draft: _draft(),
      server: _serverFull(),
      pendingWrites: const [
        {'stateOfResidence': 'Abuja', 'city': 'Wuse'},
      ],
    );
    expect(state.status, SetupNudgeStatus.complete);
    expect(state.draft.profile.state, 'Abuja');
    expect(state.draft.profile.city, 'Wuse');
  });

  test('server reconciliation persists the effective draft', () async {
    SharedPreferences.setMockInitialValues({
      'session.signedIn': true,
      'session.userId': 'u1',
      'onboarding.draft': jsonEncode(
        _draft(
          profile: _full.copyWith(city: ''),
          lastStep: OnboardingStep.whereYouLive,
          deferred: true,
        ).toJson(),
      ),
    });
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);

    c
        .read(onboardingDraftProvider.notifier)
        .reconcileServer(
          _serverFull(completedAt: DateTime(2026, 11, 27)),
          const [],
        );

    final saved = jsonDecode(prefs.getString('onboarding.draft')!) as Map;
    expect(saved['city'], 'Ikeja');
    expect(saved['interests'], ['technology', 'sports']);
    expect(c.read(onboardingDraftProvider).stepsLeft, 0);
  });

  test('the provider applies web completion to session and draft', () async {
    SharedPreferences.setMockInitialValues({
      'session.signedIn': true,
      'session.userId': 'u1',
      'session.onboardingDone': true,
      'onboarding.draft': jsonEncode(
        _draft(
          profile: _full.copyWith(city: '', interests: const []),
          lastStep: OnboardingStep.whereYouLive,
          deferred: true,
        ).toJson(),
      ),
    });
    final prefs = await SharedPreferences.getInstance();
    final completed = _serverFull(completedAt: DateTime(2026, 11, 27));
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        meProvider.overrideWith(
          (ref) async => Me(
            id: 'u1',
            name: 'Ada Obi',
            email: 'ada@example.com',
            profile: completed,
          ),
        ),
      ],
    );
    addTearDown(c.dispose);

    await c.read(meProvider.future);
    expect(c.read(setupNudgeStateProvider).status, SetupNudgeStatus.complete);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(sessionProvider).onboardingDone, isTrue);
    expect(c.read(onboardingDraftProvider).profile.city, 'Ikeja');
    expect(c.read(onboardingDraftProvider).stepsLeft, 0);
  });
}
