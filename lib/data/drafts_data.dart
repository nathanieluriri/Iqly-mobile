/// A response saved on this phone before it is sent: one per brief, kept
/// until it is sent or discarded. [step] is how far it got, 1 to
/// [DraftSteps.total].
class Draft {
  const Draft({
    required this.briefId,
    required this.editedAt,
    this.title = '',
    this.answer = '',
    this.answers = const {},
    this.step = 1,
  });

  final String briefId;
  final String title;
  final String answer;

  /// Question id to the options picked, or the typed answer as one entry.
  final Map<String, List<String>> answers;
  final int step;
  final DateTime editedAt;

  bool get isEmpty => title.isEmpty && answer.isEmpty && answers.isEmpty;

  Draft copyWith({
    String? title,
    String? answer,
    Map<String, List<String>>? answers,
    int? step,
    DateTime? editedAt,
  }) => Draft(
    briefId: briefId,
    title: title ?? this.title,
    answer: answer ?? this.answer,
    answers: answers ?? this.answers,
    step: step ?? this.step,
    editedAt: editedAt ?? this.editedAt,
  );
}

/// The Drafts frames (481:23202) count three steps: the answer, the quick
/// questions, and ready to send.
abstract final class DraftSteps {
  static const total = 3;
  static const answer = 1;
  static const questions = 2;
  static const ready = 3;
}
