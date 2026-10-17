import '../api_client.dart';
import '../outcomes_data.dart';
import '../outcomes_service.dart';
import 'live_account.dart';

/// `GET /submissions/:id/outcome` as the Results screen reads it (contract
/// 5). The leaders are the published winners without their entry titles,
/// which the API keeps private, so each entry is empty; the person's own
/// row is left out, since the screen builds it from their submission and
/// award. There is no business note.
Outcome outcomeFromJson(Map<String, dynamic> json, String submissionId) =>
    Outcome(
      submissionId: apiText(json['submissionId']) ?? submissionId,
      link: apiText(json['link']) ?? '',
      rank: apiInt(json['rank']),
      entries: apiInt(json['entries']),
      leaders: [
        if (json['leaders'] case final List<Object?> leaders)
          for (final row in leaders)
            if (row is Map && row['you'] != true && apiInt(row['rank']) != null)
              LeaderboardEntry(
                rank: apiInt(row['rank'])!,
                name: apiText(row['name']) ?? 'Anonymous',
                entry: '',
                amountKobo: apiInt(row['amountKobo']),
              ),
      ],
    );

/// [OutcomesService] on the API, each outcome kept for a read without a
/// connection. Unknown to the API, or not the person's own, is no outcome.
class LiveOutcomesService implements OutcomesService {
  LiveOutcomesService(this.link);

  final AccountLink link;

  @override
  Future<Outcome?> outcome(String submissionId) async {
    try {
      final json = await link.fetch(
        '/submissions/${Uri.encodeComponent(submissionId)}/outcome',
        AccountKeys.outcome(submissionId),
      );
      return outcomeFromJson(json, submissionId);
    } on ApiRefused catch (refused) {
      if (refused.status == 404 || refused.status == 403) return null;
      rethrow;
    }
  }
}
