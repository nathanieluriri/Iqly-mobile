class AssessmentAccess {
  const AssessmentAccess({
    required this.canTake,
    required this.canResume,
    required this.canAccessChallenges,
    required this.state,
    this.activeSessionId,
  });

  final bool canTake;
  final bool canResume;
  final bool canAccessChallenges;
  final String state;
  final String? activeSessionId;

  factory AssessmentAccess.fromJson(Map<String, dynamic> json) =>
      AssessmentAccess(
        canTake: json['canTake'] == true,
        canResume: json['canResume'] == true,
        canAccessChallenges: json['canAccessChallenges'] == true,
        state: json['state'] as String? ?? 'needed',
        activeSessionId: json['activeSessionId'] as String?,
      );

  Map<String, Object?> toJson() => {
    'canTake': canTake,
    'canResume': canResume,
    'canAccessChallenges': canAccessChallenges,
    'state': state,
    'activeSessionId': activeSessionId,
  };
}

typedef AssessmentNudgeCopy = ({String label, String description});

const assessmentQuestionCapMs = 60000;

int questionClockMs(Object? remainingMs) {
  final n = remainingMs is num ? remainingMs.toDouble() : double.nan;
  if (!n.isFinite || n <= 0) return 0;
  final ms = n.floor();
  return ms > assessmentQuestionCapMs ? assessmentQuestionCapMs : ms;
}

const assessmentIntro = (
  title: 'Qualification test',
  body: 'Twenty questions in four parts. Get enough right and you can take on challenges.',
);

/// Discover row copy. Hidden after a pass or during a wait so nobody is
/// invited to retake.
AssessmentNudgeCopy? assessmentNudge(AssessmentAccess? access) {
  if (access == null) {
    return (
      label: assessmentIntro.title,
      description: 'Twenty questions before new challenges',
    );
  }
  if (access.canAccessChallenges || access.state == 'unavailable') {
    return null;
  }
  if (access.canResume) {
    return (
      label: assessmentIntro.title,
      description: 'Pick up where you left off',
    );
  }
  if (access.canTake) {
    return (
      label: assessmentIntro.title,
      description: 'Twenty questions before new challenges',
    );
  }
  return null;
}

/// Live briefs they have not started stay off Discover until they pass.
List<String> unlockedDiscoverBriefs(
  List<String> briefIds,
  AssessmentAccess? access,
  Set<String> startedIds,
) {
  if (access == null || access.canAccessChallenges) return briefIds;
  return [
    for (final id in briefIds)
      if (startedIds.contains(id)) id,
  ];
}

class AssessmentOption {
  const AssessmentOption({required this.index, required this.text});

  final int index;
  final String text;
}

class AssessmentQuestion {
  const AssessmentQuestion({
    required this.index,
    required this.total,
    required this.domain,
    required this.prompt,
    required this.options,
    required this.remainingMs,
    required this.deadlineAt,
    this.svg,
  });

  final int index;
  final int total;
  final String domain;
  final String prompt;
  final String? svg;
  final List<AssessmentOption> options;
  final int remainingMs;
  final DateTime deadlineAt;

  factory AssessmentQuestion.fromJson(Map<String, dynamic> json) =>
      AssessmentQuestion(
        index: json['index'] as int? ?? 0,
        total: json['total'] as int? ?? 20,
        domain: json['domain'] as String? ?? '',
        prompt: json['prompt'] as String? ?? '',
        svg: json['svg'] as String?,
        options: [
          for (final item in json['options'] as List? ?? const [])
            if (item is Map)
              AssessmentOption(
                index: item['index'] as int? ?? 0,
                text: item['text'] as String? ?? '',
              ),
        ],
        remainingMs: questionClockMs(json['remainingMs']),
        deadlineAt:
            DateTime.tryParse(json['deadlineAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

class AssessmentSession {
  const AssessmentSession({
    required this.id,
    required this.status,
    required this.answered,
    required this.total,
    this.question,
  });

  final String id;
  final String status;
  final int answered;
  final int total;
  final AssessmentQuestion? question;

  factory AssessmentSession.fromJson(Map<String, dynamic> json) =>
      AssessmentSession(
        id: json['id'] as String? ?? '',
        status: json['status'] as String? ?? 'started',
        answered: json['answered'] as int? ?? 0,
        total: json['total'] as int? ?? 20,
        question: json['question'] is Map
            ? AssessmentQuestion.fromJson(
                (json['question'] as Map).cast<String, dynamic>(),
              )
            : null,
      );
}
