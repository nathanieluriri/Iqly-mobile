import '../../core/flags.dart';
import '../../data/onboarding_service.dart';
import 'onboarding_draft.dart';

typedef _Next = OnboardingStep? Function(OnboardingProfile answers);

/// First run as a state machine (owner, 16 Oct). Each step names the one
/// after it from the answers so far, and the rest (the path, Back, Resume,
/// the steps left, which answers are kept) follows from that one table, so
/// changing the order is a change to a table.
///
/// [byOccupation] forks after About you: a student says where they study,
/// anyone else what their work is, and someone who has not said what they
/// do is asked neither; then everyone says where they live. [classic] is the
/// order before the fork, where everyone gives an education. The app walks
/// [current], which Flags.onboardingByOccupation picks.
class OnboardingFlow {
  const OnboardingFlow._(this._next);

  static final byOccupation = OnboardingFlow._({
    OnboardingStep.aboutYou: (a) => switch (a.occupation) {
      null => OnboardingStep.whereYouLive,
      'student' => OnboardingStep.whereYouStudied,
      _ => OnboardingStep.yourWork,
    },
    OnboardingStep.whereYouStudied: (_) => OnboardingStep.whereYouLive,
    OnboardingStep.yourWork: (_) => OnboardingStep.whereYouLive,
    OnboardingStep.whereYouLive: (_) => OnboardingStep.whatYouLike,
    OnboardingStep.whatYouLike: (_) => null,
  });

  static final classic = OnboardingFlow._({
    OnboardingStep.aboutYou: (_) => OnboardingStep.whereYouLive,
    OnboardingStep.whereYouLive: (_) => OnboardingStep.whereYouStudied,
    OnboardingStep.whereYouStudied: (_) => OnboardingStep.whatYouLike,
    OnboardingStep.whatYouLike: (_) => null,
  });

  static OnboardingFlow get current =>
      Flags.onboardingByOccupation ? byOccupation : classic;

  final Map<OnboardingStep, _Next> _next;

  /// The step after [from], or null when [from] is the last.
  OnboardingStep? next(OnboardingStep from, OnboardingProfile answers) =>
      _next[from]?.call(answers);

  /// The steps these answers walk, first to last.
  List<OnboardingStep> path(OnboardingProfile answers) => [
    for (
      OnboardingStep? step = OnboardingStep.aboutYou;
      step != null;
      step = next(step, answers)
    )
      step,
  ];

  /// The step before [step] on the path, or null for the first.
  OnboardingStep? previous(OnboardingStep step, OnboardingProfile answers) {
    final steps = path(answers);
    final at = steps.indexOf(step);
    return at > 0 ? steps[at - 1] : null;
  }

  OnboardingStep? firstUnanswered(OnboardingProfile answers) =>
      path(answers).where((s) => !answered(s, answers)).firstOrNull;

  /// The step mark's parts that still have a step to answer.
  int partsLeft(OnboardingProfile answers) => {
    for (final step in path(answers))
      if (!answered(step, answers)) step.mark,
  }.length;

  /// The same answers without those this path never asks, so nothing is
  /// kept or sent that was not asked.
  OnboardingProfile tidy(OnboardingProfile answers) {
    final steps = path(answers);
    return answers.keeping(
      keepStudy: steps.contains(OnboardingStep.whereYouStudied),
      keepWork: steps.contains(OnboardingStep.yourWork),
    );
  }

  static bool answered(
    OnboardingStep step,
    OnboardingProfile a,
  ) => switch (step) {
    OnboardingStep.aboutYou => a.occupation != null && isAdult(a.dateOfBirth),
    OnboardingStep.whereYouStudied => a.education != null,
    OnboardingStep.yourWork => workAnswered(a),
    OnboardingStep.whereYouLive => a.state != null && a.city.trim().isNotEmpty,
    OnboardingStep.whatYouLike => OnboardingDraft.interestsComplete(a),
  };

  /// A sector, and the words for Other when Other is the one.
  static bool workAnswered(OnboardingProfile a) =>
      a.sector != null &&
      (a.sector != otherSector || a.otherSector.trim().isNotEmpty);

  static const otherSector = 'other';
}
