import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/polls_service.dart';

void main() {
  final json = {
    'id': 'p_1',
    'question': 'Which flavour should we launch first?',
    'choices': ['Zobo and ginger', 'Tiger nut'],
    'closesAt': '2026-10-22T09:41:00.000Z',
    'chosen': 0,
    'votes': [96, 71],
    'questions': [
      {
        'question': 'Which flavour should we launch first?',
        'choices': ['Zobo and ginger', 'Tiger nut'],
      },
      {
        'question': 'How much ginger should it have?',
        'choices': ['A little', 'A lot'],
        'chosen': null,
        'votes': null,
        'showIf': {
          'question': 0,
          'choices': [0],
        },
      },
      {
        'question': 'Which can size should the first run use?',
        'choices': ['33cl slim can', '50cl can'],
      },
      {
        'question': 'A fourth is never read',
        'choices': ['Yes', 'No'],
      },
    ],
  };

  test('pollQuestions reads up to three questions with their branches', () {
    final poll = pollFromJson(json, questions: true)!;
    expect(poll.questions, hasLength(3));
    expect(poll.followUps.first.showIf!.choices, [0]);
    expect(poll.asks(1), isTrue);
    expect(poll.voted, isFalse);
    expect(poll.followUps.first.votes, [0, 0]);
  });

  test('without pollQuestions a poll is its one question', () {
    final poll = pollFromJson(json)!;
    expect(poll.questions, hasLength(1));
    expect(poll.voted, isTrue);
  });

  test('a later question that does not read ends the questions there', () {
    final broken = {
      ...json,
      'questions': [
        json['questions'],
        {'question': 'No choices'},
        (json['questions']! as List)[2],
      ],
    };
    expect(pollFromJson(broken, questions: true)!.questions, hasLength(1));
  });
}
