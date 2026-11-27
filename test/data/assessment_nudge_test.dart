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
      label: 'Qualification test',
      description: 'Twenty questions before new challenges',
    ));
  });

  test('an unfinished run keeps the same row', () {
    expect(
      assessmentNudge(
        access(canResume: true, state: 'in_progress', activeSessionId: 's1'),
      ),
      (label: 'Qualification test', description: 'Pick up where you left off'),
    );
  });

  test('a broken clock is already up and nothing sits past 60 seconds', () {
    expect(questionClockMs(double.nan), 0);
    expect(questionClockMs(-12), 0);
    expect(questionClockMs(90000), 60000);
    expect(questionClockMs(25000), 25000);
  });

  test('the intro stays short', () {
    expect(assessmentIntro, (
      title: 'Qualification test',
      body: 'Twenty questions in four parts. Get enough right and you can take on challenges.',
    ));
  });

  test('passed and waiting people do not see a retake', () {
    expect(
      assessmentNudge(access(canAccessChallenges: true, state: 'passed')),
      isNull,
    );
    expect(assessmentNudge(access(state: 'unavailable')), isNull);
  });

  test('Discover still offers the test when access has not loaded', () {
    expect(assessmentNudge(null), (
      label: 'Qualification test',
      description: 'Twenty questions before new challenges',
    ));
  });
}
