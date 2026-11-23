import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/assessment_data.dart';

AssessmentAccess access({
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

void main() {
  test('a first check-in sits on Discover like finish setting up', () {
    expect(assessmentNudge(access(canTake: true)), (
      label: "Take iQLY's pre-challenge test",
      description: null,
    ));
  });

  test('an unfinished run keeps the same row', () {
    expect(
      assessmentNudge(
        access(canResume: true, state: 'in_progress', activeSessionId: 's1'),
      ),
      (
        label: "Take iQLY's pre-challenge test",
        description: 'Pick up where you left off',
      ),
    );
  });

  test('passed and waiting people do not see a retake', () {
    expect(
      assessmentNudge(access(canAccessChallenges: true, state: 'passed')),
      isNull,
    );
    expect(assessmentNudge(access(state: 'unavailable')), isNull);
    expect(assessmentNudge(null), isNull);
  });

  test('new live briefs stay off Discover until they pass', () {
    expect(
      unlockedDiscoverBriefs(
        const ['new', 'draft', 'sent'],
        access(canTake: true),
        const {'draft', 'sent'},
      ),
      ['draft', 'sent'],
    );
  });

  test('a pass puts every live brief back', () {
    expect(
      unlockedDiscoverBriefs(
        const ['new', 'draft', 'sent'],
        access(canAccessChallenges: true, state: 'passed'),
        const {'draft', 'sent'},
      ),
      ['new', 'draft', 'sent'],
    );
  });

  test('an unknown access does not hide the feed', () {
    expect(
      unlockedDiscoverBriefs(
        const ['new', 'draft', 'sent'],
        null,
        const {'draft', 'sent'},
      ),
      ['new', 'draft', 'sent'],
    );
  });
}
