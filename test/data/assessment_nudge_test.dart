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
      label: 'A short check-in',
      description: 'Needed before new briefs',
    ));
  });

  test('an unfinished run asks them to continue', () {
    expect(
      assessmentNudge(
        access(canResume: true, state: 'in_progress', activeSessionId: 's1'),
      ),
      (label: 'Continue check-in', description: 'Pick up where you left off'),
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
}
