import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/onboarding_service.dart';
import 'package:iqly_mobile/features/onboarding/onboarding_draft.dart';
import 'package:iqly_mobile/features/onboarding/onboarding_flow.dart';

const _gender = OnboardingStep.gender;
const _aboutYou = OnboardingStep.aboutYou;
const _study = OnboardingStep.whereYouStudied;
const _work = OnboardingStep.yourWork;
const _live = OnboardingStep.whereYouLive;
const _like = OnboardingStep.whatYouLike;

final _adult = DateTime(2000, 5, 1);

OnboardingProfile _as(String? occupation) => OnboardingProfile(
  occupation: occupation,
  dateOfBirth: _adult,
  gender: 'female',
);

void main() {
  group('by occupation', () {
    final flow = OnboardingFlow.byOccupation;

    test('gender comes first and must be answered', () {
      const none = OnboardingProfile();
      expect(flow.firstUnanswered(none), _gender);
      expect(OnboardingFlow.answered(_gender, none), isFalse);
      expect(
        OnboardingFlow.answered(
          _gender,
          none.copyWith(gender: 'prefer_not_to_say'),
        ),
        isTrue,
      );
    });

    test('a student is asked where they study before where they live', () {
      expect(flow.path(_as('student')), [
        _gender,
        _aboutYou,
        _study,
        _live,
        _like,
      ]);
    });

    test('anyone else is asked about their work instead', () {
      for (final occupation in [
        'entrepreneur',
        'employed',
        'self_employed',
        'unemployed',
        'other',
      ]) {
        expect(flow.path(_as(occupation)), [
          _gender,
          _aboutYou,
          _work,
          _live,
          _like,
        ]);
      }
    });

    test('with no occupation yet, neither is asked', () {
      expect(flow.path(_as(null)), [_gender, _aboutYou, _live, _like]);
    });

    test('Back walks the same path', () {
      expect(flow.previous(_live, _as('student')), _study);
      expect(flow.previous(_live, _as('employed')), _work);
      expect(flow.previous(_live, _as(null)), _aboutYou);
      expect(flow.previous(_aboutYou, _as('student')), _gender);
      expect(flow.previous(_gender, _as('student')), isNull);
    });

    test('a change of mind drops the answers the new path never asks', () {
      final student = _as('student').copyWith(
        education: 'hnd_bsc',
        university: 'University of Lagos',
        sector: 'tech',
      );
      final tidied = flow.tidy(student);
      expect(tidied.education, 'hnd_bsc');
      expect(tidied.university, 'University of Lagos');
      expect(tidied.sector, isNull);

      final employed = flow.tidy(
        student.withOccupation('employed').copyWith(sector: 'finance'),
      );
      expect(employed.education, isNull);
      expect(employed.university, isNull);
      expect(employed.sector, 'finance');
    });

    test('Other needs its words before the work step counts', () {
      final other = _as('employed')
          .copyWith(sector: OnboardingFlow.otherSector);
      expect(OnboardingFlow.answered(_work, other), isFalse);
      expect(
        OnboardingFlow.answered(_work, other.copyWith(otherSector: ' Events ')),
        isTrue,
      );
    });

    test('Resume and the steps left follow the path', () {
      final employed = _as('employed');
      expect(flow.firstUnanswered(employed), _work);
      expect(flow.partsLeft(employed), 2);
      final placed = employed.copyWith(
        sector: 'tech',
        state: 'Lagos',
        city: 'Ikeja',
      );
      expect(flow.firstUnanswered(placed), _like);
      expect(flow.partsLeft(placed), 1);
    });
  });

  test('the classic order asks everyone where they studied, after where '
      'they live, and keeps no sector', () {
    final flow = OnboardingFlow.classic;
    for (final occupation in ['student', 'employed', null]) {
      expect(flow.path(_as(occupation)), [
        _gender,
        _aboutYou,
        _live,
        _study,
        _like,
      ]);
    }
    final kept = flow.tidy(
      _as('employed').copyWith(education: 'msc', sector: 'tech'),
    );
    expect(kept.education, 'msc');
    expect(kept.sector, isNull);
  });
}
