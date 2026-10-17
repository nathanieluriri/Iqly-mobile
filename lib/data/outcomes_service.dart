import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/backend.dart';
import 'live/live_account.dart';
import 'live/live_outcomes_service.dart';
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

/// The API while submissions run live this launch, else the demo outcomes.
final outcomesServiceProvider = Provider<OutcomesService>((ref) {
  final link = ref.watch(liveLinkProvider(LiveFeature.submissions));
  if (link != null) return LiveOutcomesService(link);
  final repository = ref.watch(repositoryProvider);
  return DemoOutcomesService(
    now: repository is DemoRepository ? repository.data.now : DateTime.now(),
  );
});
