import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'outcomes_data.dart';
import 'repository.dart';

/// Results of decided submissions: the rank, the leaderboard the business
/// published and, behind Flags.businessNote, its note. The demo answers from
/// [OutcomesDemo] at the dataset's clock.
abstract class OutcomesService {
  /// Null while the submission is undecided or unknown.
  Future<Outcome?> outcome(String submissionId);
}

class DemoOutcomesService implements OutcomesService {
  DemoOutcomesService({required this.now});

  final DateTime now;

  @override
  Future<Outcome?> outcome(String submissionId) async =>
      OutcomesDemo.of(submissionId, now);
}

final outcomesServiceProvider = Provider<OutcomesService>((ref) {
  final repository = ref.watch(repositoryProvider);
  return DemoOutcomesService(
    now: repository is DemoRepository ? repository.data.now : DateTime.now(),
  );
});
